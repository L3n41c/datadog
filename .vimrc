" .vimrc — Configuration Vim locale au projet (style uniquement).
"
" Chargé automatiquement au démarrage de Vim dans ce répertoire si le
" ~/.vimrc de l'utilisateur contient :  set exrc  +  set secure
" (ou via un plugin comme vim-localrc).
"
" Contrainte volontaire : AUCUN hook de sauvegarde ici (pas de reformatage
" à la sauvegarde, pas de suppression des espaces de fin de ligne à la
" sauvegarde). Le moment où l'on reformate ses fichiers est un choix
" personnel, à définir dans ~/.vimrc, pas dans chaque dépôt.
"
" Ces réglages reflètent .editorconfig, .clang-format, .cmake-format.yaml et
" .dir-locals.el :
"   - défaut    : indentation de 2 espaces (défaut .editorconfig [*])
"   - C/C++     : tabulations d'indentation (largeur 4), limite de 100 colonnes
"   - CMake     : indentation de 4 espaces, limite de 100 colonnes
"   - Makefile  : tabulations d'indentation (exigé par make)

" --- Détection du type de fichier (nécessaire aux réglages par type) ---
filetype plugin indent on

" --- Défauts globaux (miroir de .editorconfig [*]) ---
set encoding=utf-8
set fileencoding=utf-8
set fileformat=unix         " fins de ligne LF
set endofline
set fixendofline            " ajoute la newline finale à l'écriture
set expandtab               " espaces par défaut
set tabstop=4               " largeur d'affichage d'une tabulation
set shiftwidth=2            " un niveau d'indentation
set softtabstop=2
set textwidth=0             " pas de retour à la ligne automatique :
                            " le formatage des lignes est du ressort de
                            " clang-format / cmake-format, pas de l'éditeur

" --- Réglages par type de fichier ---
augroup datadog_style
  autocmd!
  " C/C++ : tabulations pour l'indentation, espaces pour l'alignement ;
  " limite de 100 colonnes (.clang-format UseTab/TabWidth/ColumnLimit).
  autocmd FileType c,cpp setlocal noexpandtab tabstop=4 shiftwidth=4 softtabstop=4
        \ cindent cinoptions=g0,:0,N-s,(0,Ws,J1,j1 colorcolumn=101
  " CMake : 4 espaces, limite de 100 colonnes (.cmake-format.yaml).
  autocmd FileType cmake setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
        \ colorcolumn=101
  " Make : les tabulations sont obligatoires.
  autocmd FileType make setlocal noexpandtab tabstop=4 shiftwidth=4 softtabstop=4
  " YAML, JSON, Markdown, Lisp... : 2 espaces (défaut .editorconfig [*]),
  " les tabulations éventuellement présentes s'affichent sur 4 colonnes.
  autocmd FileType yaml,json,jsonc,markdown,lisp setlocal expandtab tabstop=4
        \ shiftwidth=2 softtabstop=2
augroup END
