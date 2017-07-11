;;; inf-coffee.el --- Run a Coffee process in a buffer

;; Copyright (C) 2017 Brantou

;; Author: Brantou <brantou89@gmail.com>
;; URL: http://github.com/brantou/inf-coffee
;; Keywords: languages coffee
;; Version: 0.0.1

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; This file is not part of GNU Emacs.

;;; Commentary:
;;
;; inf-coffee provides a REPL buffer connected to a Coffee subprocess.
;;

;;; Code:

(require 'comint)
(require 'coffee-mode)

(defgroup inf-coffee nil
  "Run Coffee process in a buffer"
  :group 'languages)

(defcustom inf-coffee-prompt-read-only t
  "If non-nil, the prompt will be read-only.

Also see the description of `ielm-prompt-read-only'."
  :type 'boolean
  :group 'inf-coffee)

(defcustom inf-coffee-implementations
  '(("coffee" . "coffee")
    ("nesh"   . "nesh -c"))
  "An alist of coffee implementations to coffee executable names."
  :type '(repeat (cons string string))
  :group 'inf-coffee)

(defcustom inf-coffee-default-implementation "coffee"
  "Which Coffee implementation to use if none is specified."
  :type `(choice ,@(mapcar (lambda (item) (list 'const (car item)))
                           inf-coffee-implementations))
  :group 'inf-coffee)

(defvar inf-coffee-prompt "^[^>\n[:space:]]*> *")

(defvar inf-coffee-mode-map
  (let ((map (copy-keymap comint-mode-map)))
    (define-key map (kbd "TAB") 'completion-at-point)
    map)
  "Mode map for `inf-coffee-mode'.")

(defvar inf-coffee-buffer nil "The oldest live Coffee process buffer.")

(defvar inf-coffee-buffers nil "List of Coffee process buffers.")

(defvar inf-coffee-buffer-command nil "The command used to run Coffee shell")
(make-variable-buffer-local 'inf-coffee-buffer-command)

(defvar inf-coffee-buffer-impl-name nil "The name of the Coffee shell")
(make-variable-buffer-local 'inf-coffee-buffer-impl-name)

(define-derived-mode inf-coffee-mode comint-mode "Inf-Coffee"
  "Major mode for interacting with an inferior Coffee REPL process."
  :syntax-table coffee-mode-syntax-table
  (set (make-local-variable 'indent-tabs-mode) nil)
  (setq-local font-lock-defaults '((coffee-font-lock-keywords)))
  (setq comint-prompt-regexp inf-coffee-prompt)
  (set (make-local-variable 'paragraph-separate) "\\'")
  (set (make-local-variable 'paragraph-start) comint-prompt-regexp)
  (setq comint-process-echoes t)
  (setq comint-input-ignoredups t)
  (set (make-local-variable 'comint-prompt-read-only) inf-coffee-prompt-read-only)
  (add-hook 'comint-output-filter-functions 'inf-coffee-output-filter nil t)
  (add-hook 'comint-preoutput-filter-functions
            (lambda (output)
              (replace-regexp-in-string
               "\\(\x1b\\[[0-9]+[GJK]\\|^[ \t]*undefined[\r\n]+\\)" ""
               output))
            nil t)
  (setq comint-get-old-input 'inf-coffee-get-old-input)
  (use-local-map inf-coffee-mode-map)
  (ansi-color-for-comint-mode-on))

(defvar coffee-last-coffee-buffer nil
  "The last buffer we switched to `inf-coffee' from.")
(make-variable-buffer-local 'coffee-last-coffee-buffer)

(defun coffee-remember-coffee-buffer (buffer)
  (setq coffee-last-coffee-buffer buffer))

(defun inf-coffee-output-filter (string)
  "Filter extra escape sequences from output."
  (let ((beg (or comint-last-output-start
                 (point-min-marker)))
        (end (process-mark (get-buffer-process (current-buffer)))))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              "\\(\x1b\\[[0-9]+[GJK]\\|^[ \t]*undefined[\r\n]+\\)" end t)
        (replace-match "")))))

(defun inf-coffee-get-old-input nil
  ;; Return the previous input surrounding point
  (save-excursion
    (beginning-of-line)
    (unless (looking-at-p comint-prompt-regexp)
      (re-search-backward comint-prompt-regexp))
    (comint-skip-prompt)
    (buffer-substring (point) (progn (forward-sexp 1) (point)))))

;;;###autoload
(defun run-coffee (command &optional name)
  "Run an inferior Coffee process, input and output in a new buffer.

The consecutive buffer names will be:
`*NAME*', `*NAME*<2>', `*NAME*<3>' and so on.

NAME defaults to \"coffee\".

Runs the hooks `comint-mode-hook' and `inf-coffee-mode-hook'.

\(Type \\[describe-mode] in the process buffer for the list of commands.)"
  (setq name (or name "Coffee"))

  (let* ((buffer-name (format "*%s*" name))
         (proc-buffer (comint-check-proc buffer-name)))
    (if proc-buffer
        (pop-to-buffer buffer-name)
      (let ((commandlist (split-string-and-unquote command))
            (buffer (current-buffer))
            (process-environment process-environment))
        (setenv "PAGER" (executable-find "cat"))
        (setenv "NODE_NO_READLINE" "1")
        (set-buffer (apply 'make-comint-in-buffer
                           name
                           buffer-name
                           (car commandlist)
                           nil (cdr commandlist)))
        (inf-coffee-mode)
        (coffee-remember-coffee-buffer buffer)
        (push (current-buffer) inf-coffee-buffers)
        (setq inf-coffee-buffer-impl-name name
              inf-coffee-buffer-command command)
        (unless (and inf-coffee-buffer (comint-check-proc inf-coffee-buffer))
          (setq inf-coffee-buffer (current-buffer)))
        (pop-to-buffer (current-buffer))))))

(provide 'inf-coffee)
;;; inf-coffee.el ends here
