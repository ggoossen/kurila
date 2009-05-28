
(defun kurila-indent-indentation-info (&optional start)
  "Return a list of possible indentations for the current line.
These are then used by `kurila-indent-cycle'.
START if non-nil is a presumed start pos of the current definition."
  (print (kurila-sniff-for-indent nil) (get-buffer "*Messages*"))
  '((0) (4) (8) (12)))

(defvar kurila-indent-last-info nil)


(defun kurila-indent-cycle ()
  "Indentation cycle.
We stay in the cycle as long as the TAB key is pressed."
  (interactive "*")

  (let ((marker (if (> (current-column) (current-indentation))
                    (point-marker)))
        (bol (progn (beginning-of-line) (point))))
    (back-to-indentation)
    (unless (and (eq last-command this-command)
                 (eq bol (car kurila-indent-last-info)))
      (save-excursion
        (setq kurila-indent-last-info
              (list bol (kurila-indent-indentation-info) 0 0))))
    
    (let* ((il (nth 1 kurila-indent-last-info))
           (index (nth 2 kurila-indent-last-info))
           (last-insert-length (nth 3 kurila-indent-last-info))
           (indent-info (nth index il)))

      (indent-line-to (car indent-info)) ; insert indentation
      (delete-char last-insert-length)
      (setq last-insert-length 0)
      (let ((text (cdr indent-info)))
        (if text
            (progn
              (insert text)
              (setq last-insert-length (length text)))))

      (setq kurila-indent-last-info
            (list bol il (% (1+ index) (length il)) last-insert-length))

      (if (= (length il) 1)
          (message "Sole indentation")
        (message "Indent cycle (%d)..." (length il)))

      (if marker
          (goto-char (marker-position marker))))))

;; mode

(defvar kurila-indent-mode nil
  "Indicates if the semi-intelligent Haskell indentation mode is in effect
in the current buffer.")
(make-variable-buffer-local 'kurila-indent-mode)

(defun turn-on-kurila-indent ()
  "Turn on ``intelligent'' kurila indentation mode."
  (set (make-local-variable 'indent-line-function) 'kurila-indent-cycle)
  (setq kurila-indent-mode t)
  (run-hooks 'kurila-indent-hook))

(defun turn-off-kurila-indent ()
  "Turn off ``intelligent'' kurila indentation mode that deals with
the layout rule of Haskell."
  (kill-local-variable 'indent-line-function)
  (setq kurila-indent-mode nil))

;;;###autoload
(defun kurila-indent-mode (&optional arg)
  "``intelligent'' Kurila indentation mode

Invokes `kurila-indent-hook' if not nil."
  (interactive "P")
  (setq kurila-indent-mode
        (if (null arg) (not kurila-indent-mode)
          (> (prefix-numeric-value arg) 0)))
  (if kurila-indent-mode
      (turn-on-kurila-indent)
    (turn-off-kurila-indent)))

(provide 'kurila-indent)
