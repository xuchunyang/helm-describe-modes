;;; helm-describe-modes.el --- Helm interface to major and minor modes.  -*- lexical-binding: t; -*-

;; Copyright (C) 2016 Tianxiang Xiong

;; Author: Tianxiang Xiong <tianxiang.xiong@gmail.com>
;; Keywords: docs, convenience

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides a Helm interface to major and minor mode
;; information. It is intended as a replacement for `describe-mode',
;; `describe-minor-mode', and other related commands.
;;
;; This package is heavily inspired by the `helm-descbinds' package by
;; Taiki Sugawara.  See: https://github.com/emacs-helm/helm-descbinds

;;; Usage:

;; Add the following to your init file to remap `describe-mode' to
;; `helm-describe-modes':
;;
;;     (require 'helm-describe-modes)
;;     (global-set-key [remap describe-mode] #'helm-describe-modes)
;;
;; For information about the Helm framework, see the the Helm project:
;; https://github.com/emacs-helm/helm

;;; Code:

(eval-when-compile (require 'cl-lib))
(require 'helm)


;;; Customize
(defgroup helm-describe-modes nil
  "Helm interface to major and minor mode information."
  :prefix "helm-describe-modes-"
  :group 'helm)

(defcustom helm-describe-modes-function-list
  '(helm-def-source--major-mode
    helm-def-source--active-minor-modes
    helm-def-source--inactive-minor-modes)
  "List of functions that build Helm sources for `helm-describe-modes'."
  :group 'helm-describe-modes
  :type '(repeat (choice symbol)))

(defcustom helm-describe-modes-major-mode-actions
  '(("Describe major mode" .  helm-describe-function)
    ("Find major mode" .  helm-find-function)
    ("Customize major mode" .  (lambda (mode)
			  (customize-mode (intern-soft mode))))
    ("Set as initial major mode" .  (lambda (mode)
				     (customize-set-variable 'initial-major-mode
							     (intern-soft mode)))))
  "Actions for major mode."
  :group 'helm-describe-modes
  :type '(alist :key-type string :value-type function))

(defcustom helm-describe-modes-active-minor-mode-actions
  '(("Describe minor mode" .  describe-minor-mode)
    ("Find minor mode" .  helm-find-function)
    ("Turn off minor mode(s)" .  (lambda (_ignored)
				  (mapc (lambda (mode)
					  (funcall (intern-soft mode) -1))
					(helm-marked-candidates)))))
  "Actions for active minor modes."
  :group 'helm-describe-modes
  :type '(alist :key-type string :value-type function))

(defcustom helm-describe-modes-inactive-minor-mode-actions
  '(("Describe minor mode" .  describe-minor-mode)
    ("Find minor mode" .  helm-find-function)
    ("Turn on minor mode(s)" .  (lambda (_ignored)
				 (mapc (lambda (mode)
					 (funcall (intern-soft mode) t))
				       (helm-marked-candidates)))))
  "Actions for inactive minor modes."
  :group 'helm-describe-modes
  :type '(alist :key-type string :value-type function))


;;; Helm sources

(defun helm-describe-modes--minor-modes ()
  "Return a list of all minor modes.

Some older packages do not register in `minor-mode-list', only in
`minor-mode-alist'.  See `describe-mode' for more information."
  (let ((minor-modes minor-mode-list))
    (dolist (pair minor-mode-alist)
      (unless (memq (car pair) minor-mode-list)
	(push (car pair) minor-modes)))
    minor-modes))

(defun helm-describe-modes--active-minor-modes ()
  "Return a list of active minor modes.

This function assumes that each minor mode's toggle command and
control variable have the same name (which is the default
behavior when defining a minor mode).

See `define-minor-mode' for more information."
  (cl-remove-if-not (lambda (mode)
		      (and (boundp mode)
			   (symbol-value mode)))
		    (helm-describe-modes--minor-modes)))

(defun helm-def-source--major-mode ()
  "Return a `helm' source for the major mode."
  (helm-build-sync-source "Major mode"
    :action 'helm-describe-modes-major-mode-actions
    :candidates (list major-mode)
    :nomark t))

(defun helm-def-source--active-minor-modes ()
  "Return a `helm' source for active minor modes."
  (helm-build-sync-source "Active minor modes"
    :action 'helm-describe-modes-active-minor-mode-actions
    :candidates (helm-describe-modes--active-minor-modes)
    :candidate-transformer (lambda (modes)
			     (sort modes #'string-lessp))
    :persistent-action (lambda (mode)
			 (helm-elisp--persistent-help
			  mode 'describe-minor-mode))
    :persistent-help "Describe minor mode"))

(defun helm-def-source--inactive-minor-modes ()
  "Return a `helm' source for inactive minor modes.

This is the set of all minor modes excluding active minor
modes.  See `helm-describe-modes--minor-modes' and
`helm-describe-modes--active-minor-modes' for more information."
  (helm-build-sync-source "Inactive minor modes"
    :action 'helm-describe-modes-inactive-minor-mode-actions
    :candidates (cl-set-difference (helm-describe-modes--minor-modes)
				   (helm-describe-modes--active-minor-modes))
    :candidate-transformer (lambda (modes)
			     (sort modes #'string-lessp))
    :persistent-action (lambda (mode)
			 (helm-elisp--persistent-help
			  mode 'describe-minor-mode))
    :persistent-help "Describe minor mode"))


;;; Autoloads

;;;###autoload
(defun helm-describe-modes ()
  "A convenient Helm version of `describe-mode'.

By default, it lists the major mode, active minor modes, and
inactive minor modes.  Sources can be added or removed by
customizing `helm-describe-modes-function-list'."
  (interactive)
  (helm :sources (mapcar (lambda (func)
			   (funcall func))
			 helm-describe-modes-function-list)
	:buffer "*helm modes*"))


;;; Provide
(provide 'helm-describe-modes)

;;; helm-describe-modes.el ends here