;;; .dir-locals.el — Configuration Emacs pour le projet
;;; Ce fichier est lu automatiquement par Emacs à l'ouverture d'un fichier du projet.
;;; Il applique les mêmes règles de formatage que .clang-format et .editorconfig.

((nil . ((indent-tabs-mode . t)
         (tab-width . 4)
         (c-basic-offset . 4)
         (fill-column . 100)
         (c-set-style . "file")          ; utilise .clang-format via clang-format.el ou lsp-mode
         (clang-format-executable . "clang-format")
         (flycheck-clang-tidy-executable . "clang-tidy")
         (flycheck-clang-format-executable . "clang-format")
         (flycheck-checker . clang-tidy)
         (flycheck-clang-include-path . ("/usr/include/c++/14" "/usr/include/x86_64-linux-gnu/c++/14"))
         (company-clang-executable . "clang")
         (lsp-clangd-executable . "clangd")
         (lsp-clients-clangd-args . ("--background-index" "--clang-tidy" "--header-insertion=never" "-j=4"))
         (whitespace-style . (face trailing tabs lines-tail))
         (whitespace-line-column . 100)
         (show-trailing-whitespace . t)
         ;; Mode C++ moderne
         (c-doc-comment-style . ((java-mode . javadoc) (pike-mode . autodoc) (c-mode . doxygen) (c++-mode . doxygen)))
         ;; Électric keys pour le style Allman (accolades sur leur propre ligne)
         (c-electric-flag . t)
         ;; Ne pas réindenter automatiquement (laisser clang-format gérer)
         (c-tab-always-indent . nil)
         ;; Sauvegarde automatique du formatage
         (before-save-hook . (clang-format-buffer))))

 ;; Mode spécifique pour les fichiers CMake
 (cmake-mode . ((indent-tabs-mode . nil)
                (tab-width . 4)
                (cmake-tab-width . 4)))

 ;; Mode spécifique pour le Markdown
 (markdown-mode . ((indent-tabs-mode . nil)
                   (tab-width . 4)
                   (fill-column . 100))))

;;; Pour activer le formatage automatique avec clang-format :
;;; (add-hook 'c++-mode-hook (lambda () (clang-format+-mode 1)))
;;; ou utiliser lsp-mode / eglot qui intègre clangd (recommandé).
