;;; .dir-locals.el --- Réglages de style locaux au projet pour Emacs.
;;;
;;; Chargé automatiquement par Emacs à l'ouverture de tout fichier du projet.
;;;
;;; Contrainte volontaire : AUCUN hook de sauvegarde ici (pas de
;;; before-save-hook, pas de reformatage à la sauvegarde). Le moment où
;;; l'on reformate ses fichiers est un choix personnel, à définir dans sa
;;; propre configuration utilisateur (~/.config/emacs/init.el), pas dans
;;; chaque dépôt.
;;;
;;; Ces réglages reflètent .editorconfig, .clang-format et .cmake-format.yaml :
;;;   - C/C++     : indentation par tabulations (largeur 4), colonnes à 100
;;;   - CMake     : indentation de 4 espaces, colonnes à 100
;;;   - Makefiles : indentation par tabulations (exigé par make)
;;;   - le reste  : indentation de 2 espaces (défaut de .editorconfig [*])

((nil . ((indent-tabs-mode . nil)       ; espaces par défaut (.editorconfig [*])
         (tab-width . 4)                ; largeur d'affichage d'une tabulation
         (require-final-newline . t)))  ; .editorconfig insert_final_newline
 (c-mode . ((indent-tabs-mode . t)      ; tabulations pour l'indentation,
            (tab-width . 4)             ; espaces pour l'alignement
            (c-basic-offset . 4)        ; .clang-format UseTab: ForIndentation,
            (fill-column . 100)))       ; IndentWidth/TabWidth: 4, ColumnLimit: 100
 (c++-mode . ((indent-tabs-mode . t)
              (tab-width . 4)
              (c-basic-offset . 4)
              (fill-column . 100)))
 (cmake-mode . ((indent-tabs-mode . nil)
                (tab-width . 4)
                (cmake-tab-width . 4)  ; .cmake-format.yaml format.tab_size: 4
                (fill-column . 100)))  ; .cmake-format.yaml format.line_width: 100
 (makefile-mode . ((indent-tabs-mode . t)  ; tabulations exigées par make
                   (tab-width . 4)))
 (yaml-mode . ((indent-tabs-mode . nil)
               (yaml-indent-offset . 2)))  ; défaut .editorconfig [*]
 (json-mode . ((indent-tabs-mode . nil)))
 (json-ts-mode . ((indent-tabs-mode . nil)
                  (json-ts-mode-indent-offset . 2))))  ; défaut .editorconfig [*]
