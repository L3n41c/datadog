set encoding=utf-8 fileformat=unix endofline fixendofline
set expandtab tabstop=4 shiftwidth=2 softtabstop=2 textwidth=0

filetype plugin indent on
augroup datadog_style
  autocmd!
  autocmd FileType c,cpp setlocal noexpandtab shiftwidth=4 softtabstop=4 textwidth=100
  autocmd FileType cmake setlocal expandtab shiftwidth=4 softtabstop=4 textwidth=100
  autocmd FileType make setlocal noexpandtab shiftwidth=4 softtabstop=4
augroup END
