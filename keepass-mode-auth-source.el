;;; keepass-mode-auth-source.el ---   -*- lexical-binding: t; coding: utf-8 -*-

;; Copyright (C)  5 April 2026
;;

;; Author: Sébastien Le Maguer <sebastien.lemaguer@helsinki.fi>

;; Package-Requires: ((emacs "25.2"))
;; Keywords:
;; Homepage:

;; keepass-mode-auth-source is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; keepass-mode-auth-source is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with keepass-mode-auth-source.  If not, see http://www.gnu.org/licenses.

;;; Commentary:


;;; Code:

(require 'cl-lib)
(require 'keepass-mode)
(require 'auth-source)

(cl-defun keepass-mode-auth-source-search (&rest spec
                                                 &key backend type host user port max title
                                                 &allow-other-keys)
  (let ((entity (slot-value backend 'source)))
    (with-current-buffer (find-file-noselect (expand-file-name entity))
      (let* ((search-host (if port (format "%s:%s" host port) host))
             (search-host (s-replace-regexp "^\\([^:]+://\\)?" "https://" search-host))
             (list-entries (split-string (keepass-mode-call-command search-host "search") "\n" 1))
             (filled-entries (cl-map 'list
                                     (lambda (entry)
                                       (keepass-mode-read-data-from-string
                                        (keepass-mode-call-command (keepass-mode-quote-unless-empty entry) "show -s --all")))
                                     list-entries))
             (filtered-entries (seq-filter (lambda (entry)
                                             (and (or (not user)
                                                      (string= (keepass-mode-get-value-from-alist "UserName" entry) user))
                                                  (string= (keepass-mode-get-value-from-alist "URL" entry) search-host)))
                                           filled-entries))
             (entry (car filtered-entries))
             (password (keepass-mode-get-value-from-alist "Password" entry))
             ;; (host (keepass-mode-get-value-from-alist "URL" entry))
             (login (keepass-mode-get-value-from-alist "UserName" entry)))
        (list (list
               :host host
               :user user
               :port port
               :secret password
               :searched-host search-host
               :backend 'keepass))))))


(defun keepass-auth-source-backend-parser (entry)
  "Provides keepass backend for files with the .kdbx extension."
  (when (and (stringp entry)
             (string-equal "kdbx" (file-name-extension entry)))
    (auth-source-backend :type 'keepass
                         :source entry
                         :search-function #'keepass-mode-auth-source-search)))

;;;###autoload
(defun keepass-auth-source-enable ()
  "Enable keepass auth source."
  (interactive)
  (auth-source-forget-all-cached)
  (if (boundp 'auth-source-backend-parser-functions)
      (add-hook 'auth-source-backend-parser-functions #'keepass-auth-source-backend-parser)
    (advice-add 'auth-source-backend-parse :before-until #'keepass-auth-source-backend-parser)))

(provide 'keepass-mode-auth-source)

;;; keepass-mode-auth-source.el ends here
