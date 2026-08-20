;;; init.el --- Emacs Initialization File -*- lexical-binding: t; -*-

;; ==========================================
;; 1. Startup & Performance Optimization
;; ==========================================

;; Silence native compilation warnings if native compilation is supported
(when (boundp 'native-comp-async-report-warnings-errors)
  (setq native-comp-async-report-warnings-errors 'silent))

;; Temporary increase to garbage collection threshold to speed up startup
(setq gc-cons-threshold (* 50 1024 1024))
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 2 1024 1024))))

(setq inhibit-startup-screen t)
(setq initial-scratch-message nil)
(setq initial-major-mode 'fundamental-mode)

;; Add custom lisp folder to load path
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; ==========================================
;; 2. Emacs Custom File Redirection
;; ==========================================

;; Save Custom variables and faces in a separate file to keep init.el clean.
;; Loaded early so package setups can override or respect customized values.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; ==========================================
;; 3. Package Management Setup
;; ==========================================

(require 'package)
(add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/") t)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; Install use-package if not present
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; Profile startup using benchmark-init (must be after package setup)
;; To prevent use-package load failures on first-run, we manually check and install.
(unless (package-installed-p 'benchmark-init)
  (package-install 'benchmark-init))

(when (require 'benchmark-init nil 'noerror)
  (benchmark-init/activate))

;; ==========================================
;; 4. Core UI & Editor Customization
;; ==========================================

;; Basic UI element removal
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

;; Font & Line Settings
(set-face-attribute 'default nil
                    :family "Menlo"      ; macOS built-in coding font
                    :height 260          ; 26pt
                    :weight 'normal)

(setq-default line-spacing 0.1)
(setq-default truncate-lines t)
(global-display-line-numbers-mode -1)
(global-font-lock-mode t)
(column-number-mode t)

;; Title bar blend for macOS
(add-to-list 'default-frame-alist '(ns-appearance . dark))
(add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))

;; Smooth Scrolling Settings
(setq scroll-margin 1
      scroll-step 1
      scroll-conservatively 10000
      scroll-preserve-screen-position 1)

;; Highlight Regions & Xref matching faces
(set-face-attribute 'region nil :background "darkslateblue")

(with-eval-after-load 'info
  (set-face-attribute 'info-index-match nil :background "darkslateblue"))

(with-eval-after-load 'pulse
  (require 'pulse)
  (when (facep 'pulse-highlight-face)
    (set-face-attribute 'pulse-highlight-face nil :background "darkslateblue"))
  (when (facep 'pulse-highlight-start-face)
    (set-face-attribute 'pulse-highlight-start-face nil :background "darkslateblue")))

(with-eval-after-load 'xref
  (require 'xref)
  (when (facep 'xref-match)
    (set-face-attribute 'xref-match nil :background "darkslateblue")))

;; Fullscreen on launch (graphic only)
(when (display-graphic-p)
  (toggle-frame-fullscreen))

;; ==========================================
;; 5. History, Backup, & Persistence
;; ==========================================

(use-package recentf
  :ensure nil
  :config
  (recentf-mode 1))

(use-package savehist
  :ensure nil
  :init
  (setq history-length 25)
  :config
  (savehist-mode 1))

(use-package saveplace
  :ensure nil
  :config
  (save-place-mode 1))

(use-package autorevert
  :ensure nil
  :custom
  (global-auto-revert-non-file-buffers t)
  :config
  (global-auto-revert-mode 1))

;; Persist sessions (buffers/files) across restarts
(desktop-save-mode 1)

;; Configure Backups & Autosaves
(setq backup-directory-alist `(("." . "~/.emacs.d/backups")))

;; Load latest Org mode from custom load path if it exists
(let ((org-path (expand-file-name "/path/to/org-mode/lisp")))
  (when (file-directory-p org-path)
    (add-to-list 'load-path org-path)))

;; ==========================================
;; 6. Keybindings & General Utilities
;; ==========================================

;; Buffer reverting utility
(defun revert-all-buffers ()
  "Refresh all open buffers from their respective files."
  (interactive)
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (and (buffer-file-name) (not (buffer-modified-p)))
        (revert-buffer t t t))))
  (message "All non-modified buffers reverted."))

(global-set-key (kbd "C-c R") 'revert-all-buffers)
(global-set-key (kbd "C-x C-b") 'list-buffers)

;; Lambda character insertion
(global-set-key (kbd "C-c l") (lambda () (interactive) (insert "λ")))

;; Spellcheck configuration
(use-package ispell
  :ensure nil
  :custom
  (ispell-program-name "aspell")
  (ispell-extra-args '("--sug-mode=ultra")))

(use-package flyspell
  :ensure nil
  :hook (org-mode . flyspell-mode))

;; Initial buffer listing
(list-buffers)

;; ==========================================
;; 7. Themes & Aesthetics
;; ==========================================

(use-package modus-themes
  :defer t)

(use-package auto-dark
  :init
  (setq auto-dark-allow-osascript t)
  :custom
  (auto-dark-light-theme 'modus-operandi)
  (auto-dark-dark-theme 'modus-vivendi)
  :config
  (auto-dark-mode 1))

;; ==========================================
;; 8. General Coding Packages
;; ==========================================

(use-package multiple-cursors
  :bind (("C-S-c C-S-c" . mc/edit-lines)
         ("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)))

(use-package magit
  :bind (("C-x g" . magit-status)))

(use-package company
  :hook (after-init . global-company-mode)
  :config
  (setq company-idle-delay 0.2)
  (setq company-minimum-prefix-length 1)
  (setq company-show-numbers t)
  (setq company-tooltip-align-annotations t)
  (company-tng-configure-default))

;; Tree-sitter configuration
(use-package treesit
  :ensure nil
  :config
  (setq treesit-language-source-alist
        '((clojure "https://github.com/sogaiu/tree-sitter-clojure")
          (python "https://github.com/tree-sitter/tree-sitter-python")))
  (setq major-mode-remap-alist
        '((clojure-mode . clojure-ts-mode)
          (python-mode . python-ts-mode))))

;; LSP Settings
(use-package lsp-mode
  :commands (lsp lsp-deferred)
  :hook ((clojure-mode . lsp)
         (clojure-ts-mode . lsp)
         (python-mode . lsp)
         (python-ts-mode . lsp)
         (lisp-mode . lsp))
  :init
  (setq lsp-auto-guess-root t)
  (setq lsp-headerline-breadcrumb-enable nil)
  :config
  (setq lsp-log-io t)
  (require 'lsp-clojure))

(use-package lsp-ui
  :commands lsp-ui-mode
  :hook (lsp-mode . lsp-ui-mode)
  :config
  (setq lsp-ui-doc-enable t
        lsp-ui-doc-position 'at-point
        lsp-ui-sideline-enable t
        lsp-ui-sideline-show-hover t))

;; ==========================================
;; 9. Modular Configurations
;; ==========================================

(require 'setup-clojure)
(require 'setup-llm)

;; ==========================================
;; 10. Org Mode & Babel
;; ==========================================

;; Define Org-Babel language modes to be installed/deferred automatically
(use-package go-mode :defer t)
(use-package rust-mode :defer t)
(use-package elixir-mode :defer t)
(use-package scala-mode :defer t)

(use-package org
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (clojure . t)
     (python . t)
     (js . t)
     (css . t)
     (sql . t)
     (C . t)
     (go . t)
     (rust . t)
     (shell . t))))

;; ==========================================
;; 11. Language Statistics
;; ==========================================

(use-package ess
  :defer t)
