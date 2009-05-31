

(defun kurila-sniff-for-block-start ()
  ;; Looks at the current line for a possible block starts, returns a list of positions for new blocks,
  ;; with possibly 'next-line at the end indicating the block is started at the next line
  (let (bol end points)
    (beginning-of-line)
    (setq bol (point))
    (end-of-line)
    (setq end (point))
    (beginning-of-line)
    (while (re-search-forward "sub\\s-+\\<\\w+\\>\\s-*" end t)
      (if (looking-at "(")
          (forward-sexp))
      (if (looking-at "\\s*\\(#\\|$\\)")
          (setq points (cons (- (point) bol) points))
        (setq points (cons 'next-line points))))
    (setq points (cons (current-indentation) points))
    points
  ))

(defun kurila-sniff-for-indent (&optional parse-data) ; was parse-start
  ;; Old workhorse for calculation of indentation; the major problem
  ;; is that it mixes the sniffer logic to understand what the current line
  ;; MEANS with the logic to actually calculate where to indent it.
  ;; The latter part should be eventually moved to `kurila-calculate-indent';
  ;; actually, this is mostly done now...
  (kurila-update-syntaxification (point) (point))
  (let ((res (get-text-property (point) 'syntax-type)))
    (save-excursion
      (cond
       ((and (memq res '(pod here-doc here-doc-delim format))
	     (not (get-text-property (point) 'indentable)))
	(vector res))
       ;; before start of POD - whitespace found since do not have 'pod!
       ((looking-at "[ \t]*\n=")
	(error "Spaces before POD section!"))
       ((and (not kurila-indent-left-aligned-comments)
	     (looking-at "^#"))
	[comment-special:at-beginning-of-line])
       ((get-text-property (point) 'in-pod)
	[in-pod])
       (t
	(beginning-of-line)
	(let* ((indent-point (point))
	       (char-after-pos (save-excursion
				 (skip-chars-forward " \t")
				 (point)))
	       (char-after (char-after char-after-pos))
	       (pre-indent-point (point))
	       p prop look-prop is-block delim)
	  (save-excursion		; Know we are not in POD, find appropriate pos before
	    (kurila-backward-to-noncomment nil)
	    (setq p (max (point-min) (1- (point)))
		  prop (get-text-property p 'syntax-type)
		  look-prop (or (nth 1 (assoc prop kurila-look-for-prop))
				'syntax-type))
	    (if (memq prop '(pod here-doc format here-doc-delim))
		(progn
		  (goto-char (kurila-beginning-of-property p look-prop))
		  (beginning-of-line)
		  (setq pre-indent-point (point)))))
	  (goto-char pre-indent-point)	; Orig line skipping preceeding pod/etc
          (kurila-backward-to-noncomment nil)
          (let ((blocks (kurila-sniff-for-block-start))
                )
            (if (eq (elt blocks (- (length blocks) 1)) 'next-line)
                (vector 'code-start-in-block (car blocks))
              (progn
                (while (and (> (car blocks) 0) 
                            (= (forward-line -1) 0))
                  (let ((new-blocks (kurila-sniff-for-block-start)))
                    (while (and new-blocks 
                                (not (eq (car new-blocks) 'next-line))
                                (< (car new-blocks) (elt blocks (- (length blocks) 1))))
                      (setq blocks (append blocks (list (car new-blocks))))
                      (setq new-blocks (cdr new-blocks))
                      )))
                (vector 'statement blocks)))
            )))))))

(defun kurila-indent-indentation-info (&optional start)
  "Return a list of possible indentations for the current line.
These are then used by `kurila-indent-cycle'.
START if non-nil is a presumed start pos of the current definition."
  (print (kurila-sniff-for-indent nil) (get-buffer "*Messages*"))
  (let* (parse-data
         (sniff (kurila-sniff-for-indent parse-data))
         (sniff-i (elt sniff 1))
         (indentation 0)
         (indentations '((0)))
         )
    (cond
     ((eq (elt sniff 0) 'code-start-in-block)
      (setq indentations (list (list (+ sniff-i 4))))
      )
     ((eq (elt sniff 0) 'statement)
      (setq indentations (append (list (list (car sniff-i))
                                       (list (+ (car sniff-i) 4)))
                                 (mapcar 'list (cdr sniff-i))))
      ))
    indentations
    ))

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
