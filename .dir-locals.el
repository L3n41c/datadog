;;; .dir-locals.el --- Project-local style settings for Emacs.
;;;
;;; Loaded automatically by Emacs when opening any file of the project.
;;;
;;; Deliberate constraint: NO save hook here (no before-save-hook, no
;;; reformatting on save). When to reformat one's files is a personal
;;; choice, to be set in one's own user configuration
;;; (~/.config/emacs/init.el), not in every repository.
;;;
;;; These settings mirror .editorconfig, .clang-format and .cmake-format.yaml:
;;;   - C/C++     : tab indentation (width 4), 100 columns
;;;   - CMake     : 4-space indentation, 100 columns
;;;   - Makefiles : tab indentation (required by make)
;;;   - the rest  : 2-space indentation (default of .editorconfig [*])

((nil . ((indent-tabs-mode . nil)       ; spaces by default (.editorconfig [*])
         (tab-width . 4)                ; display width of a tab
         (require-final-newline . t)))  ; .editorconfig insert_final_newline
 (c-mode . ((indent-tabs-mode . t)      ; tabs for indentation,
            (tab-width . 4)             ; spaces for alignment
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
 (makefile-mode . ((indent-tabs-mode . t)  ; tabs required by make
                   (tab-width . 4)))
 (yaml-mode . ((indent-tabs-mode . nil)
               (yaml-indent-offset . 2)))  ; default .editorconfig [*]
 (json-mode . ((indent-tabs-mode . nil)))
 (json-ts-mode . ((indent-tabs-mode . nil)
                  (json-ts-mode-indent-offset . 2))))  ; default .editorconfig [*]
