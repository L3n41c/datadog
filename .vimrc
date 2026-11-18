" .vimrc — Project-local Vim configuration (style only).
"
" Loaded automatically at Vim startup in this directory if the user's
" ~/.vimrc contains:  set exrc  +  set secure
" (or via a plugin such as vim-localrc).
"
" Deliberate constraint: NO save hook here (no reformatting on save, no
" trailing-whitespace removal on save). When to reformat one's files is a
" personal choice, to be set in ~/.vimrc, not in every repository.
"
" These settings mirror .editorconfig, .clang-format, .cmake-format.yaml
" and .dir-locals.el:
"   - default   : 2-space indentation (default of .editorconfig [*])
"   - C/C++     : indentation tabs (width 4), 100-column limit
"   - CMake     : 4-space indentation, 100-column limit
"   - Makefile  : indentation tabs (required by make)

" --- File type detection (needed for per-type settings) ---
filetype plugin indent on

" --- Global defaults (mirror of .editorconfig [*]) ---
set encoding=utf-8
set fileencoding=utf-8
set fileformat=unix         " LF line endings
set endofline
set fixendofline            " add the final newline on write
set expandtab               " spaces by default
set tabstop=4               " display width of a tab
set shiftwidth=2            " one indentation level
set softtabstop=2
set textwidth=0             " no automatic line wrapping:
                            " line formatting is clang-format / cmake-format's
                            " job, not the editor's

" --- Per-file-type settings ---
augroup datadog_style
  autocmd!
  " C/C++: tabs for indentation, spaces for alignment;
  " 100-column limit (.clang-format UseTab/TabWidth/ColumnLimit).
  autocmd FileType c,cpp setlocal noexpandtab tabstop=4 shiftwidth=4 softtabstop=4
        \ cindent cinoptions=g0,:0,N-s,(0,Ws,J1,j1 colorcolumn=101
  " CMake: 4 spaces, 100-column limit (.cmake-format.yaml).
  autocmd FileType cmake setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
        \ colorcolumn=101
  " Make: tabs are mandatory.
  autocmd FileType make setlocal noexpandtab tabstop=4 shiftwidth=4 softtabstop=4
  " YAML, JSON, Markdown, Lisp...: 2 spaces (default .editorconfig [*]),
  " any tab present is displayed 4 columns wide.
  autocmd FileType yaml,json,jsonc,markdown,lisp setlocal expandtab tabstop=4
        \ shiftwidth=2 softtabstop=2
augroup END
