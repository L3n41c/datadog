" .vimrc — Configuration Vim/Neovim pour le projet C++ moderne
" Ce fichier est chargé automatiquement si Vim est lancé depuis la racine du projet
" (nécessite 'set exrc' dans votre ~/.vimrc global, ou utiliser un plugin comme vim-localrc).
" Alternative recommandée : utiliser .editorconfig avec le plugin editorconfig-vim,
" ou un LSP (coc-clangd, vim-lsp, nvim-lspconfig) qui gère le formatage via clangd.

" --- Indentation : tabulations pour l'indentation, espaces pour l'alignement ---
" Note : Vim ne gère pas l'alignement "gofmt-style" nativement.
" Utilisez clang-format (via LSP ouALE) pour le formatage précis.
set noexpandtab       " utiliser des tabulations
set tabstop=4         " largeur visuelle d'une tabulation
set shiftwidth=4      " largeur d'un niveau d'indentation
set softtabstop=4     " nombre de espaces insérés par Tab/Backspace
set autoindent        " indentation automatique
set smartindent       " indentation intelligente pour C/C++
set cindent           " indentation C-style
set cinoptions=g0,:0,N-s,(0,Ws,J1,j1  " options d'indentation C détaillées

" --- Fichiers ---
set fileencoding=utf-8
set encoding=utf-8
set fileformat=unix           " fins de ligne LF
set fixeol                    " garantir une ligne vide finale
set noendofline               " ne pas forcer (fixeol gère déjà)
set autoread                  " recharger si modifié en externe
set hidden                    " permettre de cacher les buffers modifiés

" --- Affichage ---
set number                    " numéros de ligne
set relativenumber            " numéros relatifs (utile pour la navigation)
set nowrap                    " ne pas couper les lignes longues
set linebreak                 " couper aux limites de mots (avec nowrap)
set showmatch                 " montrer les parenthèses/crochets correspondants
set cursorline                " surligner la ligne courante
set colorcolumn=101           " colonne de limite à 100 caractères (1-based)
set signcolumn=yes            " toujours afficher la colonne de signes
set laststatus=2              " toujours afficher la barre de statut
set ruler                     " afficher position curseur
set showcmd                   " afficher les commandes partielles
set wildmenu                  " menu complétion amélioré
set wildmode=longest:list,full

" --- Recherche ---
set incsearch                 " recherche incrémentale
set hlsearch                  " surligner les résultats
set ignorecase                " ignorer la casse
set smartcase                 " ... sauf si majuscule saisie
set gdefault                  " remplacer globalement par défaut

" --- Fichiers temporaires ---
set backupdir=~/.vim/backup// " sauvegardes centralisées
set directory=~/.vim/swap//   " fichiers swap centralisés
set undodir=~/.vim/undo//     " historique undo centralisé
set undofile                  " sauvegarder l'historique undo
set noswapfile                " pas de swap (les LSP gèrent)
set nobackup                  " pas de backup (git gère)

" --- Comportement ---
set backspace=indent,eol,start " backspace libre
set mouse=a                   " souris dans tous les modes
set clipboard=unnamedplus     " presse-papier système
set scrolloff=5               " marge de défilement
set sidescrolloff=10          " marge latérale
set splitright                " split vertical à droite
set splitbelow                " split horizontal en bas
set equalalways               " tailles égales pour les splits
set timeoutlen=500            " délai pour les mappings
set ttimeoutlen=10            " délai pour les key codes
set updatetime=300            " délai de mise à jour (pour LSP/flycheck)
set shortmess+=c              " pas de message pour la complétion
set completeopt=menu,menuone,noselect,noinsert

" --- Trimming des espaces en fin de ligne (sauf Markdown) ---
autocmd BufWritePre * if &ft != 'markdown' | :%s/\s\+$//e | endif

" --- Détection du type de fichier ---
autocmd BufNewFile,BufRead CMakeLists.txt set filetype=cmake
autocmd BufNewFile,BufRead *.cmake set filetype=cmake
autocmd BufNewFile,BufRead meson.build set filetype=meson
autocmd BufNewFile,BufRead Doxyfile set filetype=dosini
autocmd BufNewFile,BufRead .clang-format set filetype=yaml
autocmd BufNewFile,BufRead .clang-tidy set filetype=yaml
autocmd BufNewFile,BufRead .editorconfig set filetype=dosini

" --- Formatage avec clang-format (manuel ou via LSP) ---
" Formater la sélection visuelle ou le buffer entier
command! -range=% ClangFormat <line1>,<line2>!clang-format --style=file
vnoremap <leader>f :ClangFormat<CR>
nnoremap <leader>f :%ClangFormat<CR>

" --- Vérification avec clang-tidy (manuel ou via LSP/ALE) ---
command! ClangTidy call jobstart(['clang-tidy', expand('%:p'), '--', '-std=c++23', '-I', expand('%:p:h')])

" --- Navigation ---
" Aller à la déclaration / définition (fonctionne avec LSP)
nnoremap <silent> gd :call CocAction('jumpDefinition')<CR>
nnoremap <silent> gD :call CocAction('jumpDeclaration')<CR>
nnoremap <silent> gi :call CocAction('jumpImplementation')<CR>
nnoremap <silent> gr :call CocAction('jumpReferences')<CR>
nnoremap <silent> gt :call CocAction('jumpTypeDefinition')<CR>

" --- Gestion des buffers ---
nnoremap <leader>bd :bdelete<CR>
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>

" --- Gestion des fenêtres ---
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" --- Terminal intégré ---
nnoremap <leader>t :terminal<CR>

" --- Neovim uniquement : support du presse-papiers ---
if has('nvim')
    " Les mappings LSP sont gérés par nvim-lspconfig
endif

" --- Note importante ---
" Pour un support complet du formatage et du linting C++ moderne,
" il est fortement recommandé d'utiliser un plugin LSP :
"   - Neovim : nvim-lspconfig avec clangd
"   - Vim : vim-lsp ou ALE (Asynchronous Lint Engine)
"   - Les deux : coc.nvim (Conquer of Completion)
" clangd gère nativement clang-format et clang-tidy.
