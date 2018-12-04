if exists('g:loaded_exception') && !exists('g:dev_exception')
  finish
endif
let g:loaded_exception = 1

let s:pattern = {
      \ 'exception': ['\v^Vim\((\w+)\):(.*)$', 2],
      \ 'throwpoint': ['\v^(\S+|function (\S+)), line (\d+)$', 3],
      \ 'function': ['\v^([^[]+)\[(\d+)\]$', 2],
      \ 'frame': ['\v^\[E:(\w+)\](.{-}) in ((\S+|function \S+), line (\d+))$', 5],
      \ }
function! s:match(expr, pattern, ...)
  let allow_empty = get(a:000, 0, 0)
  let [pattern, n] = s:pattern[a:pattern]
  let rv = matchlist(a:expr, pattern)
  if empty(rv)
    if allow_empty
      return rv
    else
      echoerr printf('match failed for: %s =~ %s', a:expr, a:pattern)
    endif
  else
    return rv[1:n]
  endif
endfunction

function! s:throwpoint(throwpoint)
  let [fileandfuncs, funcs, line] = s:match(a:throwpoint, 'throwpoint')
  if funcs == ''
    let funcs = [[fileandfuncs, line]]
  else
    let funcs = funcs . printf('[%d]', line)
    let funcs = split(funcs, '\.\.')
    let funcs = map(funcs, {i,x-> s:match(x, 'function')})
    return funcs
  endif
endfunction

" info can be obtained by exception#last()
function! exception#info(...)
  let msg = get(a:000, 0, exception#last())
  let frames = split(msg, "\n")
  let rv = []
  for frame in frames
    let item = {'frame': frame}
    let [item.type, item.msg, item.throwpoint, file, line] = s:match(frame, 'frame')
    if file =~ '^function'
      let item.stack = s:throwpoint(item.throwpoint)
    else
      let item.stack = [[file, line, 'filename']]
    endif
    call add(rv, item)
  endfor
  return rv
endfunction

function! s:locate_function(functionname, line) abort
  try
    if a:functionname =~ '<SNR>[0-9]\+'  "<SNR>function
      let [scriptid, fname] = matchlist(a:functionname,
            \  '<SNR>\([0-9]\+\)_\(.*\)')[1:2]
      let scriptnames = execute('scriptnames')
      let file = matchlist(scriptnames, scriptid . ': \(.*\)')[1]
      let output = execute('verb function ' . a:functionname)
      let pattern1 = 'function!\?\s\+\<\zss:' . fname . '\s*('
    elseif a:functionname =~ '^[0-9]\+$'   "numbered function
      let output = execute('verb function {' . a:functionname . '}')
      let pattern1 = ''
    elseif a:functionname =~ '^l[0-9]\+$'
      let lambdaid = matchlist(a:functionname, '^l\([0-9]\+\)$')[1]
      let output = execute(printf("verb function {'<lambda>%d'}", lambdaid))
      let pattern1 = ''
    else   "normal function
      let output = execute('verb function ' . a:functionname)
      let pattern1 = 'function!\?\s\+\<\zs' . a:functionname . '\s*('
    endif
  catch /Undefined function/
    Throw
  endtry
  if has('nvim')  " a bug; after calling execute() the output position is changed
    echon "\r"
  endif
  let ret = split(output, "\n")
  let pattern2 = substitute(ret[2], '^[0-9]\+\s\+', '', '')
  let file = substitute(ret[1], '\s*Last set from ', '', '')
  let rv = [file]
  let nspace = match(ret[0], 'function')
  let idx = match(ret, '^' . a:line . '\s')
  let line1 = ret[idx][nspace:]
  let line2 = ret[idx+1][nspace:]
  " return two lines to locate the position. this is not guaranteed to work
  return [file, line1, line2]
endfunction

function! exception#make_quickfix(...) abort
  let errors = call('exception#info', a:000)
  let rv = []
  for error in (errors)
    call add(rv, {'text': error.msg})
    for stack in (error.stack)
      if len(stack) == 3
        let line = stack[1]
        let file = stack[0]
        let item = {'filename': file, 'lnum': line, 'text': error.msg}
      else
        let line = stack[1]
        let item = {}
        "let item.lnum = stack[1]
        "let item.text = error.msg
        let fname = stack[0]
        let [file, content1, content2] = s:locate_function(fname, line)
        let text = fname =~ '^[0-9]\+$'? '{'.fname.'}': fname
        let pattern = printf('^\V\^%s\n%s\$', escape(content1, '\'), escape(content2, '\') )
        let item.text = text . ':' . line
        let item.pattern = pattern
        let item.filename = expand(file)
      endif
      call add(rv, item)
    endfor
  endfor
  return rv
endfunction

" optional: the traceback info. default: last traceback
function! exception#quickfix(...) abort
  let qf = call('exception#make_quickfix', a:000)
  silent call setqflist(qf)
  silent botright copen
  silent cc
endfunction

function! exception#last()
  return s:last
endfunction

function! s:make_traceback()
  if v:exception == ''
    return 0
  endif
  let frame = {}
  let exception = s:match(v:exception, 'exception', 1)
  if empty(exception)
    let frame.msg = v:exception
    let frame.type = 'throw'
  else
    let [frame.type, frame.msg] = exception
  endif
  let frame.throwpoint = v:throwpoint
  let frame.stack = s:throwpoint(v:throwpoint)
  return frame
endfunction

" optional: extra message
" if extra message
function! exception#format_traceback(traceback, ...)
  let tb = a:traceback
  let extra = get(a:000, 0, '')
  let replace = get(a:000, 1, 0)
  let msg = tb.msg
  if msg =~ '^\[E:\w\+] '  " exception generated by this plugin
    if replace && extra != ''
      if msg =~ 'in function'
        let msg = substitute(msg, '^\v\[E:\w+\] \zs.*\ze in function', extra, '')
      else  " in file (will not work if file contains space)
        let msg = substitute(msg, '^\v\[E:\w+\] \zs.*\ze in \S+, line.*', extra, '')
      endif
    else
      let extra = extra == ''? '' : '(' . extra . ') '
      let msg = substitute(msg, '^\v\[E:\w+\] \zs\ze.*', extra, '')
    endif
  else  " exception generated by vim internally
    if extra != ''
      let msg = replace? extra : printf('(%s) %s', extra, msg)
    endif
    let msg = printf('[E:%s] %s in %s', tb.type, msg, tb.throwpoint)
  endif
  return msg
endfunction

" optional: extra messagemsg
function! exception#traceback(...)
  let tb = s:make_traceback()
  if tb is 0
    return ''
  else
    return call('exception#format_traceback', [tb] + a:000)
  endif
endfunction

" mode:
"   - 'new': ceate a new frame to hold the msg
"   - 'replace': use the existing frame but replace the msg
"   - '!': the same as replace
"   - others: use the existing frame and prepend the msg
" type: error type
function! exception#exception(mode, type, msg, sfile, slnum)
  if a:mode == 'new' || v:exception == ''
    let tbinfo = exception#traceback()
    let msg = a:msg == '' ? '' : ' ' . a:msg
    let cframe = {}
    let cframe.msg = msg
    let cframe.type = a:type
    let cframe.stack = [[a:sfile, a:slnum]]
    let cframe.throwpoint = printf("in %s, line %d", a:sfile, a:slnum)
    let extra = printf("[E:%s]%s %s", cframe.type, cframe.msg, cframe.throwpoint)
    let s:frame = cframe
    let s:last = tbinfo == ''?extra : extra . "\n" . tbinfo
  else
    let replace = a:mode == '!' || a:mode == 'replace'
    let tbinfo = exception#traceback(a:msg, replace)
    let s:last = tbinfo
  endif
  return s:last
endfunction

