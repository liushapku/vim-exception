
command! -nargs=? -bar -bang Throw   throw   exception#exception(<q-bang>, 'throw',
      \ execute('echo '.<q-args>. ' "\r"')[1:-3],
      \ expand('<sfile>'), expand('<slnum>'))

command! -nargs=? -bar -bang EchoExcept echomsg exception#exception(<q-bang>, 'echomsg',
      \ execute('echo '.<q-args>. ' "\r"')[1:-3],
      \ expand('<sfile>'), expand('<slnum>'))
      
command! -nargs=? -bar       THROW   throw   exception#exception('new', 'throw',
      \ execute('echo '.<q-args>. ' "\r"')[1:-3],
      \ expand('<sfile>'), expand('<slnum>'))

command! -nargs=? -bar       ECHOEXCEPT echomsg exception#exception('new', 'echomsg',
      \ execute('echo '.<q-args>. ' "\r"')[1:-3],
      \ expand('<sfile>'), expand('<slnum>'))
      
command! -nargs=? -bar       Echotb  echomsg exception#traceback()

command! ExceptQf call exception#quickfix()
