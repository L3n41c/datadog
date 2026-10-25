;;; .dir-locals.el — Project-local Emacs configuration for code formatting only.
;;; These settings mirror .clang-format and .editorconfig.
;;; Personal preferences belong in ~/.config/emacs/init.el, not here.
;;;
;;; Loaded automatically by Emacs when visiting any file in this project.

((nil . ((;; --- Indentation: tabs for indentation (matches .clang-format UseTab: ForIndentation) ---
          (indent-tabs-mode . t)
          (tab-width . 4)
          (c-basic-offset . 4)

          ;; --- Line length (matches .clang-format ColumnLimit: 100) ---
          (fill-column . 100)

          ;; --- File encoding and line endings (matches .editorconfig) ---
          (require-final-newline . t)

          ;; --- Trailing whitespace (matches .editorconfig trim_trailing_whitespace) ---
          (before-save-hook . delete-trailing-whitespace)

          ;; --- Use project .clang-format for formatting ---
          (c-set-style . "file")))))
