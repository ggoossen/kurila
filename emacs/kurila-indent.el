
(defun kurila-util-filter (predicate list)
  "Filter LIST using PREDICATE.
    PREDICATE is called for every item in LIST.  All items for which
    PREDICATE returns non-nil are returned in a list."
  (let (new)
    (dolist (item list)
      (when (funcall predicate item)
        (setq new (cons item new))))
    (nreverse new)))


(defun kurila-sniff-for-paren-open ()
  (save-excursion
    (let ((eol (progn (end-of-line) (point)))
          (bol (progn (beginning-of-line) (point)))
          indents)
      (beginning-of-line)
      (kurila-update-syntaxification bol eol)
      (skip-chars-forward "^(")
      (if (< (point) eol)
          (let ((p (point)) endp state)
            (forward-char)
            (setq state (parse-partial-sexp (point) (+ eol 1) -1))
            (setq endp (point))
            (goto-char p)
            (forward-char)
            (skip-chars-forward " ")
            (if (> endp eol)
                (setq indents (cons (- (point) bol) indents)))
            ))
      indents
      )))

(defun kurila-sniff-for-block-start ()
  ;; Looks at the current line for a possible block starts, returns a list of positions for new blocks,
  ;; with possibly 'next-line at the end indicating the block is started at the next line
  (save-excursion
    (let (bol eol points)
      (beginning-of-line)
      (setq bol (point))
      (end-of-line)
      (setq eol (point))
      (end-of-line)
      (while (and (>= (point) bol)
                  (re-search-backward (concat "\\((\\)"
                                             "\\|"
                                             "\\()\\)"
                                             "\\|"
                                             "\\(sub\\)"
                                             "\\|"
                                              "\\(else\\)"
                                             )
                                     bol t))
        (cond 
         ;; "("
         ((match-beginning 1)
          (let ((pt (point)))
            (setq points (cons (- pt bol) points))))
         ;; ")"
         ((match-beginning 2)
          (let ((pt (point)))
            (let ((new-point (and (not (looking-at ")[[:space:]]*{"))
                                  (if (looking-at "\\s*\\(#\\|$\\)")
                                      (- (point) bol)
                                    'next-line))))
              (forward-char)
              (backward-sexp)
              (skip-syntax-backward " ")
              (if (looking-back "if\\|\\unless\\|for\\|foreach\\|while\\|until" 7)
                  (if new-point
                      (setq points (cons new-point points))))
            )))
         ;; sub
         ((match-beginning 3)
          (if (not (nth 8 (syntax-ppss)))
              (setq points (cons 'next-line points))))
         ;; keyword which starts a new block
         ((match-beginning 4)
          (unless (looking-at "else [[:space:]]*{")
            (if (looking-at "\\s*\\(#\\|$\\)")
                (setq points (cons (- (point) bol) points))
              (setq points (cons 'next-line points)))))
        ))
      (and (< (+ bol (current-indentation)) eol)
           (setq points (cons (current-indentation) points)))
      (message (format "points - %s" points))
      points
      )))
  
(defun kurila-sniff-preindent-point ()
  ;; Returns the start of the line, which is the indenting of the current line.
  (let ((pre-indent-point (point)))
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
    pre-indent-point
    ))

(defun kurila-sniff-for-layout-lists ()
  ;; Returns a list of indentation-levels at which a new layout list
  ;; is started.
  (save-excursion
    (let (indents
          (start-line-point (line-beginning-position)))
      (while (> (line-beginning-position) 1)
        (forward-line -1)
        (let
            ((eol (line-end-position))
             (bol (line-beginning-position)))
          (kurila-update-syntaxification bol eol)
          (end-of-line)
          (while (re-search-backward ":" bol t)
            (save-excursion
              (forward-char)
              (skip-syntax-forward " ")
              (while (and (< (point) (point-max))
                          (= (point) (line-end-position)))
                (forward-line 1)
                (skip-syntax-forward " "))
              (if (>= (point) start-line-point)
                  (setq indents (cons 'new-layout-list indents))
                (setq indents (cons (- (point) (line-beginning-position)) indents)))
              )))
        )
      (reverse indents)
      )))

(defun kurila-sniff-for-indent (&optional parse-data)
  ;; Old workhorse for calculation of indentation; the major problem
  ;; is that it mixes the sniffer logic to understand what the current line
  ;; MEANS with the logic to actually calculate where to indent it.
  ;; The latter part should be eventually moved to `kurila-calculate-indent';
  ;; actually, this is mostly done now...
  ;; possible returns values:
  ;;   'cont-expr (...)
  ;;
  ;;   'code-start-in-block <previous-indentation-level>          
  ;;        A new block is expected, for example
  ;;        "if (condition)", previous-indentation-level would the
  ;;        indentation level of the "if".
  ;;
  ;;   'statement (<list-of-possible-indentation-levels>)
  ;;        A new statement is expected or possibly a continuation of
  ;;        the previous one, all previous indentation levels are returned
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
	       (pre-indent-point (kurila-sniff-preindent-point))
	       p prop look-prop is-block delim)
	  (goto-char pre-indent-point)	; Orig line skipping preceeding pod/etc
          (kurila-backward-to-noncomment nil)
          (let ((blocks (kurila-sniff-for-block-start))
                (first-paren (car (reverse (kurila-sniff-for-paren-open))))
                )
            (if first-paren
                (vector 'cont-expr (list first-paren (car blocks)))
              (if (eq (elt blocks (- (length blocks) 1)) 'next-line)
                  (vector 'code-start-in-block (car blocks))
                (progn
                  (setq blocks (reverse blocks))
                  (while (and (or (not blocks) (> (car blocks) 0))
                              (= (forward-line -1) 0))
                    (let ((new-blocks (kurila-sniff-for-block-start)))
                      (while (and new-blocks 
                                  (not (eq (car new-blocks) 'next-line))
                                  (< (car new-blocks) (car blocks)))
                        (setq blocks (cons (car new-blocks) blocks))
                        (setq new-blocks (cdr new-blocks))
                        )))
                  (setq blocks (reverse blocks))
                  (vector 'statement blocks)))
            ))))))))

(defun kurila-indent-indentation-info (&optional start)
  "Return a list of possible indentations for the current line.
These are then used by `kurila-indent-cycle'.
START if non-nil is a presumed start pos of the current definition."
  (let* (parse-data
         (sniff (kurila-sniff-for-indent parse-data))
         (sniff-i (elt sniff 1))
         (indentation 0)
         (indentations '((0)))
         )
    (message (format "sniff: %s" sniff))
    (cond
     ((eq (elt sniff 0) 'code-start-in-block)
      (setq indentations (list (list (+ sniff-i 4))))
      )
     ((eq (elt sniff 0) 'statement)
      (setq indentations (append (list (list (car sniff-i))
                                       (list (+ (car sniff-i) 4)))
                                 (mapcar 'list (cdr sniff-i)))))
     ((eq (elt sniff 0) 'cont-expr)
      (setq indentations (list (list (car sniff-i)) (list (+ (car sniff-i) 4))))
      )
      )
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
