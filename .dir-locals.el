;;; .dir-locals.el — Project-local Emacs configuration for code formatting only.
;;; These settings mirror .clang-format and .editorconfig.
;;; Personal preferences belong in ~/.config/emacs/init.el, not here.
;;;
;;; Loaded automatically by Emacs when visiting any file in this project.

((nil . ((indent-tabs-mode . t)
         (tab-width . 4)
         (c-basic-offset . 4)
         (fill-column . 100)
         (require-final-newline . t)
         (before-save-hook . delete-trailing-whitespace))))
