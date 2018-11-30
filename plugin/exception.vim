
command! -nargs=? -bar -bang Throw   throw   exception#exception(<q-bang>, 'throw',
      \ execute('echo '.<q-args>. ' "\r"')[1:-3],
      \ expand('<sfile>'), expand('<slnum>'))
command! -nargs=? -bar -bang Echoerr echoerr exception#exception(<q-bang>, 'echoerr',
      \ execute('echo '.<q-args>. ' "\r"')[1:-3],
      \ expand('<sfile>'), expand('<slnum>'))
command! -nargs=? -bar -bang Echomsg echomsg exception#exception(<q-bang>, 'echomsg',
      \ execute('echo '.<q-args>. ' "\r"')[1:-3],
      \ expand('<sfile>'), expand('<slnum>'))
command! -nargs=? -bar       THROW   throw   exception#exception('replace', 'throw',
      \ execute('echo '.<q-args>. ' "\r"')[1:-3],
      \ expand('<sfile>'), expand('<slnum>'))
command! -nargs=? -bar       ECHOERR echoerr exception#exception('replace', 'echoerr',
      \ execute('echo '.<q-args>. ' "\r"')[1:-3],
      \ expand('<sfile>'), expand('<slnum>'))
command! -nargs=? -bar       ECHOMSG echomsg exception#exception('replace', 'echomsg',
      \ execute('echo '.<q-args>. ' "\r"')[1:-3],
      \ expand('<sfile>'), expand('<slnum>'))
command! -nargs=? -bar       Echotb  echomsg exception#traceback()

command! ExceptQf call exception#quickfix()