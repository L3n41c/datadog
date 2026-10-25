" .vimrc — Project-local Vim configuration for code formatting only.
" These settings mirror .clang-format and .editorconfig.
" Personal preferences belong in ~/.vimrc, not here.
"
" Loaded automatically when Vim starts in this directory
" (requires 'set exrc' in ~/.vimrc or a plugin like vim-localrc).

" --- Indentation: tabs for indentation, spaces for alignment (matches .clang-format UseTab: ForIndentation) ---
set noexpandtab       " use tab characters for indentation
set tabstop=4         " visual width of a tab character
set shiftwidth=4      " width of one indentation level
set softtabstop=4     " number of spaces inserted/removed by Tab/Backspace

" --- Line length (matches .clang-format ColumnLimit: 100) ---
set textwidth=0       " disable automatic line wrapping
set colorcolumn=101   " highlight column 101 (1-based, past the 100-char limit)

" --- File encoding and line endings (matches .editorconfig) ---
set fileencoding=utf-8
set fileformat=unix   " LF line endings
set endofline         " ensure file ends with a newline
set fixendofline      " automatically add final newline when missing

" --- Trailing whitespace (matches .editorconfig trim_trailing_whitespace) ---
autocmd BufWritePre * if &ft != 'markdown' | silent! :%s/\s\+$//e | endif

" --- Clang-format integration: format buffer on save using project .clang-format ---
" Uses system() to capture output and checks v:shell_error before replacing the
" buffer, so a clang-format failure never overwrites the source with diagnostics.
" --assume-filename tells clang-format which file it is formatting so it finds .clang-format.
if executable('clang-format')
    function! s:ClangFormatBuffer()
        let l:filename = expand('%:p')
        let l:input = join(getline(1, '$'), "\n") . "\n"
        let l:output = system('clang-format --style=file --assume-filename=' . shellescape(l:filename), l:input)
        if v:shell_error != 0
            echohl ErrorMsg
            echom 'clang-format failed (exit ' . v:shell_error . '): ' . l:output
            echohl None
            return
        endif
        let l:view = winsaveview()
        let l:lines = split(l:output, "\n", 1)
        if !empty(l:lines) && l:lines[-1] ==# ''
            call remove(l:lines, -1)
        endif
        silent! keepjumps %delete _
        if !empty(l:lines)
            call setline(1, l:lines)
        endif
        call winrestview(l:view)
    endfunction
    autocmd BufWritePre *.h,*.hh,*.hpp,*.hxx,*.c,*.cc,*.cpp,*.cxx,*.c++
        \ call s:ClangFormatBuffer()
endif

" --- C/C++ indentation style (matches .clang-format BreakBeforeBraces: Custom / Allman) ---
set cindent
set cinoptions=g0,:0,N-s,(0,Ws,J1,j1
