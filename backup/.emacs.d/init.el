;;; init.el --- Emacs Initialization File -*- lexical-binding: t; -*-

(setq inhibit-startup-screen t)
(setq initial-scratch-message nil)
(setq initial-major-mode 'fundamental-mode)
;;(setq initial-buffer-choice t)
;;(setq initial-buffer-choice "~/path/to/your/file.txt")

;; Package Management
(require 'package)
(add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/") t)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; Use the `use-package` package for managing other packages
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; multiple cursors 
(use-package multiple-cursors
  :ensure t)

;; Install and configure Magit
(use-package magit
  :ensure t
  :bind (("C-x g" . magit-status)))

;; Ensure modus-themes package is installed
(use-package modus-themes
  :ensure t)

;; Set up automatic theme switching based on macOS system appearance (light/dark mode)
(use-package auto-dark
  :ensure t
  :init
  (setq auto-dark-allow-osascript t)
  :custom
  (auto-dark-light-theme 'modus-operandi) ; Built-in high-contrast light theme
  (auto-dark-dark-theme 'modus-vivendi)   ; Built-in high-contrast dark theme
  :config
  (auto-dark-mode 1))

;; Enable smooth scrolling and improve rendering
(setq redisplay-dont-pause t
      scroll-margin 1
      scroll-step 1
      scroll-conservatively 10000
      scroll-preserve-screen-position 1)

;; Make title bar blend in with the theme on macOS (Emacs Mac Port / NS Port)
(add-to-list 'default-frame-alist '(ns-appearance . dark))
(add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))

;; Set up font using the best practice face attributes on macOS
(set-face-attribute 'default nil
                    :family "Menlo"      ; macOS built-in coding font (or "SF Mono", "Fira Code", etc.)
                    :height 260          ; 1/10th of a point (260 = 26pt)
                    :weight 'normal)

;; Add a touch of line spacing for code readability (10% of font height)
(setq-default line-spacing 0.1)

;; Set line numbers
(global-display-line-numbers-mode t)

;; Enable syntax highlighting
(global-font-lock-mode t)

;; Enable column numbers
(column-number-mode t)

;; Set up basic UI improvements
(menu-bar-mode -1)       ;; Disable the menu bar
(tool-bar-mode -1)       ;; Disable the tool bar
(scroll-bar-mode -1)     ;; Disable the scroll bar

;; CIDER - Clojure(Script) Interactive Development Environment that Rocks
(use-package cider
  :ensure t
  :bind (("C-c u" . cider-user-ns)
         ("C-M-r" . cider-refresh))
  :config
  (setq org-babel-clojure-backend 'cider)
  (setq cider-show-error-buffer t
        cider-auto-select-error-buffer t
        cider-repl-history-file (expand-file-name "cider-history" user-emacs-directory)
        cider-repl-pop-to-buffer-on-connect t
        cider-repl-wrap-history t)
  
  ;; Hook CIDER to both standard Clojure and Tree-Sitter Clojure modes
  (add-hook 'clojure-mode-hook #'cider-mode)
  (add-hook 'clojure-ts-mode-hook #'cider-mode)

  ;; Custom helper functions from the Clojure for the Brave and True config
  (defun cider-start-http-server ()
    (interactive)
    (cider-load-buffer)
    (let ((ns (cider-current-ns)))
      (cider-repl-set-ns ns)
      (cider-interactive-eval (format "(println '(def server (%s/start))) (println 'server)" ns))
      (cider-interactive-eval (format "(def server (%s/start)) (println server)" ns))))

  (defun cider-refresh ()
    (interactive)
    (cider-interactive-eval (format "(user/reset)")))

  (defun cider-user-ns ()
    (interactive)
    (cider-repl-set-ns "user")))

;; Paredit - structural editing for Lisp/Clojure code
(use-package paredit
  :ensure t
  :hook ((clojure-mode . paredit-mode)
         (clojure-ts-mode . paredit-mode)
         (cider-repl-mode . paredit-mode)
         (emacs-lisp-mode . paredit-mode)
         (lisp-mode . paredit-mode)))

;; clj-refactor - extra refactorings for Clojure
(use-package clj-refactor
  :ensure t
  :hook ((clojure-mode . clj-refactor-mode)
         (clojure-ts-mode . clj-refactor-mode))
  :config
  (cljr-add-keybindings-with-prefix "C-c C-m"))

;; cider-hydra - menu of CIDER commands
(use-package cider-hydra
  :ensure t
  :hook ((clojure-mode . cider-hydra-mode)
         (clojure-ts-mode . cider-hydra-mode)))

;; Enable subword-mode for Clojure to treat camelCase words as separate
(add-hook 'clojure-mode-hook #'subword-mode)
(add-hook 'clojure-ts-mode-hook #'subword-mode)

;; org mode - load languages for babel
(use-package org
  :ensure t
  :config
  ;; Ensure language major modes are installed (required for Babel evaluation)
  (dolist (lang-pkg '(go-mode rust-mode elixir-mode scala-mode))
    (unless (package-installed-p lang-pkg)
      (package-install lang-pkg)))
  
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (clojure . t)
     (python . t)
     (js . t)
     (css . t)
     (sql . t)
     (C . t)        ; handles C and C++
     (go . t)
     (rust . t)
     (shell . t))))

;; Configure backups
(setq backup-directory-alist `(("." . "~/.emacs.d/backups")))

;; Configure autosave
;;(setq auto-save-file-name-transforms
;;     `((".*" "~/.emacs.d/autosave/" t)))

;; Add custom directory to load path
;; (add-to-list 'load-path "~/.emacs.d/custom/")

;; Add latest Org mode to load path safely (only if the path exists).
(let ((org-path (expand-file-name "/path/to/org-mode/lisp")))
  (when (file-directory-p org-path)
    (add-to-list 'load-path org-path)))

;; Add any additional custom configurations here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages nil))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;; Refresh all open buffers from their respective files.
(defun revert-all-buffers ()
  "Refresh all open buffers from their respective files."
  (interactive)
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (and (buffer-file-name) (not (buffer-modified-p)))
        (revert-buffer t t t))))
  (message "All non-modified buffers reverted."))

(global-set-key (kbd "C-c R") 'revert-all-buffers)  ;; Bind to Ctrl + c, Shift + r


;; initial frame setup - experiment 
(when (display-graphic-p)
  (toggle-frame-fullscreen))
;;(list-buffers)
;;(global-visual-line-mode 1) ;; soft wrap text globally
(recentf-mode 1) ;; recent files history is saved 
(savehist-mode 1) ;; recent commands history is saved | use M-n (next-history-element) and M-p (previous-history-element) 
(setq history-length 25) ;; saves n recent commands 
(save-place-mode 1) ;; saves cursor location on files 
(global-auto-revert-mode 1) ;; refreshes all buffers
(setq global-auto-revert-non-file-buffers t) ;; refreshes non-file buffers (eg: folders)

;; display commands and keypresses
;;(split-window-vertically)
;;(view-lossage) ;; C-h l

;; Install ESS - Emacs speaks statistics - R 
(use-package ess
  :ensure t)

;; company - complete anything
(use-package company
  :ensure t
  :hook (after-init . global-company-mode)
  :config
  (setq company-idle-delay 0.2)  ; time in seconds before suggestions pop up
  (setq company-minimum-prefix-length 1)  ; minimum prefix length for suggestions
  (setq company-show-numbers t)  ; show numbers for quick selection
  (setq company-tooltip-align-annotations t)  ; align annotations to the right tooltip border
  (company-tng-configure-default) ; company tab and go - minor mode 
  ;; (company-statistics-mode) ; sort completion candidates 
  )

;; lsp mode
(use-package lsp-mode
  :ensure t
  :commands (lsp lsp-deferred)
  ;; Hook LSP to specific programming languages to avoid trying to run it in
  ;; modes without server support (like Emacs Lisp / elisp-mode).
  :hook ((clojure-mode . lsp)
         (clojure-ts-mode . lsp)
         (python-mode . lsp)
         (python-ts-mode . lsp)
         (lisp-mode . lsp))
  :config
  (setq lsp-log-io t) ; show logs for debugging
  (require 'lsp-clojure))

;; optional: lsp ui settings
(use-package lsp-ui
  :ensure t
  :commands lsp-ui-mode
  :hook (lsp-mode . lsp-ui-mode)
  :config
  (setq lsp-ui-doc-enable t  ; enable inline documentation
        lsp-ui-doc-position 'at-point  ; position of the documentation
        lsp-ui-sideline-enable t  ; enable sideline diagnostics
        lsp-ui-sideline-show-hover t)  ; show hover information in the sideline
  )

;; optional: customize lsp ui settings
;; lsp for python
;; brew install -g pyright ;; for python
;; (require 'lsp-pyright)
;; (add-hook 'python-mode-hook #'lsp)
;; lsp for java
;; (require 'lsp-java)
;; (add-hook 'java-mode-hook #'lsp)

;; tree sitter
(setq treesit-language-source-alist
   '((clojure "https://github.com/sogaiu/tree-sitter-clojure")
     (python "https://github.com/tree-sitter/tree-sitter-python")))
(setq major-mode-remap-alist
 '((clojure-mode . clojure-ts-mode)
   (python-mode . python-ts-mode)))
;; M-x treesit-install-language-grammar ; manually install languages

;; insert λ greek notation for λ calculus 
(global-set-key (kbd "C-c l") (lambda () (interactive) (insert "λ")))

;; ensure aspell is used as the spell checker
(setq ispell-program-name "aspell")
(setq ispell-extra-args '("--sug-mode=ultra"))  ; optional: improve performance
(add-hook 'org-mode-hook 'flyspell-mode) ; enable flyspell-mode only in Org mode

;; gptel - A simple LLM client for Emacs, configured for Ollama
(use-package gptel
  :ensure t
  :bind (("C-c g s" . gptel-send)
         ("C-c g m" . gptel-menu))
  :config
  ;; Register Ollama backend
  (gptel-make-ollama "Ollama"
    :host "localhost:11434"
    :stream t
    :models '("qwen3.8:27b-mlx"
              "muse-glimmer:30b-mlx"
              "llama3.1:latest"
              "llama3.2:latest"
              "gemma4:e4b-mlx"
              "qwen2.5:14b"
              "qwen3.6:35b-a3b-coding-nvfp4"
              "qwen3-coder:30b"
              "deepseek-r1:14b"))

  ;; Register Gemini backend and set it as default
  (setq gptel-backend
        (gptel-make-gemini "Gemini"
          :key (lambda ()
                 (let ((pass-bin (or (executable-find "pass")
                                     (and (file-executable-p "/opt/homebrew/bin/pass") "/opt/homebrew/bin/pass")
                                     (and (file-executable-p "/usr/local/bin/pass") "/usr/local/bin/pass")
                                     "pass")))
                   (string-trim (shell-command-to-string (concat pass-bin " GEMINI_API_KEY")))))
          :stream t
          :models '("gemini-3.6-flash"
                    "gemini-3.5-flash"
                    "gemini-3.5-flash-lite"
                    "gemini-3.1-pro-preview"
                    "gemini-3.1-flash-lite"
                    "gemini-2.5-flash"
                    "gemini-2.5-pro"
                    "gemini-1.5-flash"
                    "gemini-1.5-pro")))

  ; (setq gptel-model "muse-glimmer:30b-mlx")
  (setq gptel-model "gemini-3.5-flash-lite")
  ; (setq gptel-model "qwen2.5:14b")
  ; (setq gptel-model "qwen3.6:35b-a3b-coding-nvfp4")
  (setq gptel-default-mode 'org-mode)
  
  ;; Configure global temperature (0.0 = deterministic/factual, 1.0+ = creative)
  (setq gptel-temperature 1.0)

  ;; Advise request-data to inject top_p and top_k parameters for Ollama
  (advice-add 'gptel--request-data :filter-return
              (lambda (request-data)
                (when (and (boundp 'gptel-backend)
                           (fboundp 'gptel-ollama-p)
                           (gptel-ollama-p gptel-backend))
                  (let* ((options (plist-get request-data :options))
                         (updated-options (plist-put (plist-put options :top_p 0.9) :top_k 40)))
                    (plist-put request-data :options updated-options)))
                request-data)))


;; list buffers
(list-buffers)

;; Bind C-x C-b to list buffers (if it was overridden)
(global-set-key (kbd "C-x C-b") 'list-buffers)
(set-face-attribute 'region nil :background "darkslateblue")

(with-eval-after-load 'info
  (set-face-attribute 'info-index-match nil :background "darkslateblue"))

(with-eval-after-load 'pulse
  (set-face-attribute 'pulse-highlight-face nil :background "darkslateblue")
  (set-face-attribute 'pulse-highlight-start-face nil :background "darkslateblue"))

(with-eval-after-load 'xref
  (set-face-attribute 'xref-match nil :background "darkslateblue"))

