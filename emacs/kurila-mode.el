;;; kurila-mode.el --- Perl code editing commands for Emacs

;; Copyright (C) 1985, 86, 87, 91, 92, 93, 94, 95, 96, 97, 98, 99,
;;               2000, 2003, 2005, 2006
;;     Free Software Foundation, Inc.

;; Author: Ilya Zakharevich and Bob Olson
;; Maintainer: Ilya Zakharevich <ilyaz@cpan.org>
;; Keywords: languages, Perl

;; This file is part of GNU Emacs.

;;; This code started from the following message of long time ago
;;; (IZ), but Bob does not maintain this mode any more:

;;; From: olson@mcs.anl.gov (Bob Olson)
;;; Newsgroups: comp.lang.perl
;;; Subject: kurila-mode: Another perl mode for Gnuemacs
;;; Date: 14 Aug 91 15:20:01 GMT

;; Copyright (C) Ilya Zakharevich and Bob Olson

;; This file may be distributed
;; either under the same terms as GNU Emacs, or under the same terms
;; as Perl. You should have received a copy of Perl Artistic license
;; along with the Perl distribution.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Corrections made by Ilya Zakharevich ilyaz@cpan.org
;;; XEmacs changes by Peter Arius arius@informatik.uni-erlangen.de

;;; Commentary:

;; $Id: kurila-mode.el,v 5.23 2007/02/15 11:34:23 vera Exp vera $

;;; If your Emacs does not default to `kurila-mode' on Perl files:
;;; To use this mode put the following into
;;; your .emacs file:

;; (autoload 'perl-mode "kurila-mode" "alternate mode for editing Perl programs" t)

;; You can either fine-tune the bells and whistles of this mode or
;; bulk enable them by putting

;; (setq kurila-hairy t)

;; in your .emacs file.  (Emacs rulers do not consider it politically
;; correct to make whistles enabled by default.)

;; DO NOT FORGET to read micro-docs (available from `Perl' menu)   <<<<<<
;; or as help on variables `kurila-tips', `kurila-problems',         <<<<<<
;; `kurila-non-problems', `kurila-praise', `kurila-speed'.            <<<<<<

;; Additional useful commands to put into your .emacs file (before
;; RMS Emacs 20.3):

;; (setq auto-mode-alist
;;      (append '(("\\.\\([pP][Llm]\\|al\\)$" . perl-mode))  auto-mode-alist ))
;; (setq interpreter-mode-alist (append interpreter-mode-alist
;; 				        '(("miniperl" . perl-mode))))

;; The mode information (on C-h m) provides some customization help.
;; If you use font-lock feature of this mode, it is advisable to use
;; either lazy-lock-mode or fast-lock-mode.  I prefer lazy-lock.

;; Faces used now: three faces for first-class and second-class keywords
;; and control flow words, one for each: comments, string, labels,
;; functions definitions and packages, arrays, hashes, and variable
;; definitions.  If you do not see all these faces, your font-lock does
;; not define them, so you need to define them manually.
;; Maybe you have an obsolete font-lock from 19.28 or earlier.  Upgrade.

;; If you have a grayscale monitor, and do not have the variable
;; font-lock-display-type bound to 'grayscale, insert

;; (setq font-lock-display-type 'grayscale)

;; into your .emacs file (this is relevant before RMS Emacs 20).

;; This mode supports font-lock, imenu and mode-compile.  In the
;; hairy version font-lock is on, but you should activate imenu
;; yourself (note that mode-compile is not standard yet).  Well, you
;; can use imenu from keyboard anyway (M-x imenu), but it is better
;; to bind it like that:

;; (define-key global-map [M-S-down-mouse-3] 'imenu)

;;; Font lock bugs as of v4.32:

;; The following kinds of Perl code erroneously start strings:
;; \$`  \$'  \$"
;; $opt::s  $opt_s  $opt{s}  (s => ...)  /\s+.../
;; likewise with m, tr, y, q, qX instead of s

;;; In fact the version of font-lock that this version supports can be
;;; much newer than the version you actually have. This means that a
;;; lot of faces can be set up, but are not visible on your screen
;;; since the coloring rules for this faces are not defined.

;;; Code:

(if (fboundp 'eval-when-compile)
    (eval-when-compile
      (condition-case nil
	  (require 'custom)
	(error nil))
      (condition-case nil
	  (require 'man)
	(error nil))
      (defconst kurila-xemacs-p (string-match "XEmacs\\|Lucid" emacs-version))
      (defvar kurila-can-font-lock
	(or kurila-xemacs-p
	    (and (boundp 'emacs-major-version)
		 (or window-system
		     (> emacs-major-version 20)))))
      (if kurila-can-font-lock
	  (require 'font-lock))
      (defvar msb-menu-cond)
      (defvar gud-perldb-history)
      (defvar font-lock-background-mode) ; not in Emacs
      (defvar font-lock-display-type)	; ditto
      (defvar paren-backwards-message)	; Not in newer XEmacs?
      (defvar vc-rcs-header)		; likewise?
      (defvar vc-sccs-header)		; likewise?
      (or (fboundp 'defgroup)
	  (defmacro defgroup (name val doc &rest arr)
	    nil))
      (or (fboundp 'custom-declare-variable)
	  (defmacro defcustom (name val doc &rest arr)
	    (` (defvar (, name) (, val) (, doc)))))
      (or (and (fboundp 'custom-declare-variable)
	       (string< "19.31" emacs-version))	;  Checked with 19.30: defface does not work
	  (defmacro defface (&rest arr)
	    nil))
      ;; Avoid warning (tmp definitions)
      (or (fboundp 'x-color-defined-p)
	  (defmacro x-color-defined-p (col)
	    (cond ((fboundp 'color-defined-p) (` (color-defined-p (, col))))
		  ;; XEmacs >= 19.12
		  ((fboundp 'valid-color-name-p) (` (valid-color-name-p (, col))))
		  ;; XEmacs 19.11
		  ((fboundp 'x-valid-color-name-p) (` (x-valid-color-name-p (, col))))
		  (t '(error "Cannot implement color-defined-p")))))
      (defmacro kurila-is-face (arg)	; Takes quoted arg
	(cond ((fboundp 'find-face)
	       (` (find-face (, arg))))
	      (;;(and (fboundp 'face-list)
	       ;;	(face-list))
	       (fboundp 'face-list)
	       (` (member (, arg) (and (fboundp 'face-list)
				       (face-list)))))
	      (t
	       (` (boundp (, arg))))))
      (defmacro kurila-make-face (arg descr) ; Takes unquoted arg
	(cond ((fboundp 'make-face)
	       (` (make-face (quote (, arg)))))
	      (t
	       (` (defvar (, arg) (quote (, arg)) (, descr))))))
      (defmacro kurila-force-face (arg descr) ; Takes unquoted arg
	(` (progn
	     (or (kurila-is-face (quote (, arg)))
		 (kurila-make-face (, arg) (, descr)))
	     (or (boundp (quote (, arg))) ; We use unquoted variants too
		 (defvar (, arg) (quote (, arg)) (, descr))))))
      (if kurila-xemacs-p
	  (defmacro kurila-etags-snarf-tag (file line)
	    (` (progn
		 (beginning-of-line 2)
		 (list (, file) (, line)))))
	(defmacro kurila-etags-snarf-tag (file line)
	  (` (etags-snarf-tag))))
      (if kurila-xemacs-p
	  (defmacro kurila-etags-goto-tag-location (elt)
	    (`;;(progn
	     ;; (switch-to-buffer (get-file-buffer (elt (, elt) 0)))
	     ;; (set-buffer (get-file-buffer (elt (, elt) 0)))
	     ;; Probably will not work due to some save-excursion???
	     ;; Or save-file-position?
	     ;; (message "Did I get to line %s?" (elt (, elt) 1))
	     (goto-line (string-to-int (elt (, elt) 1)))))
	;;)
	(defmacro kurila-etags-goto-tag-location (elt)
	  (` (etags-goto-tag-location (, elt)))))))

(defconst kurila-xemacs-p (string-match "XEmacs\\|Lucid" emacs-version))

(defvar kurila-can-font-lock
  (or kurila-xemacs-p
      (and (boundp 'emacs-major-version)
	   (or window-system
	       (> emacs-major-version 20)))))

(condition-case nil
    (require 'custom)
  (error nil))				; Already fixed by eval-when-compile

(defun kurila-choose-color (&rest list)
  (let (answer)
    (while list
      (or answer
	  (if (or (x-color-defined-p (car list))
		  (null (cdr list)))
	      (setq answer (car list))))
      (setq list (cdr list)))
    answer))


(defgroup kurila nil
  "Major mode for editing Perl code."
  :prefix "kurila-"
  :group 'languages)

(defgroup kurila-indentation-details nil
  "Indentation."
  :prefix "kurila-"
  :group 'kurila)

(defgroup kurila-affected-by-hairy nil
  "Variables affected by `kurila-hairy'."
  :prefix "kurila-"
  :group 'kurila)

(defgroup kurila-autoinsert-details nil
  "Auto-insert tuneup."
  :prefix "kurila-"
  :group 'kurila)

(defgroup kurila-faces nil
  "Fontification colors."
  :prefix "kurila-"
  :group 'kurila)

(defgroup kurila-speed nil
  "Speed vs. validity tuneup."
  :prefix "kurila-"
  :group 'kurila)

(defgroup kurila-help-system nil
  "Help system tuneup."
  :prefix "kurila-"
  :group 'kurila)


(defcustom kurila-extra-newline-before-brace nil
  "*Non-nil means that if, elsif, while, until, else, for, foreach
and do constructs look like:

	if ()
	{
	}

instead of:

	if () {
	}"
  :type 'boolean
  :group 'kurila-autoinsert-details)

(defcustom kurila-extra-newline-before-brace-multiline
  kurila-extra-newline-before-brace
  "*Non-nil means the same as `kurila-extra-newline-before-brace', but
for constructs with multiline if/unless/while/until/for/foreach condition."
  :type 'boolean
  :group 'kurila-autoinsert-details)

(defcustom kurila-indent-level 2
  "*Indentation of Kurila statements with respect to containing block."
  :type 'integer
  :group 'kurila-indentation-details)

(defcustom kurila-lineup-step nil
  "*`kurila-lineup' will always lineup at multiple of this number.
If nil, the value of `kurila-indent-level' will be used."
  :type '(choice (const nil) integer)
  :group 'kurila-indentation-details)

(defcustom kurila-brace-imaginary-offset 0
  "*Imagined indentation of a Perl open brace that actually follows a statement.
An open brace following other text is treated as if it were this far
to the right of the start of its line."
  :type 'integer
  :group 'kurila-indentation-details)

(defcustom kurila-brace-offset 0
  "*Extra indentation for braces, compared with other text in same context."
  :type 'integer
  :group 'kurila-indentation-details)
(defcustom kurila-label-offset -2
  "*Offset of Kurila label lines relative to usual indentation."
  :type 'integer
  :group 'kurila-indentation-details)
(defcustom kurila-min-label-indent 1
  "*Minimal offset of Kurila label lines."
  :type 'integer
  :group 'kurila-indentation-details)
(defcustom kurila-continued-statement-offset 2
  "*Extra indent for lines not starting new statements."
  :type 'integer
  :group 'kurila-indentation-details)
(defcustom kurila-continued-brace-offset 0
  "*Extra indent for substatements that start with open-braces.
This is in addition to kurila-continued-statement-offset."
  :type 'integer
  :group 'kurila-indentation-details)
(defcustom kurila-close-paren-offset -1
  "*Extra indent for substatements that start with close-parenthesis."
  :type 'integer
  :group 'kurila-indentation-details)

(defcustom kurila-indent-wrt-brace t
  "*Non-nil means indent statements in if/etc block relative brace, not if/etc.
Versions 5.2 ... 5.20 behaved as if this were `nil'."
  :type 'boolean
  :group 'kurila-indentation-details)

(defcustom kurila-auto-newline nil
  "*Non-nil means automatically newline before and after braces,
and after colons and semicolons, inserted in Kurila code.  The following
\\[kurila-electric-backspace] will remove the inserted whitespace.
Insertion after colons requires both this variable and
`kurila-auto-newline-after-colon' set."
  :type 'boolean
  :group 'kurila-autoinsert-details)

(defcustom kurila-autoindent-on-semi nil
  "*Non-nil means automatically indent after insertion of (semi)colon.
Active if `kurila-auto-newline' is false."
  :type 'boolean
  :group 'kurila-autoinsert-details)

(defcustom kurila-auto-newline-after-colon nil
  "*Non-nil means automatically newline even after colons.
Subject to `kurila-auto-newline' setting."
  :type 'boolean
  :group 'kurila-autoinsert-details)

(defcustom kurila-tab-always-indent t
  "*Non-nil means TAB in Kurila mode should always reindent the current line,
regardless of where in the line point is when the TAB command is used."
  :type 'boolean
  :group 'kurila-indentation-details)

(defcustom kurila-font-lock nil
  "*Non-nil (and non-null) means Kurila buffers will use `font-lock-mode'.
Can be overwritten by `kurila-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'kurila-affected-by-hairy)

(defcustom kurila-electric-lbrace-space nil
  "*Non-nil (and non-null) means { after $ should be preceded by ` '.
Can be overwritten by `kurila-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'kurila-affected-by-hairy)

(defcustom kurila-electric-parens-string "({[]})"
  "*String of parentheses that should be electric in Kurila.
Closing ones are electric only if the region is highlighted."
  :type 'string
  :group 'kurila-affected-by-hairy)

(defcustom kurila-electric-parens nil
  "*Non-nil (and non-null) means parentheses should be electric in Kurila.
Can be overwritten by `kurila-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'kurila-affected-by-hairy)

(defvar zmacs-regions)			; Avoid warning

(defcustom kurila-electric-parens-mark
  (and window-system
       (or (and (boundp 'transient-mark-mode) ; For Emacs
		transient-mark-mode)
	   (and (boundp 'zmacs-regions) ; For XEmacs
		zmacs-regions)))
  "*Not-nil means that electric parens look for active mark.
Default is yes if there is visual feedback on mark."
  :type 'boolean
  :group 'kurila-autoinsert-details)

(defcustom kurila-electric-linefeed nil
  "*If true, LFD should be hairy in Kurila, otherwise C-c LFD is hairy.
In any case these two mean plain and hairy linefeeds together.
Can be overwritten by `kurila-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'kurila-affected-by-hairy)

(defcustom kurila-electric-keywords nil
  "*Not-nil (and non-null) means keywords are electric in Kurila.
Can be overwritten by `kurila-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'kurila-affected-by-hairy)

(defcustom kurila-electric-backspace-untabify t
  "*Not-nil means electric-backspace will untabify in Kurila."
  :type 'boolean
  :group 'kurila-autoinsert-details)

(defcustom kurila-hairy nil
  "*Not-nil means most of the bells and whistles are enabled in Kurila.
Affects: `kurila-font-lock', `kurila-electric-lbrace-space',
`kurila-electric-parens', `kurila-electric-linefeed', `kurila-electric-keywords',
`kurila-info-on-command-no-prompt', `kurila-clobber-lisp-bindings',
`kurila-lazy-help-time'."
  :type 'boolean
  :group 'kurila-affected-by-hairy)

(defcustom kurila-comment-column 32
  "*Column to put comments in Kurila (use \\[kurila-indent] to lineup with code)."
  :type 'integer
  :group 'kurila-indentation-details)

(defcustom kurila-indent-comment-at-column-0 nil
  "*Non-nil means that comment started at column 0 should be indentable."
  :type 'boolean
  :group 'kurila-indentation-details)

(defcustom kurila-vc-sccs-header '("($sccs) = ('%W\%' =~ /(\\d+(\\.\\d+)+)/) ;")
  "*Special version of `vc-sccs-header' that is used in Kurila mode buffers."
  :type '(repeat string)
  :group 'kurila)

(defcustom kurila-vc-rcs-header '("($rcs) = (' $Id\$ ' =~ /(\\d+(\\.\\d+)+)/);")
  "*Special version of `vc-rcs-header' that is used in Kurila mode buffers."
  :type '(repeat string)
     :group 'kurila)

;; This became obsolete...
(defcustom kurila-vc-header-alist '()
  "*What to use as `vc-header-alist' in Kurila.
Obsolete, with newer Emacsen use `kurila-vc-rcs-header' or
`kurila-vc-sccs-header' instead.  If this list is empty, `vc-header-alist'
will be reconstructed basing on these two variables."
  :type '(repeat (list symbol string))
  :group 'kurila)

(defcustom kurila-clobber-mode-lists
  (not
   (and
    (boundp 'interpreter-mode-alist)
    (assoc "miniperl" interpreter-mode-alist)
    (assoc "\\.\\([pP][Llm]\\|al\\)$" auto-mode-alist)))
  "*Whether to install us into `interpreter-' and `extension' mode lists."
  :type 'boolean
  :group 'kurila)

(defcustom kurila-info-on-command-no-prompt nil
  "*Not-nil (and non-null) means not to prompt on C-h f.
The opposite behaviour is always available if prefixed with C-c.
Can be overwritten by `kurila-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'kurila-affected-by-hairy)

(defcustom kurila-clobber-lisp-bindings nil
  "*Not-nil (and non-null) means not overwrite C-h f.
The function is available on \\[kurila-info-on-command], \\[kurila-get-help].
Can be overwritten by `kurila-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'kurila-affected-by-hairy)

(defcustom kurila-lazy-help-time nil
  "*Not-nil (and non-null) means to show lazy help after given idle time.
Can be overwritten by `kurila-hairy' to be 5 sec if nil."
  :type '(choice (const null) (const nil) integer)
  :group 'kurila-affected-by-hairy)

(defcustom kurila-pod-face 'font-lock-comment-face
  "*The result of evaluation of this expression is used for POD highlighting."
  :type 'face
  :group 'kurila-faces)

(defcustom kurila-pod-head-face 'font-lock-variable-name-face
  "*The result of evaluation of this expression is used for POD highlighting.
Font for POD headers."
  :type 'face
  :group 'kurila-faces)

(defcustom kurila-here-face 'font-lock-string-face
  "*The result of evaluation of this expression is used for here-docs highlighting."
  :type 'face
  :group 'kurila-faces)

;;; Some double-evaluation happened with font-locks...  Needed with 21.2...
(defvar kurila-singly-quote-face kurila-xemacs-p)

(defcustom kurila-invalid-face nil		; Does not customize with '' on XEmacs
  (if kurila-singly-quote-face
      "*This face is used for highlighting trailing whitespace."
    "*The result of evaluation of this expression highlights trailing whitespace.")
  :type 'face
  :group 'kurila-faces)

(defcustom kurila-pod-here-fontify '(featurep 'font-lock)
  "*Not-nil after evaluation means to highlight POD and here-docs sections."
  :type 'boolean
  :group 'kurila-faces)

(defcustom kurila-fontify-m-as-s t
  "*Not-nil means highlight 1arg regular expressions operators same as 2arg."
  :type 'boolean
  :group 'kurila-faces)

(defcustom kurila-highlight-variables-indiscriminately nil
  "*Non-nil means perform additional highlighting on variables.
Currently only changes how scalar variables are highlighted.
Note that that variable is only read at initialization time for
the variable `perl-font-lock-keywords-2', so changing it after you've
entered Kurila mode the first time will have no effect."
  :type 'boolean
  :group 'kurila)

(defcustom kurila-pod-here-scan t
  "*Not-nil means look for POD and here-docs sections during startup.
You can always make lookup from menu or using \\[kurila-find-pods-heres]."
  :type 'boolean
  :group 'kurila-speed)

(defcustom kurila-regexp-scan t
  "*Not-nil means make marking of regular expression more thorough.
Effective only with `kurila-pod-here-scan'."
  :type 'boolean
  :group 'kurila-speed)

(defcustom kurila-hook-after-change t
  "*Not-nil means install hook to know which regions of buffer are changed.
May significantly speed up delayed fontification.  Changes take effect
after reload."
  :type 'boolean
  :group 'kurila-speed)

(defcustom kurila-imenu-addback nil
  "*Not-nil means add backreferences to generated `imenu's.
May require patched `imenu' and `imenu-go'.  Obsolete."
  :type 'boolean
  :group 'kurila-help-system)

(defcustom kurila-max-help-size 66
  "*Non-nil means shrink-wrapping of info-buffer allowed up to these percents."
  :type '(choice integer (const nil))
  :group 'kurila-help-system)

(defcustom kurila-shrink-wrap-info-frame t
  "*Non-nil means shrink-wrapping of info-buffer-frame allowed."
  :type 'boolean
  :group 'kurila-help-system)

(defcustom kurila-info-page "perl"
  "*Name of the info page containing perl docs.
Older version of this page was called `perl5', newer `perl'."
  :type 'string
  :group 'kurila-help-system)

(defcustom kurila-use-syntax-table-text-property
  (boundp 'parse-sexp-lookup-properties)
  "*Non-nil means Kurila sets up and uses `syntax-table' text property."
  :type 'boolean
  :group 'kurila-speed)

(defcustom kurila-use-syntax-table-text-property-for-tags
  kurila-use-syntax-table-text-property
  "*Non-nil means: set up and use `syntax-table' text property generating TAGS."
  :type 'boolean
  :group 'kurila-speed)

(defcustom kurila-scan-files-regexp "\\.\\([pP][Llm]\\|xs\\)$"
  "*Regexp to match files to scan when generating TAGS."
  :type 'regexp
  :group 'kurila)

(defcustom kurila-noscan-files-regexp
  "/\\(\\.\\.?\\|SCCS\\|RCS\\|CVS\\|blib\\)$"
  "*Regexp to match files/dirs to skip when generating TAGS."
  :type 'regexp
  :group 'kurila)

(defcustom kurila-regexp-indent-step nil
  "*Indentation used when beautifying regexps.
If nil, the value of `kurila-indent-level' will be used."
  :type '(choice integer (const nil))
  :group 'kurila-indentation-details)

(defcustom kurila-indent-left-aligned-comments t
  "*Non-nil means that the comment starting in leftmost column should indent."
  :type 'boolean
  :group 'kurila-indentation-details)

(defcustom kurila-under-as-char t
  "*Non-nil means that the _ (underline) should be treated as word char."
  :type 'boolean
  :group 'kurila)

(defcustom kurila-extra-perl-args ""
  "*Extra arguments to use when starting Perl.
Currently used with `kurila-check-syntax' only."
  :type 'string
  :group 'kurila)

(defcustom kurila-message-electric-keyword t
  "*Non-nil means that the `kurila-electric-keyword' prints a help message."
  :type 'boolean
  :group 'kurila-help-system)

(defcustom kurila-indent-region-fix-constructs 1
  "*Amount of space to insert between `}' and `else' or `elsif'
in `kurila-indent-region'.  Set to nil to leave as is.  Values other
than 1 and nil will probably not work."
  :type '(choice (const nil) (const 1))
  :group 'kurila-indentation-details)

(defcustom kurila-break-one-line-blocks-when-indent t
  "*Non-nil means that one-line if/unless/while/until/for/foreach BLOCKs
need to be reformatted into multiline ones when indenting a region."
  :type 'boolean
  :group 'kurila-indentation-details)

(defcustom kurila-fix-hanging-brace-when-indent t
  "*Non-nil means that BLOCK-end `}' may be put on a separate line
when indenting a region.
Braces followed by else/elsif/while/until are excepted."
  :type 'boolean
  :group 'kurila-indentation-details)

(defcustom kurila-merge-trailing-else t
  "*Non-nil means that BLOCK-end `}' followed by else/elsif/continue
may be merged to be on the same line when indenting a region."
  :type 'boolean
  :group 'kurila-indentation-details)

(defcustom kurila-indent-parens-as-block nil
  "*Non-nil means that non-block ()-, {}- and []-groups are indented as blocks,
but for trailing \",\" inside the group, which won't increase indentation.
One should tune up `kurila-close-paren-offset' as well."
  :type 'boolean
  :group 'kurila-indentation-details)

(defcustom kurila-syntaxify-by-font-lock
  (and kurila-can-font-lock
       (boundp 'parse-sexp-lookup-properties))
  "*Non-nil means that Kurila uses `font-lock's routines for syntaxification."
  :type '(choice (const message) boolean)
  :group 'kurila-speed)

(defcustom kurila-syntaxify-unwind
  t
  "*Non-nil means that Kurila unwinds to a start of a long construction
when syntaxifying a chunk of buffer."
  :type 'boolean
  :group 'kurila-speed)

(defcustom kurila-syntaxify-for-menu
  t
  "*Non-nil means that Kurila syntaxifies up to the point before showing menu.
This way enabling/disabling of menu items is more correct."
  :type 'boolean
  :group 'kurila-speed)

(defcustom kurila-ps-print-face-properties
  '((font-lock-keyword-face		nil nil		bold shadow)
    (font-lock-variable-name-face	nil nil		bold)
    (font-lock-function-name-face	nil nil		bold italic box)
    (font-lock-constant-face		nil "LightGray"	bold)
    (kurila-array-face			nil "LightGray"	bold underline)
    (kurila-hash-face			nil "LightGray"	bold italic underline)
    (font-lock-comment-face		nil "LightGray"	italic)
    (font-lock-string-face		nil nil		italic underline)
    (kurila-nonoverridable-face		nil nil		italic underline)
    (font-lock-type-face		nil nil		underline)
    (font-lock-warning-face		nil "LightGray"	bold italic box)
    (underline				nil "LightGray"	strikeout))
  "List given as an argument to `ps-extend-face-list' in `kurila-ps-print'."
  :type '(repeat (cons symbol
		       (cons (choice (const nil) string)
			     (cons (choice (const nil) string)
				   (repeat symbol)))))
  :group 'kurila-faces)

(if kurila-can-font-lock
    (progn
      (defvar kurila-dark-background
	(kurila-choose-color "navy" "os2blue" "darkgreen"))
      (defvar kurila-dark-foreground
	(kurila-choose-color "orchid1" "orange"))

      (defface kurila-nonoverridable-face
	(` ((((class grayscale) (background light))
	     (:background "Gray90" :italic t :underline t))
	    (((class grayscale) (background dark))
	     (:foreground "Gray80" :italic t :underline t :bold t))
	    (((class color) (background light))
	     (:foreground "chartreuse3"))
	    (((class color) (background dark))
	     (:foreground (, kurila-dark-foreground)))
	    (t (:bold t :underline t))))
	"Font Lock mode face used to highlight array names."
	:group 'kurila-faces)

      (defface kurila-array-face
	(` ((((class grayscale) (background light))
	     (:background "Gray90" :bold t))
	    (((class grayscale) (background dark))
	     (:foreground "Gray80" :bold t))
	    (((class color) (background light))
	     (:foreground "Blue" :background "lightyellow2" :bold t))
	    (((class color) (background dark))
	     (:foreground "yellow" :background (, kurila-dark-background) :bold t))
	    (t (:bold t))))
	"Font Lock mode face used to highlight array names."
	:group 'kurila-faces)

      (defface kurila-hash-face
	(` ((((class grayscale) (background light))
	     (:background "Gray90" :bold t :italic t))
	    (((class grayscale) (background dark))
	     (:foreground "Gray80" :bold t :italic t))
	    (((class color) (background light))
	     (:foreground "Red" :background "lightyellow2" :bold t :italic t))
	    (((class color) (background dark))
	     (:foreground "Red" :background (, kurila-dark-background) :bold t :italic t))
	    (t (:bold t :italic t))))
	"Font Lock mode face used to highlight hash names."
	:group 'kurila-faces)))



;;; Short extra-docs.

(defvar kurila-tips 'please-ignore-this-line
  "Get maybe newer version of this package from
  http://ilyaz.org/software/emacs
Subdirectory `kurila-mode' may contain yet newer development releases and/or
patches to related files.

For best results apply to an older Emacs the patches from
  ftp://ftp.math.ohio-state.edu/pub/users/ilya/kurila-mode/patches
\(this upgrades syntax-parsing abilities of RMS Emaxen v19.34 and
v20.2 up to the level of RMS Emacs v20.3 - a must for a good Perl
mode.)  As of beginning of 2003, XEmacs may provide a similar ability.

Get support packages choose-color.el (or font-lock-extra.el before
19.30), imenu-go.el from the same place.  \(Look for other files there
too... ;-).  Get a patch for imenu.el in 19.29.  Note that for 19.30 and
later you should use choose-color.el *instead* of font-lock-extra.el
\(and you will not get smart highlighting in C :-().

Note that to enable Compile choices in the menu you need to install
mode-compile.el.

If your Emacs does not default to `kurila-mode' on Perl files, and you
want it to: put the following into your .emacs file:

  (autoload 'perl-mode \"kurila-mode\" \"alternate mode for editing Perl programs\" t)

or

  (defalias 'perl-mode 'kurila-mode)

Get perl5-info from
  $CPAN/doc/manual/info/perl5-old/perl5-info.tar.gz
Also, one can generate a newer documentation running `pod2texi' converter
  $CPAN/doc/manual/info/perl5/pod2texi-0.1.tar.gz

If you use imenu-go, run imenu on perl5-info buffer (you can do it
from Perl menu).  If many files are related, generate TAGS files from
Tools/Tags submenu in Perl menu.

If some class structure is too complicated, use Tools/Hierarchy-view
from Perl menu, or hierarchic view of imenu.  The second one uses the
current buffer only, the first one requires generation of TAGS from
Perl/Tools/Tags menu beforehand.

Run Perl/Tools/Insert-spaces-if-needed to fix your lazy typing.

Switch auto-help on/off with Perl/Tools/Auto-help.

Though with contemporary Emaxen Kurila mode should maintain the correct
parsing of Perl even when editing, sometimes it may be lost.  Fix this by

  M-x norm RET

or

  \\[normal-mode]

In cases of more severe confusion sometimes it is helpful to do

  M-x load-l RET kurila-mode RET
  M-x norm RET

or

  \\[load-library] kurila-mode RET
  \\[normal-mode]

Before reporting (non-)problems look in the problem section of online
micro-docs on what I know about Kurila problems.")

(defvar kurila-problems 'please-ignore-this-line
  "Description of problems in Kurila mode.
Some faces will not be shown on some versions of Emacs unless you
install choose-color.el, available from
  http://ilyaz.org/software/emacs

`fill-paragraph' on a comment may leave the point behind the
paragraph.  It also triggers a bug in some versions of Emacs (Kurila tries
to detect it and bulk out).

See documentation of a variable `kurila-problems-old-emaxen' for the
problems which disappear if you upgrade Emacs to a reasonably new
version (20.3 for RMS Emacs, and those of 2004 for XEmacs).")

(defvar kurila-problems-old-emaxen 'please-ignore-this-line
  "Description of problems in Kurila mode specific for older Emacs versions.

Emacs had a _very_ restricted syntax parsing engine until RMS's Emacs
20.1.  Most problems below are corrected starting from this version of
Emacs, and all of them should be fixed in RMS's version 20.3.  (Or apply
patches to Emacs 19.33/34 - see tips.)  XEmacs was very backward in
this respect (until 2003).

Note that even with newer Emacsen in some very rare cases the details
of interaction of `font-lock' and syntaxification may be not cleaned
up yet.  You may get slightly different colors basing on the order of
fontification and syntaxification.  Say, the initial faces is correct,
but editing the buffer breaks this.

Even with older Emacsen Kurila mode tries to corrects some Emacs
misunderstandings, however, for efficiency reasons the degree of
correction is different for different operations.  The partially
corrected problems are: POD sections, here-documents, regexps.  The
operations are: highlighting, indentation, electric keywords, electric
braces.

This may be confusing, since the regexp s#//#/#\; may be highlighted
as a comment, but it will be recognized as a regexp by the indentation
code.  Or the opposite case, when a POD section is highlighted, but
may break the indentation of the following code (though indentation
should work if the balance of delimiters is not broken by POD).

The main trick (to make $ a \"backslash\") makes constructions like
${aaa} look like unbalanced braces.  The only trick I can think of is
to insert it as $ {aaa} (legal in perl5, not in perl4).

Similar problems arise in regexps, when /(\\s|$)/ should be rewritten
as /($|\\s)/.  Note that such a transposition is not always possible.

The solution is to upgrade your Emacs or patch an older one.  Note
that RMS's 20.2 has some bugs related to `syntax-table' text
properties.  Patches are available on the main Kurila download site,
and on CPAN.

If these bugs cannot be fixed on your machine (say, you have an inferior
environment and cannot recompile), you may still disable all the fancy stuff
via `kurila-use-syntax-table-text-property'.")

(defvar kurila-non-problems 'please-ignore-this-line
"As you know from `problems' section, Perl syntax is too hard for Kurila on
older Emacsen.  Here is what you can do if you cannot upgrade, or if
you want to switch off these capabilities on RMS Emacs 20.2 (+patches) or 20.3
or better.  Please skip this docs if you run a capable Emacs already.

Most of the time, if you write your own code, you may find an equivalent
\(and almost as readable) expression (what is discussed below is usually
not relevant on newer Emacsen, since they can do it automatically).

Try to help Kurila: add comments with embedded quotes to fix Kurila
misunderstandings about the end of quotation:

$a='500$';      # ';

You won't need it too often.  The reason: $ \"quotes\" the following
character (this saves a life a lot of times in Kurila), thus due to
Emacs parsing rules it does not consider tick (i.e., ' ) after a
dollar as a closing one, but as a usual character.  This is usually
correct, but not in the above context.

Even with older Emacsen the indentation code is pretty wise.  The only
drawback is that it relied on Emacs parsing to find matching
parentheses.  And Emacs *could not* match parentheses in Perl 100%
correctly.  So
	1 if s#//#/#;
would not break indentation, but
	1 if ( s#//#/# );
would.  Upgrade.

By similar reasons
	s\"abc\"def\";
could confuse Kurila a lot.

If you still get wrong indentation in situation that you think the
code should be able to parse, try:

a) Check what Emacs thinks about balance of your parentheses.
b) Supply the code to me (IZ).

Pods were treated _very_ rudimentally.  Here-documents were not
treated at all (except highlighting and inhibiting indentation).  Upgrade.

To speed up coloring the following compromises exist:
   a) sub in $mypackage::sub may be highlighted.
   b) -z in [a-z] may be highlighted.
   c) if your regexp contains a keyword (like \"s\"), it may be highlighted.


Imenu in 19.31 is broken.  Set `imenu-use-keymap-menu' to t, and remove
`car' before `imenu-choose-buffer-index' in `imenu'.
`imenu-add-to-menubar' in 20.2 is broken.
A lot of things on XEmacs may be broken too, judging by bug reports I
receive.  Note that some releases of XEmacs are better than the others
as far as bugs reports I see are concerned.")

(defvar kurila-praise 'please-ignore-this-line
  "Advantages of Kurila mode.

0) It uses the newest `syntax-table' property ;-);

1) It does 99% of Perl syntax correct (as opposed to 80-90% in Perl
mode - but the latter number may have improved too in last years) even
with old Emaxen which do not support `syntax-table' property.

When using `syntax-table' property for syntax assist hints, it should
handle 99.995% of lines correct - or somesuch.  It automatically
updates syntax assist hints when you edit your script.

2) It is generally believed to be \"the most user-friendly Emacs
package\" whatever it may mean (I doubt that the people who say similar
things tried _all_ the rest of Emacs ;-), but this was not a lonely
voice);

3) Everything is customizable, one-by-one or in a big sweep;

4) It has many easily-accessable \"tools\":
        a) Can run program, check syntax, start debugger;
        b) Can lineup vertically \"middles\" of rows, like `=' in
                a  = b;
                cc = d;
        c) Can insert spaces where this impoves readability (in one
                interactive sweep over the buffer);
        d) Has support for imenu, including:
                1) Separate unordered list of \"interesting places\";
                2) Separate TOC of POD sections;
                3) Separate list of packages;
                4) Hierarchical view of methods in (sub)packages;
                5) and functions (by the full name - with package);
        e) Has an interface to INFO docs for Perl; The interface is
                very flexible, including shrink-wrapping of
                documentation buffer/frame;
        f) Has a builtin list of one-line explanations for perl constructs.
        g) Can show these explanations if you stay long enough at the
                corresponding place (or on demand);
        h) Has an enhanced fontification (using 3 or 4 additional faces
                comparing to font-lock - basically, different
                namespaces in Perl have different colors);
        i) Can construct TAGS basing on its knowledge of Perl syntax,
                the standard menu has 6 different way to generate
                TAGS (if \"by directory\", .xs files - with C-language
                bindings - are included in the scan);
        j) Can build a hierarchical view of classes (via imenu) basing
                on generated TAGS file;
        k) Has electric parentheses, electric newlines, uses Abbrev
                for electric logical constructs
                        while () {}
                with different styles of expansion (context sensitive
                to be not so bothering).  Electric parentheses behave
                \"as they should\" in a presence of a visible region.
        l) Changes msb.el \"on the fly\" to insert a group \"Perl files\";
        m) Can convert from
		if (A) { B }
	   to
		B if A;

        n) Highlights (by user-choice) either 3-delimiters constructs
	   (such as tr/a/b/), or regular expressions and `y/tr';
	o) Highlights trailing whitespace;
	p) Is able to manipulate Perl Regular Expressions to ease
	   conversion to a more readable form.
        q) Can ispell POD sections and HERE-DOCs.
	r) Understands comments and character classes inside regular
	   expressions; can find matching () and [] in a regular expression.
	s) Allows indentation of //x-style regular expressions;
	t) Highlights different symbols in regular expressions according
	   to their function; much less problems with backslashitis;
	u) Allows to find regular expressions which contain interpolated parts.

5) The indentation engine was very smart, but most of tricks may be
not needed anymore with the support for `syntax-table' property.  Has
progress indicator for indentation (with `imenu' loaded).

6) Indent-region improves inline-comments as well; also corrects
whitespace *inside* the conditional/loop constructs.

7) Fill-paragraph correctly handles multi-line comments;

8) Can switch to different indentation styles by one command, and restore
the settings present before the switch.

9) When doing indentation of control constructs, may correct
line-breaks/spacing between elements of the construct.

10) Uses a linear-time algorith for indentation of regions (on Emaxen with
capable syntax engines).

11) Syntax-highlight, indentation, sexp-recognition inside regular expressions.
")

(defvar kurila-speed 'please-ignore-this-line
  "This is an incomplete compendium of what is available in other parts
of Kurila documentation.  (Please inform me if I skept anything.)

There is a perception that Kurila is slower than alternatives.  This part
of documentation is designed to overcome this misconception.

*By default* Kurila tries to enable the most comfortable settings.
From most points of view, correctly working package is infinitely more
comfortable than a non-correctly working one, thus by default Kurila
prefers correctness over speed.  Below is the guide how to change
settings if your preferences are different.

A)  Speed of loading the file.  When loading file, Kurila may perform a
scan which indicates places which cannot be parsed by primitive Emacs
syntax-parsing routines, and marks them up so that either

    A1) Kurila may work around these deficiencies (for big chunks, mostly
        PODs and HERE-documents), or
    A2) On capable Emaxen Kurila will use improved syntax-handlings
	which reads mark-up hints directly.

    The scan in case A2 is much more comprehensive, thus may be slower.

    User can disable syntax-engine-helping scan of A2 by setting
       `kurila-use-syntax-table-text-property'
    variable to nil (if it is set to t).

    One can disable the scan altogether (both A1 and A2) by setting
       `kurila-pod-here-scan'
    to nil.

B) Speed of editing operations.

    One can add a (minor) speedup to editing operations by setting
       `kurila-use-syntax-table-text-property'
    variable to nil (if it is set to t).  This will disable
    syntax-engine-helping scan, thus will make many more Perl
    constructs be wrongly recognized by Kurila, thus may lead to
    wrongly matched parentheses, wrong indentation, etc.

    One can unset `kurila-syntaxify-unwind'.  This might speed up editing
    of, say, long POD sections.")

(defvar kurila-tips-faces 'please-ignore-this-line
  "Kurila mode uses following faces for highlighting:

  `kurila-array-face'		Array names
  `kurila-hash-face'		Hash names
  `font-lock-comment-face'	Comments, PODs and whatever is considered
				syntaxically to be not code
  `font-lock-constant-face'	HERE-doc delimiters, labels, delimiters of
				2-arg operators s/y/tr/ or of RExen,
  `font-lock-warning-face'	Special-cased m// and s//foo/,
  `font-lock-function-name-face' _ as a target of a file tests, file tests,
				subroutine names at the moment of definition
				(except those conflicting with Perl operators),
				package names (when recognized), format names
  `font-lock-keyword-face'	Control flow switch constructs, declarators
  `kurila-nonoverridable-face'	Non-overridable keywords, modifiers of RExen
  `font-lock-string-face'	Strings, qw() constructs, RExen, POD sections,
				literal parts and the terminator of formats
				and whatever is syntaxically considered
				as string literals
  `font-lock-type-face'		Overridable keywords
  `font-lock-variable-name-face' Variable declarations, indirect array and
				hash names, POD headers/item names
  `kurila-invalid-face'		Trailing whitespace

Note that in several situations the highlighting tries to inform about
possible confusion, such as different colors for function names in
declarations depending on what they (do not) override, or special cases
m// and s/// which do not do what one would expect them to do.

Help with best setup of these faces for printout requested (for each of
the faces: please specify bold, italic, underline, shadow and box.)

In regular expressions (except character classes):
  `font-lock-string-face'	\"Normal\" stuff and non-0-length constructs
  `font-lock-constant-face':	Delimiters
  `font-lock-warning-face'	Special-cased m// and s//foo/,
				Mismatched closing delimiters, parens
				we couldn't match, misplaced quantifiers,
				unrecognized escape sequences
  `kurila-nonoverridable-face'	Modifiers, as gism in m/REx/gism
  `font-lock-type-face'		POSIX classes inside charclasses,
				escape sequences with arguments (\x \23 \p \N)
				and others match-a-char escape sequences
  `font-lock-keyword-face'	Capturing parens, and |
  `font-lock-function-name-face' Special symbols: $ ^ . [ ] [^ ] (?{ }) (??{ })
  `font-lock-builtin-face'	\"Remaining\" 0-length constructs, executable
				parts of a REx, not-capturing parens
  `font-lock-variable-name-face' Interpolated constructs, embedded code
  `font-lock-comment-face'	Embedded comments

")



;;; Portability stuff:

(defmacro kurila-define-key (emacs-key definition &optional xemacs-key)
  (` (define-key kurila-mode-map
       (, (if xemacs-key
	      (` (if kurila-xemacs-p (, xemacs-key) (, emacs-key)))
	    emacs-key))
       (, definition))))

(defvar kurila-del-back-ch
  (car (append (where-is-internal 'delete-backward-char)
	       (where-is-internal 'backward-delete-char-untabify)))
  "Character generated by key bound to `delete-backward-char'.")

(and (vectorp kurila-del-back-ch) (= (length kurila-del-back-ch) 1)
     (setq kurila-del-back-ch (aref kurila-del-back-ch 0)))

(defun kurila-mark-active () (mark))	; Avoid undefined warning
(if kurila-xemacs-p
    (progn
      ;; "Active regions" are on: use region only if active
      ;; "Active regions" are off: use region unconditionally
      (defun kurila-use-region-p ()
	(if zmacs-regions (mark) t)))
  (defun kurila-use-region-p ()
    (if transient-mark-mode mark-active t))
  (defun kurila-mark-active () mark-active))

(defsubst kurila-enable-font-lock ()
  kurila-can-font-lock)

(defun kurila-putback-char (c)		; Emacs 19
  (set 'unread-command-events (list c))) ; Avoid undefined warning

(if (boundp 'unread-command-events)
    (if kurila-xemacs-p
	(defun kurila-putback-char (c)	; XEmacs >= 19.12
	  (setq unread-command-events (list (eval '(character-to-event c))))))
  (defun kurila-putback-char (c)		; XEmacs <= 19.11
    (set 'unread-command-event (eval '(character-to-event c))))) ; Avoid warnings

(or (fboundp 'uncomment-region)
    (defun uncomment-region (beg end)
      (interactive "r")
      (comment-region beg end -1)))

(defvar kurila-do-not-fontify
  (if (string< emacs-version "19.30")
      'fontified
    'lazy-lock)
  "Text property which inhibits refontification.")

(defsubst kurila-put-do-not-fontify (from to &optional post)
  ;; If POST, do not do it with postponed fontification
  (if (and post kurila-syntaxify-by-font-lock)
      nil
    (put-text-property (max (point-min) (1- from))
		       to kurila-do-not-fontify t)))

(autoload 'turn-on-kurila-indent "kurila-indent"
  "Turn on Kurila indentation." t)

(defcustom kurila-mode-hook nil
  "Hook run by Kurila mode."
  :type 'hook
  :options '(turn-on-kurila-indent)
  :group 'kurila)

(defvar kurila-syntax-state nil)
(defvar kurila-syntax-done-to nil)
(defvar kurila-emacs-can-parse (> (length (save-excursion
					   (parse-partial-sexp (point) (point)))) 9))

;; Make customization possible "in reverse"
(defsubst kurila-val (symbol &optional default hairy)
  (cond
   ((eq (symbol-value symbol) 'null) default)
   (kurila-hairy (or hairy t))
   (t (symbol-value symbol))))


(defun kurila-make-indent (column &optional minimum keep)
  "Makes indent of the current line the requested amount.
Unless KEEP, removes the old indentation.  Works around a bug in ancient
versions of Emacs."
  (let ((prop (get-text-property (point) 'syntax-type)))
    (or keep
	(delete-horizontal-space))
    (indent-to column minimum)
    ;; In old versions (e.g., 19.33) `indent-to' would not inherit properties
    (and prop
	 (> (current-column) 0)
	 (save-excursion
	   (beginning-of-line)
	   (or (get-text-property (point) 'syntax-type)
	       (and (looking-at "\\=[ \t]")
		      (put-text-property (point) (match-end 0)
					 'syntax-type prop)))))))

;;; Probably it is too late to set these guys already, but it can help later:

(and kurila-clobber-mode-lists
     (setq auto-mode-alist
      (append '(("\\.\\([pP][Llm]\\|al\\)$" . perl-mode))  auto-mode-alist ))
     (and (boundp 'interpreter-mode-alist)
	  (setq interpreter-mode-alist (append interpreter-mode-alist
					       '(("miniperl" . perl-mode))))))
(if (fboundp 'eval-when-compile)
    (eval-when-compile
      (mapcar (lambda (p)
		(condition-case nil
		    (require p)
		  (error nil)))
	      '(imenu easymenu etags timer man info))
      (if (fboundp 'ps-extend-face-list)
	  (defmacro kurila-ps-extend-face-list (arg)
	    (` (ps-extend-face-list (, arg))))
	(defmacro kurila-ps-extend-face-list (arg)
	  (` (error "This version of Emacs has no `ps-extend-face-list'"))))
      ;; Calling `kurila-enable-font-lock' below doesn't compile on XEmacs,
      ;; macros instead of defsubsts don't work on Emacs, so we do the
      ;; expansion manually.  Any other suggestions?
      (if kurila-can-font-lock
	  (require 'font-lock))
      (require 'cl)))

(defvar kurila-mode-abbrev-table nil
  "Abbrev table in use in Kurila mode buffers.")

(add-hook 'edit-var-mode-alist '(perl-mode (regexp . "^kurila-")))

(defvar kurila-mode-map () "Keymap used in Kurila mode.")

(if kurila-mode-map nil
  (setq kurila-mode-map (make-sparse-keymap))
  (kurila-define-key "{" 'kurila-electric-lbrace)
  (kurila-define-key "[" 'kurila-electric-paren)
  (kurila-define-key "(" 'kurila-electric-paren)
  (kurila-define-key "}" 'kurila-electric-brace)
  (kurila-define-key "]" 'kurila-electric-rparen)
  (kurila-define-key ")" 'kurila-electric-rparen)
  (kurila-define-key ";" 'kurila-electric-semi)
  (kurila-define-key ":" 'kurila-electric-terminator)
  (kurila-define-key "\C-j" 'newline-and-indent)
  (kurila-define-key "\C-c\C-j" 'kurila-linefeed)
  (kurila-define-key "\C-c\C-a" 'kurila-toggle-auto-newline)
  (kurila-define-key "\C-c\C-k" 'kurila-toggle-abbrev)
  (kurila-define-key "\C-c\C-w" 'kurila-toggle-construct-fix)
  (kurila-define-key "\C-c\C-f" 'auto-fill-mode)
  (kurila-define-key "\C-c\C-e" 'kurila-toggle-electric)
  (kurila-define-key "\C-c\C-b" 'kurila-find-bad-style)
  (kurila-define-key "\C-c\C-p" 'kurila-pod-spell)
  (kurila-define-key "\C-c\C-d" 'kurila-here-doc-spell)
  (kurila-define-key "\C-c\C-n" 'kurila-narrow-to-here-doc)
  (kurila-define-key "\C-c\C-v" 'kurila-next-interpolated-REx)
  (kurila-define-key "\C-c\C-x" 'kurila-next-interpolated-REx-0)
  (kurila-define-key "\C-c\C-y" 'kurila-next-interpolated-REx-1)
  (kurila-define-key "\C-c\C-ha" 'kurila-toggle-autohelp)
  (kurila-define-key "\C-c\C-hp" 'kurila-perldoc)
  (kurila-define-key "\C-c\C-hP" 'kurila-perldoc-at-point)
  (kurila-define-key "\e\C-q" 'kurila-indent-exp) ; Usually not bound
  (kurila-define-key [?\C-\M-\|] 'kurila-lineup
		    [(control meta |)])
  ;;(kurila-define-key "\M-q" 'kurila-fill-paragraph)
  ;;(kurila-define-key "\e;" 'kurila-indent-for-comment)
  (kurila-define-key "\177" 'kurila-electric-backspace)
  ;; don't clobber the backspace binding:
  (kurila-define-key "\C-c\C-hF" 'kurila-info-on-command
		    [(control c) (control h) F])
  (if (kurila-val 'kurila-clobber-lisp-bindings)
      (progn
	(kurila-define-key "\C-hf"
			  ;;(concat (char-to-string help-char) "f") ; does not work
			  'kurila-info-on-command
			  [(control h) f])
	(kurila-define-key "\C-hv"
			  ;;(concat (char-to-string help-char) "v") ; does not work
			  'kurila-get-help
			  [(control h) v])
	(kurila-define-key "\C-c\C-hf"
			  ;;(concat (char-to-string help-char) "f") ; does not work
			  (key-binding "\C-hf")
			  [(control c) (control h) f])
	(kurila-define-key "\C-c\C-hv"
			  ;;(concat (char-to-string help-char) "v") ; does not work
			  (key-binding "\C-hv")
			  [(control c) (control h) v]))
    (kurila-define-key "\C-c\C-hf" 'kurila-info-on-current-command
		      [(control c) (control h) f])
    (kurila-define-key "\C-c\C-hv"
		      ;;(concat (char-to-string help-char) "v") ; does not work
		      'kurila-get-help
		      [(control c) (control h) v]))
  (if (and kurila-xemacs-p
	   (<= emacs-minor-version 11) (<= emacs-major-version 19))
      (progn
	;; substitute-key-definition is usefulness-deenhanced...
	;;;;;(kurila-define-key "\M-q" 'kurila-fill-paragraph)
	(kurila-define-key "\e;" 'kurila-indent-for-comment)
	(kurila-define-key "\e\C-\\" 'kurila-indent-region))
    (or (boundp 'fill-paragraph-function)
	(substitute-key-definition
	 'fill-paragraph 'kurila-fill-paragraph
	 kurila-mode-map global-map))
    (substitute-key-definition
     'indent-sexp 'kurila-indent-exp
     kurila-mode-map global-map)
    (substitute-key-definition
     'indent-region 'kurila-indent-region
     kurila-mode-map global-map)
    (substitute-key-definition
     'indent-for-comment 'kurila-indent-for-comment
     kurila-mode-map global-map)))

(defvar kurila-menu)
(defvar kurila-lazy-installed)
(defvar kurila-old-style nil)
(condition-case nil
    (progn
      (require 'easymenu)
      (easy-menu-define
       kurila-menu kurila-mode-map "Menu for Kurila mode"
       '("Perl"
	 ["Beginning of function" beginning-of-defun t]
	 ["End of function" end-of-defun t]
	 ["Mark function" mark-defun t]
	 ["Indent expression" kurila-indent-exp t]
	 ["Fill paragraph/comment" kurila-fill-paragraph t]
	 "----"
	 ["Line up a construction" kurila-lineup (kurila-use-region-p)]
	 ("Regexp"
	  ["Beautify" kurila-beautify-regexp
	   kurila-use-syntax-table-text-property]
	  ["Beautify one level deep" (kurila-beautify-regexp 1)
	   kurila-use-syntax-table-text-property]
	  ["Beautify a group" kurila-beautify-level
	   kurila-use-syntax-table-text-property]
	  ["Beautify a group one level deep" (kurila-beautify-level 1)
	   kurila-use-syntax-table-text-property]
	  ["Contract a group" kurila-contract-level
	   kurila-use-syntax-table-text-property]
	  ["Contract groups" kurila-contract-levels
	   kurila-use-syntax-table-text-property]
	  "----"
	  ["Find next interpolated" kurila-next-interpolated-REx 
	   (next-single-property-change (point-min) 'REx-interpolated)]
	  ["Find next interpolated (no //o)"
	   kurila-next-interpolated-REx-0
	   (or (text-property-any (point-min) (point-max) 'REx-interpolated t)
	       (text-property-any (point-min) (point-max) 'REx-interpolated 1))]
	  ["Find next interpolated (neither //o nor whole-REx)"
	   kurila-next-interpolated-REx-1
	   (text-property-any (point-min) (point-max) 'REx-interpolated t)])
	 ["Insert spaces if needed to fix style" kurila-find-bad-style t]
	 ["Refresh \"hard\" constructions" kurila-find-pods-heres t]
	 "----"
	 ["Indent region" kurila-indent-region (kurila-use-region-p)]
	 ["Comment region" kurila-comment-region (kurila-use-region-p)]
	 ["Uncomment region" kurila-uncomment-region (kurila-use-region-p)]
	 "----"
	 ["Run" mode-compile (fboundp 'mode-compile)]
	 ["Kill" mode-compile-kill (and (fboundp 'mode-compile-kill)
					(get-buffer "*compilation*"))]
	 ["Next error" next-error (get-buffer "*compilation*")]
	 ["Check syntax" kurila-check-syntax (fboundp 'mode-compile)]
	 "----"
	 ["Debugger" kurila-db t]
	 "----"
	 ("Tools"
	  ["Imenu" imenu (fboundp 'imenu)]
	  ["Imenu on Perl Info" kurila-imenu-on-info (featurep 'imenu)]
	  "----"
	  ["Ispell PODs" kurila-pod-spell
	   ;; Better not to update syntaxification here:
	   ;; debugging syntaxificatio can be broken by this???
	   (or
	    (get-text-property (point-min) 'in-pod)
	    (< (progn
		 (and kurila-syntaxify-for-menu
		      (kurila-update-syntaxification (point-max) (point-max)))
		 (next-single-property-change (point-min) 'in-pod nil (point-max)))
	       (point-max)))]
	  ["Ispell HERE-DOCs" kurila-here-doc-spell
	   (< (progn
		(and kurila-syntaxify-for-menu
		     (kurila-update-syntaxification (point-max) (point-max)))
		(next-single-property-change (point-min) 'here-doc-group nil (point-max)))
	      (point-max))]
	  ["Narrow to this HERE-DOC" kurila-narrow-to-here-doc
	   (eq 'here-doc  (progn
		(and kurila-syntaxify-for-menu
		     (kurila-update-syntaxification (point) (point)))
		(get-text-property (point) 'syntax-type)))]
	  ["Select this HERE-DOC or POD section"
	   kurila-select-this-pod-or-here-doc
	   (memq (progn
		   (and kurila-syntaxify-for-menu
			(kurila-update-syntaxification (point) (point)))
		   (get-text-property (point) 'syntax-type))
		 '(here-doc pod))]
	  "----"
	  ["Kurila pretty print (exprmntl)" kurila-ps-print
	   (fboundp 'ps-extend-face-list)]
	  "----"
	  ["Syntaxify region" kurila-find-pods-heres-region
	   (kurila-use-region-p)]
	  ["Profile syntaxification" kurila-time-fontification t]
	  ["Debug errors in delayed fontification" kurila-emulate-lazy-lock t]
	  ["Debug unwind for syntactic scan" kurila-toggle-set-debug-unwind t]
	  ["Debug backtrace on syntactic scan (BEWARE!!!)"
	   (kurila-toggle-set-debug-unwind nil t) t]
	  "----"
	  ["Class Hierarchy from TAGS" kurila-tags-hier-init t]
	  ;;["Update classes" (kurila-tags-hier-init t) tags-table-list]
	  ("Tags"
;;;	     ["Create tags for current file" kurila-etags t]
;;;	     ["Add tags for current file" (kurila-etags t) t]
;;;	     ["Create tags for Perl files in directory" (kurila-etags nil t) t]
;;;	     ["Add tags for Perl files in directory" (kurila-etags t t) t]
;;;	     ["Create tags for Perl files in (sub)directories"
;;;	      (kurila-etags nil 'recursive) t]
;;;	     ["Add tags for Perl files in (sub)directories"
;;;	      (kurila-etags t 'recursive) t])
;;;; kurila-write-tags (&optional file erase recurse dir inbuffer)
	   ["Create tags for current file" (kurila-write-tags nil t) t]
	   ["Add tags for current file" (kurila-write-tags) t]
	   ["Create tags for Perl files in directory"
	    (kurila-write-tags nil t nil t) t]
	   ["Add tags for Perl files in directory"
	    (kurila-write-tags nil nil nil t) t]
	   ["Create tags for Perl files in (sub)directories"
	    (kurila-write-tags nil t t t) t]
	   ["Add tags for Perl files in (sub)directories"
	    (kurila-write-tags nil nil t t) t]))
	 ("Perl docs"
	  ["Define word at point" imenu-go-find-at-position
	   (fboundp 'imenu-go-find-at-position)]
	  ["Help on function" kurila-info-on-command t]
	  ["Help on function at point" kurila-info-on-current-command t]
	  ["Help on symbol at point" kurila-get-help t]
	  ["Perldoc" kurila-perldoc t]
	  ["Perldoc on word at point" kurila-perldoc-at-point t]
	  ["View manpage of POD in this file" kurila-build-manpage t]
	  ["Auto-help on" kurila-lazy-install
	   (and (fboundp 'run-with-idle-timer)
		(not kurila-lazy-installed))]
	  ["Auto-help off" kurila-lazy-unstall
	   (and (fboundp 'run-with-idle-timer)
		kurila-lazy-installed)])
	 ("Toggle..."
	  ["Auto newline" kurila-toggle-auto-newline t]
	  ["Electric parens" kurila-toggle-electric t]
	  ["Electric keywords" kurila-toggle-abbrev t]
	  ["Fix whitespace on indent" kurila-toggle-construct-fix t]
	  ["Auto-help on Perl constructs" kurila-toggle-autohelp t]
	  ["Auto fill" auto-fill-mode t])
	 ("Indent styles..."
	  ["Kurila" (kurila-set-style "Kurila") t]
	  ["PerlStyle" (kurila-set-style "PerlStyle") t]
	  ["GNU" (kurila-set-style "GNU") t]
	  ["C++" (kurila-set-style "C++") t]
	  ["K&R" (kurila-set-style "K&R") t]
	  ["BSD" (kurila-set-style "BSD") t]
	  ["Whitesmith" (kurila-set-style "Whitesmith") t]
	  ["Memorize Current" (kurila-set-style "Current") t]
	  ["Memorized" (kurila-set-style-back) kurila-old-style])
	 ("Micro-docs"
	  ["Tips" (describe-variable 'kurila-tips) t]
	  ["Problems" (describe-variable 'kurila-problems) t]
	  ["Non-problems" (describe-variable 'kurila-non-problems) t]
	  ["Speed" (describe-variable 'kurila-speed) t]
	  ["Praise" (describe-variable 'kurila-praise) t]
	  ["Faces" (describe-variable 'kurila-tips-faces) t]
	  ["Kurila mode" (describe-function 'kurila-mode) t]
	  ["Kurila version"
	   (message "The version of master-file for this Kurila is %s"
		    kurila-version) t]))))
  (error nil))

(autoload 'c-macro-expand "cmacexp"
  "Display the result of expanding all C macros occurring in the region.
The expansion is entirely correct because it uses the C preprocessor."
  t)

;;; These two must be unwound, otherwise take exponential time
(defconst kurila-maybe-white-and-comment-rex "[ \t\n]*\\(#[^\n]*\n[ \t\n]*\\)*"
"Regular expression to match optional whitespace with interpspersed comments.
Should contain exactly one group.")

;;; This one is tricky to unwind; still very inefficient...
(defconst kurila-white-and-comment-rex "\\([ \t\n]\\|#[^\n]*\n\\)+"
"Regular expression to match whitespace with interpspersed comments.
Should contain exactly one group.")


;;; Is incorporated in `kurila-imenu--function-name-regexp-perl'
;;; `kurila-outline-regexp', `defun-prompt-regexp'.
;;; Details of groups in this may be used in several functions; see comments
;;; near mentioned above variable(s)...
;;; sub($$):lvalue{}  sub:lvalue{} Both allowed...
(defsubst kurila-after-sub-regexp (named) ; 9 groups without attr...
  "Match the text after `sub' in a subroutine declaration.
If NAMED is nil, allows anonymous subroutines.  Matches up to the first \":\"
of attributes (if present), or end of the name or prototype (whatever is
the last)."
  (concat				; Assume n groups before this...
   "\\("				; n+1=name-group
     kurila-white-and-comment-rex	; n+2=pre-name
     "\\(::[a-zA-Z_0-9:']+\\|[a-zA-Z_'][a-zA-Z_0-9:']*\\)" ; n+3=name
   "\\)"				; END n+1=name-group
   (if named "" "?")
   "\\("				; n+4=proto-group
     kurila-maybe-white-and-comment-rex	; n+5=pre-proto
     "\\(([^()]*)\\)"			; n+6=prototype
   "\\)?"				; END n+4=proto-group
   ))

;;; Details of groups in this are used in `kurila-imenu--create-perl-index'
;;;  and `kurila-outline-level'.
;;;; Was: 2=sub|package; now 2=package-group, 5=package-name 8=sub-name (+3)
(defvar kurila-imenu--function-name-regexp-perl
  (concat
   "^\\("				; 1 = all
       "\\([ \t]*package"		; 2 = package-group
          "\\("				; 3 = package-name-group
	    kurila-white-and-comment-rex ; 4 = pre-package-name
	       "\\([a-zA-Z_0-9:']+\\)\\)?\\)" ; 5 = package-name
       "\\|"
          "[ \t]*sub"
	  (kurila-after-sub-regexp 'named) ; 8=name 11=proto 14=attr-start
	  kurila-maybe-white-and-comment-rex	; 15=pre-block
   "\\|"
     "=head\\([1-4]\\)[ \t]+"		; 16=level
     "\\([^\n]+\\)$"			; 17=text
   "\\)"))

(defvar kurila-outline-regexp
  (concat kurila-imenu--function-name-regexp-perl "\\|" "\\`"))

(defvar kurila-mode-syntax-table nil
  "Syntax table in use in Kurila mode buffers.")

(defvar kurila-string-syntax-table nil
  "Syntax table in use in Kurila mode string-like chunks.")

(defsubst kurila-1- (p)
  (max (point-min) (1- p)))

(defsubst kurila-1+ (p)
  (min (point-max) (1+ p)))

(if kurila-mode-syntax-table
    ()
  (setq kurila-mode-syntax-table (make-syntax-table))
  (modify-syntax-entry ?\\ "\\" kurila-mode-syntax-table)
  (modify-syntax-entry ?/ "." kurila-mode-syntax-table)
  (modify-syntax-entry ?* "." kurila-mode-syntax-table)
  (modify-syntax-entry ?+ "." kurila-mode-syntax-table)
  (modify-syntax-entry ?- "." kurila-mode-syntax-table)
  (modify-syntax-entry ?= "." kurila-mode-syntax-table)
  (modify-syntax-entry ?% "." kurila-mode-syntax-table)
  (modify-syntax-entry ?< "." kurila-mode-syntax-table)
  (modify-syntax-entry ?> "." kurila-mode-syntax-table)
  (modify-syntax-entry ?& "." kurila-mode-syntax-table)
  (modify-syntax-entry ?$ "." kurila-mode-syntax-table)
  (modify-syntax-entry ?\n ">" kurila-mode-syntax-table)
  (modify-syntax-entry ?# "<" kurila-mode-syntax-table)
  (modify-syntax-entry ?' "\"" kurila-mode-syntax-table)
  (modify-syntax-entry ?` "\"" kurila-mode-syntax-table)
  (if kurila-under-as-char
      (modify-syntax-entry ?_ "w" kurila-mode-syntax-table))
  (modify-syntax-entry ?: "_" kurila-mode-syntax-table)
  (modify-syntax-entry ?| "." kurila-mode-syntax-table)
  (setq kurila-string-syntax-table (copy-syntax-table kurila-mode-syntax-table))
  (modify-syntax-entry ?$ "." kurila-string-syntax-table)
  (modify-syntax-entry ?\{ "." kurila-string-syntax-table)
  (modify-syntax-entry ?\} "." kurila-string-syntax-table)
  (modify-syntax-entry ?# "." kurila-string-syntax-table)) ; (?# comment )



;; provide an alias for working with emacs 19.  the perl-mode that comes
;; with it is really bad, and this lets us seamlessly replace it.
;;;###autoload
(fset 'perl-mode 'kurila-mode)
(defvar kurila-faces-init nil)
;; Fix for msb.el
(defvar kurila-msb-fixed nil)
(defvar font-lock-syntactic-keywords)
(defvar perl-font-lock-keywords)
(defvar perl-font-lock-keywords-1)
(defvar perl-font-lock-keywords-2)
(defvar outline-level)
(if (fboundp 'defvaralias)
    (let ((f 'defvaralias)) ; Some functions deduce stuff from the mode name...
      (funcall f 'kurila-font-lock-keywords   'perl-font-lock-keywords)
      (funcall f 'kurila-font-lock-keywords-1 'perl-font-lock-keywords-1)
      (funcall f 'kurila-font-lock-keywords-2 'perl-font-lock-keywords-2)))

(defvar kurila-use-major-mode 'perl-mode)
(defvar kurila-font-lock-multiline-start nil)
(defvar kurila-font-lock-multiline nil)
(defvar kurila-compilation-error-regexp-alist nil)
(defvar kurila-font-locking nil)

;;;###autoload
(defun kurila-mode ()
  "Major mode for editing Perl code.
Expression and list commands understand all C brackets.
Tab indents for Perl code.
Paragraphs are separated by blank lines only.
Delete converts tabs to spaces as it moves back.

Various characters in Perl almost always come in pairs: {}, (), [],
sometimes <>.  When the user types the first, she gets the second as
well, with optional special formatting done on {}.  (Disabled by
default.)  You can always quote (with \\[quoted-insert]) the left
\"paren\" to avoid the expansion.  The processing of < is special,
since most the time you mean \"less\".  Kurila mode tries to guess
whether you want to type pair <>, and inserts is if it
appropriate.  You can set `kurila-electric-parens-string' to the string that
contains the parenths from the above list you want to be electrical.
Electricity of parenths is controlled by `kurila-electric-parens'.
You may also set `kurila-electric-parens-mark' to have electric parens
look for active mark and \"embrace\" a region if possible.'

Kurila mode provides expansion of the Perl control constructs:

   if, else, elsif, unless, while, until, continue, do,
   for, foreach, formy and foreachmy.

and POD directives (Disabled by default, see `kurila-electric-keywords'.)

The user types the keyword immediately followed by a space, which
causes the construct to be expanded, and the point is positioned where
she is most likely to want to be.  eg. when the user types a space
following \"if\" the following appears in the buffer: if () { or if ()
} { } and the cursor is between the parentheses.  The user can then
type some boolean expression within the parens.  Having done that,
typing \\[kurila-linefeed] places you - appropriately indented - on a
new line between the braces (if you typed \\[kurila-linefeed] in a POD
directive line, then appropriate number of new lines is inserted).

If Kurila decides that you want to insert \"English\" style construct like

            bite if angry;

it will not do any expansion.  See also help on variable
`kurila-extra-newline-before-brace'.  (Note that one can switch the
help message on expansion by setting `kurila-message-electric-keyword'
to nil.)

\\[kurila-linefeed] is a convenience replacement for typing carriage
return.  It places you in the next line with proper indentation, or if
you type it inside the inline block of control construct, like

            foreach (@lines) {print; print}

and you are on a boundary of a statement inside braces, it will
transform the construct into a multiline and will place you into an
appropriately indented blank line.  If you need a usual
`newline-and-indent' behaviour, it is on \\[newline-and-indent],
see documentation on `kurila-electric-linefeed'.

\\{kurila-mode-map}

Setting the variable `kurila-font-lock' to t switches on font-lock-mode
\(even with older Emacsen), `kurila-electric-lbrace-space' to t switches
on electric space between $ and {, `kurila-electric-parens-string' is
the string that contains parentheses that should be electric in Kurila
\(see also `kurila-electric-parens-mark' and `kurila-electric-parens'),
setting `kurila-electric-keywords' enables electric expansion of
control structures in Kurila.  `kurila-electric-linefeed' governs which
one of two linefeed behavior is preferable.  You can enable all these
options simultaneously (recommended mode of use) by setting
`kurila-hairy' to t.  In this case you can switch separate options off
by setting them to `null'.  Note that one may undo the extra
whitespace inserted by semis and braces in `auto-newline'-mode by
consequent \\[kurila-electric-backspace].

If your site has perl5 documentation in info format, you can use commands
\\[kurila-info-on-current-command] and \\[kurila-info-on-command] to access it.
These keys run commands `kurila-info-on-current-command' and
`kurila-info-on-command', which one is which is controlled by variable
`kurila-info-on-command-no-prompt' and `kurila-clobber-lisp-bindings'
\(in turn affected by `kurila-hairy').

Even if you have no info-format documentation, short one-liner-style
help is available on \\[kurila-get-help], and one can run perldoc or
man via menu.

It is possible to show this help automatically after some idle time.
This is regulated by variable `kurila-lazy-help-time'.  Default with
`kurila-hairy' (if the value of `kurila-lazy-help-time' is nil) is 5
secs idle time .  It is also possible to switch this on/off from the
menu, or via \\[kurila-toggle-autohelp].  Requires `run-with-idle-timer'.

Use \\[kurila-lineup] to vertically lineup some construction - put the
beginning of the region at the start of construction, and make region
span the needed amount of lines.

Variables `kurila-pod-here-scan', `kurila-pod-here-fontify',
`kurila-pod-face', `kurila-pod-head-face' control processing of POD and
here-docs sections.  With capable Emaxen results of scan are used
for indentation too, otherwise they are used for highlighting only.

Variables controlling indentation style:
 `kurila-tab-always-indent'
    Non-nil means TAB in Kurila mode should always reindent the current line,
    regardless of where in the line point is when the TAB command is used.
 `kurila-indent-left-aligned-comments'
    Non-nil means that the comment starting in leftmost column should indent.
 `kurila-auto-newline'
    Non-nil means automatically newline before and after braces,
    and after colons and semicolons, inserted in Perl code.  The following
    \\[kurila-electric-backspace] will remove the inserted whitespace.
    Insertion after colons requires both this variable and
    `kurila-auto-newline-after-colon' set.
 `kurila-auto-newline-after-colon'
    Non-nil means automatically newline even after colons.
    Subject to `kurila-auto-newline' setting.
 `kurila-indent-level'
    Indentation of Perl statements within surrounding block.
    The surrounding block's indentation is the indentation
    of the line on which the open-brace appears.
 `kurila-continued-statement-offset'
    Extra indentation given to a substatement, such as the
    then-clause of an if, or body of a while, or just a statement continuation.
 `kurila-continued-brace-offset'
    Extra indentation given to a brace that starts a substatement.
    This is in addition to `kurila-continued-statement-offset'.
 `kurila-brace-offset'
    Extra indentation for line if it starts with an open brace.
 `kurila-brace-imaginary-offset'
    An open brace following other text is treated as if it the line started
    this far to the right of the actual line indentation.
 `kurila-label-offset'
    Extra indentation for line that is a label.
 `kurila-min-label-indent'
    Minimal indentation for line that is a label.

Settings for classic indent-styles: K&R BSD=C++ GNU PerlStyle=Whitesmith
  `kurila-indent-level'                5   4       2   4
  `kurila-brace-offset'                0   0       0   0
  `kurila-continued-brace-offset'     -5  -4       0   0
  `kurila-label-offset'               -5  -4      -2  -4
  `kurila-continued-statement-offset'  5   4       2   4

Kurila knows several indentation styles, and may bulk set the
corresponding variables.  Use \\[kurila-set-style] to do this.  Use
\\[kurila-set-style-back] to restore the memorized preexisting values
\(both available from menu).  See examples in `kurila-style-examples'.

Part of the indentation style is how different parts of if/elsif/else
statements are broken into lines; in Kurila, this is reflected on how
templates for these constructs are created (controlled by
`kurila-extra-newline-before-brace'), and how reflow-logic should treat \"continuation\" blocks of else/elsif/continue, controlled by the same variable,
and by `kurila-extra-newline-before-brace-multiline',
`kurila-merge-trailing-else', `kurila-indent-region-fix-constructs'.

If `kurila-indent-level' is 0, the statement after opening brace in
column 0 is indented on
`kurila-brace-offset'+`kurila-continued-statement-offset'.

Turning on Kurila mode calls the hooks in the variable `kurila-mode-hook'
with no args.

DO NOT FORGET to read micro-docs (available from `Perl' menu)
or as help on variables `kurila-tips', `kurila-problems',
`kurila-non-problems', `kurila-praise', `kurila-speed'."
  (interactive)
  (kill-all-local-variables)
  (use-local-map kurila-mode-map)
  (if (kurila-val 'kurila-electric-linefeed)
      (progn
	(local-set-key "\C-J" 'kurila-linefeed)
	(local-set-key "\C-C\C-J" 'newline-and-indent)))
  (if (and
       (kurila-val 'kurila-clobber-lisp-bindings)
       (kurila-val 'kurila-info-on-command-no-prompt))
      (progn
	;; don't clobber the backspace binding:
	(kurila-define-key "\C-hf" 'kurila-info-on-current-command [(control h) f])
	(kurila-define-key "\C-c\C-hf" 'kurila-info-on-command
			  [(control c) (control h) f])))
  (setq major-mode kurila-use-major-mode)
  (setq mode-name "Kurila")
  (if (not kurila-mode-abbrev-table)
      (let ((prev-a-c abbrevs-changed))
	(define-abbrev-table 'kurila-mode-abbrev-table '(
		("if" "if" kurila-electric-keyword 0)
		("elsif" "elsif" kurila-electric-keyword 0)
		("while" "while" kurila-electric-keyword 0)
		("until" "until" kurila-electric-keyword 0)
		("unless" "unless" kurila-electric-keyword 0)
		("else" "else" kurila-electric-else 0)
		("continue" "continue" kurila-electric-else 0)
		("for" "for" kurila-electric-keyword 0)
		("foreach" "foreach" kurila-electric-keyword 0)
		("formy" "formy" kurila-electric-keyword 0)
		("foreachmy" "foreachmy" kurila-electric-keyword 0)
		("do" "do" kurila-electric-keyword 0)
		("=pod" "=pod" kurila-electric-pod 0)
		("=over" "=over" kurila-electric-pod 0)
		("=head1" "=head1" kurila-electric-pod 0)
		("=head2" "=head2" kurila-electric-pod 0)
		("pod" "pod" kurila-electric-pod 0)
		("over" "over" kurila-electric-pod 0)
		("head1" "head1" kurila-electric-pod 0)
		("head2" "head2" kurila-electric-pod 0)))
	(setq abbrevs-changed prev-a-c)))
  (setq local-abbrev-table kurila-mode-abbrev-table)
  (if (kurila-val 'kurila-electric-keywords)
      (abbrev-mode 1))
  (set-syntax-table kurila-mode-syntax-table)
  ;; Until Emacs is multi-threaded, we do not actually need it local:
  (make-local-variable 'kurila-font-lock-multiline-start)
  (make-local-variable 'kurila-font-locking)
  (make-local-variable 'outline-regexp)
  ;; (setq outline-regexp imenu-example--function-name-regexp-perl)
  (setq outline-regexp kurila-outline-regexp)
  (make-local-variable 'outline-level)
  (setq outline-level 'kurila-outline-level)
  (make-local-variable 'paragraph-start)
  (setq paragraph-start (concat "^$\\|" page-delimiter))
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'paragraph-ignore-fill-prefix)
  (setq paragraph-ignore-fill-prefix t)
  (if kurila-xemacs-p
    (progn
      (make-local-variable 'paren-backwards-message)
      (set 'paren-backwards-message t)))
  (make-local-variable 'require-final-newline)
  (setq require-final-newline t)
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (make-local-variable 'comment-end)
  (setq comment-end "")
  (make-local-variable 'comment-column)
  (setq comment-column kurila-comment-column)
  (make-local-variable 'comment-start-skip)
  (setq comment-start-skip "#+ *")
  (make-local-variable 'defun-prompt-regexp)
  (setq defun-prompt-regexp
	(concat "[ \t]*\\(sub"
		(kurila-after-sub-regexp 'named)
		"\\|"			; per toke.c
		"\\(BEGIN\\|CHECK\\|INIT\\|END\\|AUTOLOAD\\|DESTROY\\)"
		"\\)"
		kurila-maybe-white-and-comment-rex))
  (make-local-variable 'comment-indent-function)
  (setq comment-indent-function 'kurila-comment-indent)
  (and (boundp 'fill-paragraph-function)
      (progn
	(make-local-variable 'fill-paragraph-function)
	(set 'fill-paragraph-function 'kurila-fill-paragraph)))
  (make-local-variable 'parse-sexp-ignore-comments)
  (setq parse-sexp-ignore-comments t)
  (make-local-variable 'indent-region-function)
  (setq indent-region-function 'kurila-indent-region)
  ;;(setq auto-fill-function 'kurila-do-auto-fill) ; Need to switch on and off!
  (make-local-variable 'imenu-create-index-function)
  (setq imenu-create-index-function
	(function kurila-imenu--create-perl-index))
  (make-local-variable 'imenu-sort-function)
  (setq imenu-sort-function nil)
  (make-local-variable 'vc-rcs-header)
  (set 'vc-rcs-header kurila-vc-rcs-header)
  (make-local-variable 'vc-sccs-header)
  (set 'vc-sccs-header kurila-vc-sccs-header)
  ;; This one is obsolete...
  (make-local-variable 'vc-header-alist)
  (set 'vc-header-alist (or kurila-vc-header-alist ; Avoid warning
			    (` ((SCCS (, (car kurila-vc-sccs-header)))
				     (RCS (, (car kurila-vc-rcs-header)))))))
;;   (cond ((boundp 'compilation-error-regexp-alist-alist);; xemacs 20.x
;; 	 (make-local-variable 'compilation-error-regexp-alist-alist)
;; 	 (set 'compilation-error-regexp-alist-alist
;; 	      (cons (cons 'kurila kurila-compilation-error-regexp-alist)
;; 		    (symbol-value 'compilation-error-regexp-alist-alist)))
;; 	 (let ((f 'compilation-build-compilation-error-regexp-alist))
;; 	   (funcall f)))
;; 	((boundp 'compilation-error-regexp-alist);; xmeacs 19.x
;; 	 (make-local-variable 'compilation-error-regexp-alist)
;; 	 (set 'compilation-error-regexp-alist
;; 	       (cons kurila-compilation-error-regexp-alist
;; 		     (symbol-value 'compilation-error-regexp-alist)))))
  (make-local-variable 'font-lock-defaults)
  (setq	font-lock-defaults
	(cond
	 ((string< emacs-version "19.30")
	  '(perl-font-lock-keywords-2 nil nil ((?_ . "w"))))
	 ((string< emacs-version "19.33") ; Which one to use?
	  '((perl-font-lock-keywords
	     perl-font-lock-keywords-1
	     perl-font-lock-keywords-2) nil nil ((?_ . "w"))))
	 (t
	  '((kurila-load-font-lock-keywords
	     kurila-load-font-lock-keywords-1
	     kurila-load-font-lock-keywords-2) nil nil ((?_ . "w"))))))
  (make-local-variable 'kurila-syntax-state)
  (setq kurila-syntax-state nil)		; reset syntaxification cache
  (if kurila-use-syntax-table-text-property
      (progn
	(make-local-variable 'parse-sexp-lookup-properties)
	;; Do not introduce variable if not needed, we check it!
	(set 'parse-sexp-lookup-properties t)
	;; Fix broken font-lock:
	(or (boundp 'font-lock-unfontify-region-function)
	    (set 'font-lock-unfontify-region-function
		 'font-lock-default-unfontify-region))
	(unless kurila-xemacs-p		; Our: just a plug for wrong font-lock
	  (make-local-variable 'font-lock-unfontify-region-function)
	  (set 'font-lock-unfontify-region-function ; not present with old Emacs
	       'kurila-font-lock-unfontify-region-function))
	(make-local-variable 'kurila-syntax-done-to)
	(setq kurila-syntax-done-to nil)	; reset syntaxification cache
	;; Another bug: unless font-lock-syntactic-keywords, font-lock
	;;  ignores syntax-table text-property.  (t) is a hack
	;;  to make font-lock think that font-lock-syntactic-keywords
	;;  are defined
	(make-local-variable 'font-lock-syntactic-keywords)
	(setq font-lock-syntactic-keywords
	      (if kurila-syntaxify-by-font-lock
		  '(t (kurila-fontify-syntaxically))
		'(t)))))
  (if (boundp 'font-lock-multiline)	; Newer font-lock; use its facilities
      (progn
	(setq kurila-font-lock-multiline t) ; Not localized...
	(set (make-local-variable 'font-lock-multiline) t))
    (make-local-variable 'font-lock-fontify-region-function)
    (set 'font-lock-fontify-region-function ; not present with old Emacs
	 'kurila-font-lock-fontify-region-function))
  (make-local-variable 'font-lock-fontify-region-function)
  (set 'font-lock-fontify-region-function ; not present with old Emacs
       'kurila-font-lock-fontify-region-function)
  (make-local-variable 'kurila-old-style)
  (if (boundp 'normal-auto-fill-function) ; 19.33 and later
      (set (make-local-variable 'normal-auto-fill-function)
	   'kurila-do-auto-fill)	      ; RMS has it as #'kurila-do-auto-fill ???
    (or (fboundp 'kurila-old-auto-fill-mode)
	(progn
	  (fset 'kurila-old-auto-fill-mode (symbol-function 'auto-fill-mode))
	  (defun auto-fill-mode (&optional arg)
	    (interactive "P")
	    (eval '(kurila-old-auto-fill-mode arg)) ; Avoid a warning
	    (and auto-fill-function (memq major-mode '(perl-mode kurila-mode))
		 (setq auto-fill-function 'kurila-do-auto-fill))))))
  (if (kurila-enable-font-lock)
      (if (kurila-val 'kurila-font-lock)
	  (progn (or kurila-faces-init (kurila-init-faces))
		 (font-lock-mode 1))))
  (set (make-local-variable 'facemenu-add-face-function)
       'kurila-facemenu-add-face-function) ; XXXX What this guy is for???
  (and (boundp 'msb-menu-cond)
       (not kurila-msb-fixed)
       (kurila-msb-fix))
  (if (featurep 'easymenu)
      (easy-menu-add kurila-menu))	; A NOP in RMS Emacs.
  (run-hooks 'kurila-mode-hook)
  (if kurila-hook-after-change
      (progn
	(make-local-hook 'after-change-functions)
	(add-hook 'after-change-functions 'kurila-after-change-function nil t)))
  ;; After hooks since fontification will break this
  (if kurila-pod-here-scan
      (or kurila-syntaxify-by-font-lock
       (progn (or kurila-faces-init (kurila-init-faces-weak))
	      (kurila-find-pods-heres)))))

;; Fix for perldb - make default reasonable
(defun kurila-db ()
  (interactive)
  (require 'gud)
  (perldb (read-from-minibuffer "Run perldb (like this): "
				(if (consp gud-perldb-history)
				    (car gud-perldb-history)
				  (concat "perl " ;;(file-name-nondirectory
					  ;; I have problems
					  ;; in OS/2
					  ;; otherwise
					  (buffer-file-name)))
				nil nil
				'(gud-perldb-history . 1))))

(defun kurila-msb-fix ()
  ;; Adds perl files to msb menu, supposes that msb is already loaded
  (setq kurila-msb-fixed t)
  (let* ((l (length msb-menu-cond))
	 (last (nth (1- l) msb-menu-cond))
	 (precdr (nthcdr (- l 2) msb-menu-cond)) ; cdr of this is last
	 (handle (1- (nth 1 last))))
    (setcdr precdr (list
		    (list
		     '(memq major-mode '(kurila-mode perl-mode))
		     handle
		     "Perl Files (%d)")
		    last))))

;; This is used by indent-for-comment
;; to decide how much to indent a comment in Kurila code
;; based on its context.  Do fallback if comment is found wrong.

(defvar kurila-wrong-comment)
(defvar kurila-st-cfence '(14))		; Comment-fence
(defvar kurila-st-sfence '(15))		; String-fence
(defvar kurila-st-punct '(1))
(defvar kurila-st-word '(2))
(defvar kurila-st-bra '(4 . ?\>))
(defvar kurila-st-ket '(5 . ?\<))


(defun kurila-comment-indent ()		; called at point at supposed comment
  (let ((p (point)) (c (current-column)) was phony)
    (if (and (not kurila-indent-comment-at-column-0)
	     (looking-at "^#"))
	0	; Existing comment at bol stays there.
      ;; Wrong comment found
      (save-excursion
	(setq was (kurila-to-comment-or-eol)
	      phony (eq (get-text-property (point) 'syntax-table)
			kurila-st-cfence))
	(if phony
	    (progn			; Too naive???
	      (re-search-forward "#\\|$") ; Hmm, what about embedded #?
	      (if (eq (preceding-char) ?\#)
		  (forward-char -1))
	      (setq was nil)))
	(if (= (point) p)		; Our caller found a correct place
	    (progn
	      (skip-chars-backward " \t")
	      (setq was (current-column))
	      (if (eq was 0)
		  comment-column
		(max (1+ was) ; Else indent at comment column
		     comment-column)))
	  ;; No, the caller found a random place; we need to edit ourselves
	  (if was nil
	    (insert comment-start)
	    (backward-char (length comment-start)))
	  (setq kurila-wrong-comment t)
	  (kurila-make-indent comment-column 1) ; Indent min 1
	  c)))))

;;;(defun kurila-comment-indent-fallback ()
;;;  "Is called if the standard comment-search procedure fails.
;;;Point is at start of real comment."
;;;  (let ((c (current-column)) target cnt prevc)
;;;    (if (= c comment-column) nil
;;;      (setq cnt (skip-chars-backward "[ \t]"))
;;;      (setq target (max (1+ (setq prevc
;;;			     (current-column))) ; Else indent at comment column
;;;		   comment-column))
;;;      (if (= c comment-column) nil
;;;	(delete-backward-char cnt)
;;;	(while (< prevc target)
;;;	  (insert "\t")
;;;	  (setq prevc (current-column)))
;;;	(if (> prevc target) (progn (delete-char -1) (setq prevc (current-column))))
;;;	(while (< prevc target)
;;;	  (insert " ")
;;;	  (setq prevc (current-column)))))))

(defun kurila-indent-for-comment ()
  "Substitute for `indent-for-comment' in Kurila."
  (interactive)
  (let (kurila-wrong-comment)
    (indent-for-comment)
    (if kurila-wrong-comment		; set by `kurila-comment-indent'
	(progn (kurila-to-comment-or-eol)
	       (forward-char (length comment-start))))))

(defun kurila-comment-region (b e arg)
  "Comment or uncomment each line in the region in Kurila mode.
See `comment-region'."
  (interactive "r\np")
  (let ((comment-start "#"))
    (comment-region b e arg)))

(defun kurila-uncomment-region (b e arg)
  "Uncomment or comment each line in the region in Kurila mode.
See `comment-region'."
  (interactive "r\np")
  (let ((comment-start "#"))
    (comment-region b e (- arg))))

(defvar kurila-brace-recursing nil)

(defun kurila-electric-brace (arg &optional only-before)
  "Insert character and correct line's indentation.
If ONLY-BEFORE and `kurila-auto-newline', will insert newline before the
place (even in empty line), but not after.  If after \")\" and the inserted
char is \"{\", insert extra newline before only if
`kurila-extra-newline-before-brace'."
  (interactive "P")
  (let (insertpos
	(other-end (if (and kurila-electric-parens-mark
			    (kurila-mark-active)
			    (< (mark) (point)))
		       (mark)
		     nil)))
    (if (and other-end
	     (not kurila-brace-recursing)
	     (kurila-val 'kurila-electric-parens)
	     (>= (save-excursion (kurila-to-comment-or-eol) (point)) (point)))
	;; Need to insert a matching pair
	(progn
	  (save-excursion
	    (setq insertpos (point-marker))
	    (goto-char other-end)
	    (setq last-command-char ?\{)
	    (kurila-electric-lbrace arg insertpos))
	  (forward-char 1))
      ;; Check whether we close something "usual" with `}'
      (if (and (eq last-command-char ?\})
	       (not
		(condition-case nil
		    (save-excursion
		      (up-list (- (prefix-numeric-value arg)))
		      ;;(kurila-after-block-p (point-min))
		      (or (kurila-after-expr-p nil "{;)")
			  ;; after sub, else, continue
			  (kurila-after-block-p nil 'pre)))
		  (error nil))))
	  ;; Just insert the guy
	  (self-insert-command (prefix-numeric-value arg))
	(if (and (not arg)		; No args, end (of empty line or auto)
		 (eolp)
		 (or (and (null only-before)
			  (save-excursion
			    (skip-chars-backward " \t")
			    (bolp)))
		     (and (eq last-command-char ?\{) ; Do not insert newline
			  ;; if after ")" and `kurila-extra-newline-before-brace'
			  ;; is nil, do not insert extra newline.
			  (not kurila-extra-newline-before-brace)
			  (save-excursion
			    (skip-chars-backward " \t")
			    (eq (preceding-char) ?\))))
		     (if kurila-auto-newline
			 (progn (kurila-indent-line) (newline) t) nil)))
	    (progn
	      (self-insert-command (prefix-numeric-value arg))
	      (kurila-indent-line)
	      (if kurila-auto-newline
		  (setq insertpos (1- (point))))
	      (if (and kurila-auto-newline (null only-before))
		  (progn
		    (newline)
		    (kurila-indent-line)))
	      (save-excursion
		(if insertpos (progn (goto-char insertpos)
				     (search-forward (make-string
						      1 last-command-char))
				     (setq insertpos (1- (point)))))
		(delete-char -1))))
	(if insertpos
	    (save-excursion
	      (goto-char insertpos)
	      (self-insert-command (prefix-numeric-value arg)))
	  (self-insert-command (prefix-numeric-value arg)))))))

(defun kurila-electric-lbrace (arg &optional end)
  "Insert character, correct line's indentation, correct quoting by space."
  (interactive "P")
  (let ((kurila-brace-recursing t)
	(kurila-auto-newline kurila-auto-newline)
	(other-end (or end
		       (if (and kurila-electric-parens-mark
				(kurila-mark-active)
				(> (mark) (point)))
			   (save-excursion
			     (goto-char (mark))
			     (point-marker))
			 nil)))
	pos after)
    (and (kurila-val 'kurila-electric-lbrace-space)
	 (eq (preceding-char) ?$)
	 (save-excursion
	   (skip-chars-backward "$")
	   (looking-at "\\(\\$\\$\\)*\\$\\([^\\$]\\|$\\)"))
	 (insert ?\ ))
    ;; Check whether we are in comment
    (if (and
	 (save-excursion
	   (beginning-of-line)
	   (not (looking-at "[ \t]*#")))
	 (kurila-after-expr-p nil "{;)"))
	nil
      (setq kurila-auto-newline nil))
    (kurila-electric-brace arg)
    (and (kurila-val 'kurila-electric-parens)
	 (eq last-command-char ?{)
	 (memq last-command-char
	       (append kurila-electric-parens-string nil))
	 (or (if other-end (goto-char (marker-position other-end)))
	     t)
	 (setq last-command-char ?} pos (point))
	 (progn (kurila-electric-brace arg t)
		(goto-char pos)))))

(defun kurila-electric-paren (arg)
  "Insert an opening parenthesis or a matching pair of parentheses.
See `kurila-electric-parens'."
  (interactive "P")
  (let ((beg (save-excursion (beginning-of-line) (point)))
	(other-end (if (and kurila-electric-parens-mark
			    (kurila-mark-active)
			    (> (mark) (point)))
		       (save-excursion
			 (goto-char (mark))
			 (point-marker))
		     nil)))
    (if (and (kurila-val 'kurila-electric-parens)
	     (memq last-command-char
		   (append kurila-electric-parens-string nil))
	     (>= (save-excursion (kurila-to-comment-or-eol) (point)) (point))
	     ;;(not (save-excursion (search-backward "#" beg t)))
	     (if (eq last-command-char ?<)
		 (progn
		   (and abbrev-mode ; later it is too late, may be after `for'
			(expand-abbrev))
		   (kurila-after-expr-p nil "{;(,:="))
	       1))
	(progn
	  (self-insert-command (prefix-numeric-value arg))
	  (if other-end (goto-char (marker-position other-end)))
	  (insert (make-string
		   (prefix-numeric-value arg)
		   (cdr (assoc last-command-char '((?{ .?})
						   (?[ . ?])
						   (?( . ?))
						   (?< . ?>))))))
	  (forward-char (- (prefix-numeric-value arg))))
      (self-insert-command (prefix-numeric-value arg)))))

(defun kurila-electric-rparen (arg)
  "Insert a matching pair of parentheses if marking is active.
If not, or if we are not at the end of marking range, would self-insert.
Affected by `kurila-electric-parens'."
  (interactive "P")
  (let ((beg (save-excursion (beginning-of-line) (point)))
	(other-end (if (and kurila-electric-parens-mark
			    (kurila-val 'kurila-electric-parens)
			    (memq last-command-char
				  (append kurila-electric-parens-string nil))
			    (kurila-mark-active)
			    (< (mark) (point)))
		       (mark)
		     nil))
	p)
    (if (and other-end
	     (kurila-val 'kurila-electric-parens)
	     (memq last-command-char '( ?\) ?\] ?\} ?\> ))
	     (>= (save-excursion (kurila-to-comment-or-eol) (point)) (point))
	     ;;(not (save-excursion (search-backward "#" beg t)))
	     )
	(progn
	  (self-insert-command (prefix-numeric-value arg))
	  (setq p (point))
	  (if other-end (goto-char other-end))
	  (insert (make-string
		   (prefix-numeric-value arg)
		   (cdr (assoc last-command-char '((?\} . ?\{)
						   (?\] . ?\[)
						   (?\) . ?\()
						   (?\> . ?\<))))))
	  (goto-char (1+ p)))
      (self-insert-command (prefix-numeric-value arg)))))

(defun kurila-electric-keyword ()
  "Insert a construction appropriate after a keyword.
Help message may be switched off by setting `kurila-message-electric-keyword'
to nil."
  (let ((beg (save-excursion (beginning-of-line) (point)))
	(dollar (and (eq last-command-char ?$)
		     (eq this-command 'self-insert-command)))
	(delete (and (memq last-command-char '(?\ ?\n ?\t ?\f))
		     (memq this-command '(self-insert-command newline))))
	my do)
    (and (save-excursion
	   (condition-case nil
	       (progn
		 (backward-sexp 1)
		 (setq do (looking-at "do\\>")))
	     (error nil))
	   (kurila-after-expr-p nil "{;:"))
	 (save-excursion
	   (not
	    (re-search-backward
	     "[#\"'`]\\|\\<q\\(\\|[wqxr]\\)\\>"
	     beg t)))
	 (save-excursion (or (not (re-search-backward "^=" nil t))
			     (or
			      (looking-at "=cut")
			      (and kurila-use-syntax-table-text-property
				   (not (eq (get-text-property (point)
							       'syntax-type)
					    'pod))))))
	 (save-excursion (forward-sexp -1)
			 (not (memq (following-char) (append "$@%&*" nil))))
	 (progn
	   (and (eq (preceding-char) ?y)
		(progn			; "foreachmy"
		  (forward-char -2)
		  (insert " ")
		  (forward-char 2)
		  (setq my t dollar t
			delete
			(memq this-command '(self-insert-command newline)))))
	   (and dollar (insert " $"))
	   (kurila-indent-line)
	   ;;(insert " () {\n}")
 	   (cond
 	    (kurila-extra-newline-before-brace
 	     (insert (if do "\n" " ()\n"))
 	     (insert "{")
 	     (kurila-indent-line)
 	     (insert "\n")
 	     (kurila-indent-line)
 	     (insert "\n}")
	     (and do (insert " while ();")))
 	    (t
 	     (insert (if do " {\n} while ();" " () {\n}"))))
	   (or (looking-at "[ \t]\\|$") (insert " "))
	   (kurila-indent-line)
	   (if dollar (progn (search-backward "$")
			     (if my
				 (forward-char 1)
			       (delete-char 1)))
	     (search-backward ")")
	     (if (eq last-command-char ?\()
		 (progn			; Avoid "if (())"
		   (delete-backward-char 1)
		   (delete-backward-char -1))))
	   (if delete
	       (kurila-putback-char kurila-del-back-ch))
	   (if kurila-message-electric-keyword
	       (message "Precede char by C-q to avoid expansion"))))))

(defun kurila-ensure-newlines (n &optional pos)
  "Make sure there are N newlines after the point."
  (or pos (setq pos (point)))
  (if (looking-at "\n")
      (forward-char 1)
    (insert "\n"))
  (if (> n 1)
      (kurila-ensure-newlines (1- n) pos)
    (goto-char pos)))

(defun kurila-electric-pod ()
  "Insert a POD chunk appropriate after a =POD directive."
  (let ((delete (and (memq last-command-char '(?\ ?\n ?\t ?\f))
		     (memq this-command '(self-insert-command newline))))
	head1 notlast name p really-delete over)
    (and (save-excursion
	   (forward-word -1)
	   (and
	    (eq (preceding-char) ?=)
	    (progn
	      (setq head1 (looking-at "head1\\>[ \t]*$"))
	      (setq over (and (looking-at "over\\>[ \t]*$")
			      (not (looking-at "over[ \t]*\n\n\n*=item\\>"))))
	      (forward-char -1)
	      (bolp))
	    (or
	     (get-text-property (point) 'in-pod)
	     (kurila-after-expr-p nil "{;:")
	     (and (re-search-backward "\\(\\`\n?\\|^\n\\)=\\sw+" (point-min) t)
		  (not (looking-at "\n*=cut"))
		  (or (not kurila-use-syntax-table-text-property)
		      (eq (get-text-property (point) 'syntax-type) 'pod))))))
	 (progn
	   (save-excursion
	     (setq notlast (re-search-forward "^\n=" nil t)))
	   (or notlast
	       (progn
		 (insert "\n\n=cut")
		 (kurila-ensure-newlines 2)
		 (forward-word -2)
		 (if (and head1
			  (not
			   (save-excursion
			     (forward-char -1)
			     (re-search-backward "\\(\\`\n?\\|\n\n\\)=head1\\>"
						 nil t)))) ; Only one
		     (progn
		       (forward-word 1)
		       (setq name (file-name-sans-extension
				   (file-name-nondirectory (buffer-file-name)))
			     p (point))
		       (insert " NAME\n\n" name
			       " - \n\n=head1 SYNOPSIS\n\n\n\n"
			       "=head1 DESCRIPTION")
		       (kurila-ensure-newlines 4)
		       (goto-char p)
		       (forward-word 2)
		       (end-of-line)
		       (setq really-delete t))
		   (forward-word 1))))
	   (if over
	       (progn
		 (setq p (point))
		 (insert "\n\n=item \n\n\n\n"
			 "=back")
		 (kurila-ensure-newlines 2)
		 (goto-char p)
		 (forward-word 1)
		 (end-of-line)
		 (setq really-delete t)))
	   (if (and delete really-delete)
	       (kurila-putback-char kurila-del-back-ch))))))

(defun kurila-electric-else ()
  "Insert a construction appropriate after a keyword.
Help message may be switched off by setting `kurila-message-electric-keyword'
to nil."
  (let ((beg (save-excursion (beginning-of-line) (point))))
    (and (save-excursion
	   (backward-sexp 1)
	   (kurila-after-expr-p nil "{;:"))
	 (save-excursion
	   (not
	    (re-search-backward
	     "[#\"'`]\\|\\<q\\(\\|[wqxr]\\)\\>"
	     beg t)))
	 (save-excursion (or (not (re-search-backward "^=" nil t))
			     (looking-at "=cut")
			     (and kurila-use-syntax-table-text-property
				  (not (eq (get-text-property (point)
							      'syntax-type)
					   'pod)))))
	 (progn
	   (kurila-indent-line)
	   ;;(insert " {\n\n}")
 	   (cond
 	    (kurila-extra-newline-before-brace
 	     (insert "\n")
 	     (insert "{")
 	     (kurila-indent-line)
 	     (insert "\n\n}"))
 	    (t
 	     (insert " {\n\n}")))
	   (or (looking-at "[ \t]\\|$") (insert " "))
	   (kurila-indent-line)
	   (forward-line -1)
	   (kurila-indent-line)
	   (kurila-putback-char kurila-del-back-ch)
	   (setq this-command 'kurila-electric-else)
	   (if kurila-message-electric-keyword
	       (message "Precede char by C-q to avoid expansion"))))))

(defun kurila-linefeed ()
  "Go to end of line, open a new line and indent appropriately.
If in POD, insert appropriate lines."
  (interactive)
  (let ((beg (save-excursion (beginning-of-line) (point)))
	(end (save-excursion (end-of-line) (point)))
	(pos (point)) start over cut res)
    (if (and				; Check if we need to split:
					; i.e., on a boundary and inside "{...}"
	 (save-excursion (kurila-to-comment-or-eol)
			 (>= (point) pos)) ; Not in a comment
	 (or (save-excursion
	       (skip-chars-backward " \t" beg)
	       (forward-char -1)
	       (looking-at "[;{]"))     ; After { or ; + spaces
	     (looking-at "[ \t]*}")	; Before }
	     (re-search-forward "\\=[ \t]*;" end t)) ; Before spaces + ;
	 (save-excursion
	   (and
	    (eq (car (parse-partial-sexp pos end -1)) -1)
					; Leave the level of parens
	    (looking-at "[,; \t]*\\($\\|#\\)") ; Comma to allow anon subr
					; Are at end
	    (kurila-after-block-p (point-min))
	    (progn
	      (backward-sexp 1)
	      (setq start (point-marker))
	      (<= start pos)))))	; Redundant?  Are after the
					; start of parens group.
	(progn
	  (skip-chars-backward " \t")
	  (or (memq (preceding-char) (append ";{" nil))
	      (insert ";"))
	  (insert "\n")
	  (forward-line -1)
	  (kurila-indent-line)
	  (goto-char start)
	  (or (looking-at "{[ \t]*$")	; If there is a statement
					; before, move it to separate line
	      (progn
		(forward-char 1)
		(insert "\n")
		(kurila-indent-line)))
	  (forward-line 1)		; We are on the target line
	  (kurila-indent-line)
	  (beginning-of-line)
	  (or (looking-at "[ \t]*}[,; \t]*$") ; If there is a statement
					; after, move it to separate line
	      (progn
		(end-of-line)
		(search-backward "}" beg)
		(skip-chars-backward " \t")
		(or (memq (preceding-char) (append ";{" nil))
		    (insert ";"))
		(insert "\n")
		(kurila-indent-line)
		(forward-line -1)))
	  (forward-line -1)		; We are on the line before target
	  (end-of-line)
	  (newline-and-indent))
      (end-of-line)			; else - no splitting
      (cond
       ((and (looking-at "\n[ \t]*{$")
	     (save-excursion
	       (skip-chars-backward " \t")
	       (eq (preceding-char) ?\)))) ; Probably if () {} group
					; with an extra newline.
	(forward-line 2)
	(kurila-indent-line))
       ((save-excursion			; In POD header
	  (forward-paragraph -1)
	  ;; (re-search-backward "\\(\\`\n?\\|\n\n\\)=head1\\b")
	  ;; We are after \n now, so look for the rest
	  (if (looking-at "\\(\\`\n?\\|\n\\)=\\sw+")
	      (progn
		(setq cut (looking-at "\\(\\`\n?\\|\n\\)=cut\\>"))
		(setq over (looking-at "\\(\\`\n?\\|\n\\)=over\\>"))
		t)))
	(if (and over
		 (progn
		   (forward-paragraph -1)
		   (forward-word 1)
		   (setq pos (point))
		   (setq cut (buffer-substring (point)
					       (save-excursion
						 (end-of-line)
						 (point))))
		   (delete-char (- (save-excursion (end-of-line) (point))
				   (point)))
		   (setq res (expand-abbrev))
		   (save-excursion
		     (goto-char pos)
		     (insert cut))
		   res))
	    nil
	  (kurila-ensure-newlines (if cut 2 4))
	  (forward-line 2)))
       ((get-text-property (point) 'in-pod) ; In POD section
	(kurila-ensure-newlines 4)
	(forward-line 2))
       ((looking-at "\n[ \t]*$")	; Next line is empty - use it.
        (forward-line 1)
	(kurila-indent-line))
       (t
	(newline-and-indent))))))

(defun kurila-electric-semi (arg)
  "Insert character and correct line's indentation."
  (interactive "P")
  (if kurila-auto-newline
      (kurila-electric-terminator arg)
    (self-insert-command (prefix-numeric-value arg))
    (if kurila-autoindent-on-semi
	(kurila-indent-line))))

(defun kurila-electric-terminator (arg)
  "Insert character and correct line's indentation."
  (interactive "P")
  (let ((end (point))
	(auto (and kurila-auto-newline
		   (or (not (eq last-command-char ?:))
		       kurila-auto-newline-after-colon)))
	insertpos)
    (if (and ;;(not arg)
	     (eolp)
	     (not (save-excursion
		    (beginning-of-line)
		    (skip-chars-forward " \t")
		    (or
		     ;; Ignore in comment lines
		     (= (following-char) ?#)
		     ;; Colon is special only after a label
		     ;; So quickly rule out most other uses of colon
		     ;; and do no indentation for them.
		     (and (eq last-command-char ?:)
			  (save-excursion
			    (forward-word 1)
			    (skip-chars-forward " \t")
			    (and (< (point) end)
				 (progn (goto-char (- end 1))
					(not (looking-at ":"))))))
		     (progn
		       (beginning-of-defun)
		       (let ((pps (parse-partial-sexp (point) end)))
			 (or (nth 3 pps) (nth 4 pps) (nth 5 pps))))))))
	(progn
	  (self-insert-command (prefix-numeric-value arg))
	  ;;(forward-char -1)
	  (if auto (setq insertpos (point-marker)))
	  ;;(forward-char 1)
	  (kurila-indent-line)
	  (if auto
	      (progn
		(newline)
		(kurila-indent-line)))
	  (save-excursion
	    (if insertpos (goto-char (1- (marker-position insertpos)))
	      (forward-char -1))
	    (delete-char 1))))
    (if insertpos
	(save-excursion
	  (goto-char insertpos)
	  (self-insert-command (prefix-numeric-value arg)))
      (self-insert-command (prefix-numeric-value arg)))))

(defun kurila-electric-backspace (arg)
  "Backspace, or remove the whitespace around the point inserted by an electric
key.  Will untabivy if `kurila-electric-backspace-untabify' is non-nil."
  (interactive "p")
  (if (and kurila-auto-newline
	   (memq last-command '(kurila-electric-semi
				kurila-electric-terminator
				kurila-electric-lbrace))
	   (memq (preceding-char) '(?\  ?\t ?\n)))
      (let (p)
	(if (eq last-command 'kurila-electric-lbrace)
	    (skip-chars-forward " \t\n"))
	(setq p (point))
	(skip-chars-backward " \t\n")
	(delete-region (point) p))
    (and (eq last-command 'kurila-electric-else)
	 ;; We are removing the whitespace *inside* kurila-electric-else
	 (setq this-command 'kurila-electric-else-really))
    (if (and kurila-auto-newline
	     (eq last-command 'kurila-electric-else-really)
	     (memq (preceding-char) '(?\  ?\t ?\n)))
	(let (p)
	  (skip-chars-forward " \t\n")
	  (setq p (point))
	  (skip-chars-backward " \t\n")
	  (delete-region (point) p))
      (if kurila-electric-backspace-untabify
	  (backward-delete-char-untabify arg)
	(delete-backward-char arg)))))

(defun kurila-indent-line (&optional parse-data)
  "Indent current line as Perl code.
Return the amount the indentation changed by."
  (let ((case-fold-search nil)
	(pos (- (point-max) (point)))
	indent i beg shift-amt)
    (setq indent (kurila-calculate-indent parse-data)
	  i indent)
    (beginning-of-line)
    (setq beg (point))
    (cond ((or (eq indent nil) (eq indent t))
	   (setq indent (current-indentation) i nil))
	  ;;((eq indent t)    ; Never?
	  ;; (setq indent (kurila-calculate-indent-within-comment)))
	  ;;((looking-at "[ \t]*#")
	  ;; (setq indent 0))
	  (t
	   (skip-chars-forward " \t")
	   (if (listp indent) (setq indent (car indent)))
	   (cond ((and (looking-at "[A-Za-z_][A-Za-z_0-9]*:[^:]")
		       (not (looking-at "[smy]:\\|tr:")))
		  (and (> indent 0)
		       (setq indent (max kurila-min-label-indent
					 (+ indent kurila-label-offset)))))
		 ((= (following-char) ?})
		  (setq indent (- indent kurila-indent-level)))
		 ((memq (following-char) '(?\) ?\])) ; To line up with opening paren.
		  (setq indent (+ indent kurila-close-paren-offset)))
		 ((= (following-char) ?{)
		  (setq indent (+ indent kurila-brace-offset))))))
    (skip-chars-forward " \t")
    (setq shift-amt (and i (- indent (current-column))))
    (if (or (not shift-amt)
	    (zerop shift-amt))
	(if (> (- (point-max) pos) (point))
	    (goto-char (- (point-max) pos)))
      ;;;(delete-region beg (point))
      ;;;(indent-to indent)
      (kurila-make-indent indent)
      ;; If initial point was within line's indentation,
      ;; position after the indentation.  Else stay at same point in text.
      (if (> (- (point-max) pos) (point))
	  (goto-char (- (point-max) pos))))
    shift-amt))

(defun kurila-after-label ()
  ;; Returns true if the point is after label.  Does not do save-excursion.
  (and (eq (preceding-char) ?:)
       (memq (char-syntax (char-after (- (point) 2)))
	     '(?w ?_))
       (progn
	 (backward-sexp)
	 (looking-at "[a-zA-Z_][a-zA-Z0-9_]*:[^:]"))))

(defun kurila-get-state (&optional parse-start start-state)
  ;; returns list (START STATE DEPTH PRESTART),
  ;; START is a good place to start parsing, or equal to
  ;; PARSE-START if preset,
  ;; STATE is what is returned by `parse-partial-sexp'.
  ;; DEPTH is true is we are immediately after end of block
  ;; which contains START.
  ;; PRESTART is the position basing on which START was found.
  (save-excursion
    (let ((start-point (point)) depth state start prestart)
      (if (and parse-start
	       (<= parse-start start-point))
	  (goto-char parse-start)
	(beginning-of-defun)
	(setq start-state nil))
      (setq prestart (point))
      (if start-state nil
	;; Try to go out, if sub is not on the outermost level
	(while (< (point) start-point)
	  (setq start (point) parse-start start depth nil
		state (parse-partial-sexp start start-point -1))
	  (if (> (car state) -1) nil
	    ;; The current line could start like }}}, so the indentation
	    ;; corresponds to a different level than what we reached
	    (setq depth t)
	    (beginning-of-line 2)))	; Go to the next line.
	(if start (goto-char start)))	; Not at the start of file
      (setq start (point))
      (or state (setq state (parse-partial-sexp start start-point -1 nil start-state)))
      (list start state depth prestart))))

(defvar kurila-look-for-prop '((pod in-pod) (here-doc-delim here-doc-group)))

(defun kurila-beginning-of-property (p prop &optional lim)
  "Given that P has a property PROP, find where the property starts.
Will not look before LIM."
  ;;; XXXX What to do at point-max???
  (or (previous-single-property-change (kurila-1+ p) prop lim)
      (point-min))
;;;  (cond ((eq p (point-min))
;;;	 p)
;;;	((and lim (<= p lim))
;;;	 p)
;;;	((not (get-text-property (1- p) prop))
;;;	 p)
;;;	(t (or (previous-single-property-change p look-prop lim)
;;;	       (point-min))))
  )

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
       ((and (memq res '(pod here-doc here-doc-delim))
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
	    (if (memq prop '(pod here-doc here-doc-delim))
		(progn
		  (goto-char (kurila-beginning-of-property p look-prop))
		  (beginning-of-line)
		  (setq pre-indent-point (point)))))
	  (goto-char pre-indent-point)	; Orig line skipping preceeding pod/etc
	  (let* ((case-fold-search nil)
		 (s-s (kurila-get-state (car parse-data) (nth 1 parse-data)))
		 (start (or (nth 2 parse-data) ; last complete sexp terminated
			    (nth 0 s-s))) ; Good place to start parsing
		 (state (nth 1 s-s))
		 (containing-sexp (car (cdr state)))
		 old-indent)
	    (if (and
		 ;;containing-sexp		;; We are buggy at toplevel :-(
		 parse-data)
		(progn
		  (setcar parse-data pre-indent-point)
		  (setcar (cdr parse-data) state)
		  (or (nth 2 parse-data)
		      (setcar (cddr parse-data) start))
		  ;; Before this point: end of statement
		  (setq old-indent (nth 3 parse-data))))
	    (cond ((get-text-property (point) 'indentable)
		   ;; indent to "after" the surrounding open
		   ;; (same offset as `kurila-beautify-regexp-piece'),
		   ;; skip blanks if we do not close the expression.
		   (setq delim		; We do not close the expression
			 (get-text-property
			  (kurila-1+ char-after-pos) 'indentable)
			 p (1+ (kurila-beginning-of-property
				(point) 'indentable))
			 is-block	; misused for: preceeding line in REx
			 (save-excursion ; Find preceeding line
			   (kurila-backward-to-noncomment p)
			   (beginning-of-line)
			   (if (<= (point) p)
			       (progn	; get indent from the first line
				 (goto-char p)
				 (skip-chars-forward " \t")
				 (if (memq (char-after (point))
					   (append "#\n" nil))
				     nil ; Can't use intentation of this line...
				   (point)))
			     (skip-chars-forward " \t")
			     (point)))
			 prop (parse-partial-sexp p char-after-pos))
		   (cond ((not delim)	; End the REx, ignore is-block
			  (vector 'indentable 'terminator p is-block))
			 (is-block	; Indent w.r.t. preceeding line
			  (vector 'indentable 'cont-line char-after-pos
				  is-block char-after p))
			 (t		; No preceeding line...
			  (vector 'indentable 'first-line p))))
		  ((get-text-property char-after-pos 'REx-part2)
		   (vector 'REx-part2 (point)))
		  ((nth 4 state)
		   [comment])
		  ((nth 3 state)
		   [string])
		  ;; XXXX Do we need to special-case this?
		  ((null containing-sexp)
		   ;; Line is at top level.  May be data or function definition,
		   ;; or may be function argument declaration.
		   ;; Indent like the previous top level line
		   ;; unless that ends in a closeparen without semicolon,
		   ;; in which case this line is the first argument decl.
		   (skip-chars-forward " \t")
		   (kurila-backward-to-noncomment (or old-indent (point-min)))
		   (setq state
			 (or (bobp)
			     (eq (point) old-indent) ; old-indent was at comment
			     (eq (preceding-char) ?\;)
			     ;;  Had ?\) too
			     (and (eq (preceding-char) ?\})
				  (kurila-after-block-and-statement-beg
				   (point-min))) ; Was start - too close
			     (memq char-after (append ")]}" nil))
			     (and (eq (preceding-char) ?\:) ; label
				  (progn
				    (forward-sexp -1)
				    (skip-chars-backward " \t")
				    (looking-at "[ \t]*[a-zA-Z_][a-zA-Z_0-9]*[ \t]*:")))))
		   
		   ;; Look at previous line that's at column 0
		   ;; to determine whether we are in top-level decls
		   ;; or function's arg decls.  Set basic-indent accordingly.
		   ;; Now add a little if this is a continuation line.
		   (and state
			parse-data
			(not (eq char-after ?\C-j))
			(setcdr (cddr parse-data)
				(list pre-indent-point)))
		   (vector 'toplevel start char-after state (nth 2 s-s)))
		  ((not
		    (or (setq is-block
			      (and (setq delim (= (char-after containing-sexp) ?{))
				   (save-excursion ; Is it a hash?
				     (goto-char containing-sexp)
				     (kurila-block-p))))
			kurila-indent-parens-as-block))
		   ;; group is an expression, not a block:
		   ;; indent to just after the surrounding open parens,
		   ;; skip blanks if we do not close the expression.
		   (goto-char (1+ containing-sexp))
		   (or (memq char-after
			     (append (if delim "}" ")]}") nil))
		       (looking-at "[ \t]*\\(#\\|$\\)")
		       (skip-chars-forward " \t"))
		   (setq old-indent (point)) ; delim=is-brace
		   (vector 'in-parens char-after (point) delim containing-sexp))
		  (t
		   ;; Statement level.  Is it a continuation or a new statement?
		   ;; Find previous non-comment character.
		   (goto-char pre-indent-point) ; Skip one level of POD/etc
		   (kurila-backward-to-noncomment containing-sexp)
		   ;; Back up over label lines, since they don't
		   ;; affect whether our line is a continuation.
		   ;; (Had \, too)
		   (while;;(or (eq (preceding-char) ?\,)
		       (and (eq (preceding-char) ?:)
			    (or;;(eq (char-after (- (point) 2)) ?\') ; ????
			     (memq (char-syntax (char-after (- (point) 2)))
				   '(?w ?_))))
		     ;;)
		     ;; This is always FALSE?
		     (if (eq (preceding-char) ?\,)
			 ;; Will go to beginning of line, essentially.
			 ;; Will ignore embedded sexpr XXXX.
			 (kurila-backward-to-start-of-continued-exp containing-sexp))
		     (beginning-of-line)
		     (kurila-backward-to-noncomment containing-sexp))
		   ;; Now we get non-label preceeding the indent point
		   (if (not (or (eq (1- (point)) containing-sexp)
				(memq (preceding-char)
				      (append (if is-block " ;{" " ,;{") '(nil)))
				(and (eq (preceding-char) ?\})
				     (kurila-after-block-and-statement-beg
				      containing-sexp))))
		       ;; This line is continuation of preceding line's statement;
		       ;; indent  `kurila-continued-statement-offset'  more than the
		       ;; previous line of the statement.
		       ;;
		       ;; There might be a label on this line, just
		       ;; consider it bad style and ignore it.
		       (progn
			 (kurila-backward-to-start-of-continued-exp containing-sexp)
			 (vector 'continuation (point) char-after is-block delim))
		     ;; This line starts a new statement.
		     ;; Position following last unclosed open brace
		     (goto-char containing-sexp)
		     ;; Is line first statement after an open-brace?
		     (or
		      ;; If no, find that first statement and indent like
		      ;; it.  If the first statement begins with label, do
		      ;; not believe when the indentation of the label is too
		      ;; small.
		      (save-excursion
			(forward-char 1)
			(let ((colon-line-end 0))
			  (while
			      (progn (skip-chars-forward " \t\n")
				     ;; s: foo : bar :x is NOT label
				     (and (looking-at "#\\|\\([a-zA-Z0-9_$]+\\):[^:]\\|=[a-zA-Z]")
					  (not (looking-at "[sym]:\\|tr:"))))
			    ;; Skip over comments and labels following openbrace.
			    (cond ((= (following-char) ?\#)
				   (forward-line 1))
				  ((= (following-char) ?\=)
				   (goto-char
				    (or (next-single-property-change (point) 'in-pod)
					(point-max)))) ; do not loop if no syntaxification
				  ;; label:
				  (t
				   (save-excursion (end-of-line)
						   (setq colon-line-end (point)))
				   (search-forward ":"))))
			  ;; We are at beginning of code (NOT label or comment)
			  ;; First, the following code counts
			  ;; if it is before the line we want to indent.
			  (and (< (point) indent-point)
			       (vector 'have-prev-sibling (point) colon-line-end
				       containing-sexp))))
		      (progn
			;; If no previous statement,
			;; indent it relative to line brace is on.

			;; For open-braces not the first thing in a line,
			;; add in kurila-brace-imaginary-offset.

			;; If first thing on a line:  ?????
			;; Move back over whitespace before the openbrace.
			(setq		; brace first thing on a line
			 old-indent (progn (skip-chars-backward " \t") (bolp)))
			;; Should we indent w.r.t. earlier than start?
			;; Move to start of control group, possibly on a different line
			(or kurila-indent-wrt-brace
			    (kurila-backward-to-noncomment (point-min)))
			;; If the openbrace is preceded by a parenthesized exp,
			;; move to the beginning of that;
			(if (eq (preceding-char) ?\))
			    (progn
			      (forward-sexp -1)
			      (kurila-backward-to-noncomment (point-min))))
			;; In the case it starts a subroutine, indent with
			;; respect to `sub', not with respect to the
			;; first thing on the line, say in the case of
			;; anonymous sub in a hash.
			(if (and;; Is it a sub in group starting on this line?
			     (cond ((get-text-property (point) 'attrib-group)
				    (goto-char (kurila-beginning-of-property
						(point) 'attrib-group)))
				   ((eq (preceding-char) ?b)
				    (forward-sexp -1)
				    (looking-at "sub\\>")))
			     (setq p (nth 1 ; start of innermost containing list
					  (parse-partial-sexp
					   (save-excursion (beginning-of-line)
							   (point))
					   (point)))))
			    (progn
			      (goto-char (1+ p)) ; enclosing block on the same line
			      (skip-chars-forward " \t")
			      (vector 'code-start-in-block containing-sexp char-after
				      (and delim (not is-block)) ; is a HASH
				      old-indent ; brace first thing on a line
				      t (point) ; have something before...
				      )
			      ;;(current-column)
			      )
			  ;; Get initial indentation of the line we are on.
			  ;; If line starts with label, calculate label indentation
			  (vector 'code-start-in-block containing-sexp char-after
				  (and delim (not is-block)) ; is a HASH
				  old-indent ; brace first thing on a line
				  nil (point))))))))))))))) ; nothing interesting before

(defvar kurila-indent-rules-alist
  '((pod nil)				; via `syntax-type' property
    (here-doc nil)			; via `syntax-type' property
    (here-doc-delim nil)		; via `syntax-type' property
    (in-pod nil)			; via `in-pod' property
    (comment-special:at-beginning-of-line nil)
    (string t)
    (comment nil))
  "Alist of indentation rules for Kurila mode.
The values mean:
  nil: do not indent;
  number: add this amount of indentation.")

(defun kurila-calculate-indent (&optional parse-data) ; was parse-start
  "Return appropriate indentation for current line as Perl code.
In usual case returns an integer: the column to indent to.
Returns nil if line starts inside a string, t if in a comment.

Will not correct the indentation for labels, but will correct it for braces
and closing parentheses and brackets."
  ;; This code is still a broken architecture: in some cases we need to
  ;; compensate for some modifications which `kurila-indent-line' will add later
  (car (kurila-indent-indentation-info)))

(defun kurila-calculate-indent-within-comment ()
  "Return the indentation amount for line, assuming that
the current line is to be regarded as part of a block comment."
  (let (end star-start)
    (save-excursion
      (beginning-of-line)
      (skip-chars-forward " \t")
      (setq end (point))
      (and (= (following-char) ?#)
	   (forward-line -1)
	   (kurila-to-comment-or-eol)
	   (setq end (point)))
      (goto-char end)
      (current-column))))


(defun kurila-to-comment-or-eol ()
  "Go to position before comment on the current line, or to end of line.
Returns true if comment is found.  In POD will not move the point."
  ;; If the line is inside other syntax groups (qq-style strings, HERE-docs)
  ;; then looks for literal # or end-of-line.
  (let (state stop-in cpoint (lim (progn (end-of-line) (point))) pr e)
    (or kurila-font-locking
	(kurila-update-syntaxification lim lim))
    (beginning-of-line)
    (if (setq pr (get-text-property (point) 'syntax-type))
	(setq e (next-single-property-change (point) 'syntax-type nil (point-max))))
    (if (or (eq pr 'pod)
	    (if (or (not e) (> e lim))	; deep inside a group
		(re-search-forward "\\=[ \t]*\\(#\\|$\\)" lim t)))
	(if (eq (preceding-char) ?\#) (progn (backward-char 1) t))
      ;; Else - need to do it the hard way
      (and (and e (<= e lim))
	   (goto-char e))
      (while (not stop-in)
	(setq state (parse-partial-sexp (point) lim nil nil nil t))
					; stop at comment
	;; If fails (beginning-of-line inside sexp), then contains not-comment
	(if (nth 4 state)		; After `#';
					; (nth 2 state) can be
					; beginning of m,s,qq and so
					; on
	    (if (nth 2 state)
		(progn
		  (setq cpoint (point))
		  (goto-char (nth 2 state))
		  (cond
		   ((looking-at "\\(s\\|tr\\)\\>")
		    (or (re-search-forward
			 "\\=\\w+[ \t]*#\\([^\n\\\\#]\\|\\\\[\\\\#]\\)*#\\([^\n\\\\#]\\|\\\\[\\\\#]\\)*"
			 lim 'move)
			(setq stop-in t)))
		   ((looking-at "\\(m\\|q\\([qxwr]\\)?\\)\\>")
		    (or (re-search-forward
			 "\\=\\w+[ \t]*#\\([^\n\\\\#]\\|\\\\[\\\\#]\\)*#"
			 lim 'move)
			(setq stop-in t)))
		   (t			; It was fair comment
		    (setq stop-in t)	; Finish
		    (goto-char (1- cpoint)))))
	      (setq stop-in t)		; Finish
	      (forward-char -1))
	  (setq stop-in t)))		; Finish
      (nth 4 state))))

(defsubst kurila-modify-syntax-type (at how)
  (if (< at (point-max))
      (progn
	(put-text-property at (1+ at) 'syntax-table how)
	(put-text-property at (1+ at) 'rear-nonsticky '(syntax-table)))))

(defun kurila-protect-defun-start (s e)
  ;; C code looks for "^\\s(" to skip comment backward in "hard" situations
  (save-excursion
    (goto-char s)
    (while (re-search-forward "^\\s(" e 'to-end)
      (put-text-property (1- (point)) (point) 'syntax-table kurila-st-punct))))

(defun kurila-commentify (bb e string &optional noface)
  (if kurila-use-syntax-table-text-property
      (if (eq noface 'n)		; Only immediate
	  nil
	;; We suppose that e is _after_ the end of construction, as after eol.
	(setq string (if string kurila-st-sfence kurila-st-cfence))
	(if (> bb (- e 2))
	    ;; one-char string/comment?!
	    (kurila-modify-syntax-type bb kurila-st-punct)
	  (kurila-modify-syntax-type bb string)
	  (kurila-modify-syntax-type (1- e) string))
	(if (and (eq string kurila-st-sfence) (> (- e 2) bb))
	    (put-text-property (1+ bb) (1- e)
			       'syntax-table kurila-string-syntax-table))
	(kurila-protect-defun-start bb e))
    ;; Fontify
    (or noface
	(not kurila-pod-here-fontify)
	(put-text-property bb e 'face (if string 'font-lock-string-face
					'font-lock-comment-face)))))

(defvar kurila-starters '(( ?\( . ?\) )
			 ( ?\[ . ?\] )
			 ( ?\{ . ?\} )
			 ( ?\< . ?\> )))

(defun kurila-cached-syntax-table (st)
  "Get a syntax table cached in ST, or create and cache into ST a syntax table.
All the entries of the syntax table are \".\", except for a backslash, which
is quoting."
  (if (car-safe st)
      (car st)
    (setcar st (make-syntax-table))
    (setq st (car st))
    (let ((i 0))
      (while (< i 256)
	(modify-syntax-entry i "." st)
	(setq i (1+ i))))
    (modify-syntax-entry ?\\ "\\" st)
    st))

(defun kurila-forward-re (lim end is-2arg st-l err-l argument
			     &optional ostart oend)
"Find the end of a regular expression or a stringish construct (q[] etc).
The point should be before the starting delimiter.

Goes to LIM if none is found.  If IS-2ARG is non-nil, assumes that it
is s/// or tr/// like expression.  If END is nil, generates an error
message if needed.  If SET-ST is non-nil, will use (or generate) a
cached syntax table in ST-L.  If ERR-L is non-nil, will store the
error message in its CAR (unless it already contains some error
message).  ARGUMENT should be the name of the construct (used in error
messages).  OSTART, OEND may be set in recursive calls when processing
the second argument of 2ARG construct.

Works *before* syntax recognition is done.  In IS-2ARG situation may
modify syntax-type text property if the situation is too hard."
  (let (b starter ender st i i2 go-forward reset-st set-st)
    (skip-chars-forward " \t")
    ;; ender means matching-char matcher.
    (setq b (point)
	  starter (if (eobp) 0 (char-after b))
	  ender (cdr (assoc starter kurila-starters)))
    ;; What if starter == ?\\  ????
    (setq st (kurila-cached-syntax-table st-l))
    (setq set-st t)
    ;; Whether we have an intermediate point
    (setq i nil)
    ;; Prepare the syntax table:
    (if (not ender)		; m/blah/, s/x//, s/x/y/
	(modify-syntax-entry starter "$" st)
      (modify-syntax-entry starter (concat "(" (list ender)) st)
      (modify-syntax-entry ender  (concat ")" (list starter)) st))
    (condition-case bb
	(progn
	  ;; We use `$' syntax class to find matching stuff, but $$
	  ;; is recognized the same as $, so we need to check this manually.
	  (if (and (eq starter (char-after (kurila-1+ b)))
		   (not ender))
	      ;; $ has TeXish matching rules, so $$ equiv $...
	      (forward-char 2)
	    (setq reset-st (syntax-table))
	    (set-syntax-table st)
	    (forward-sexp 1)
	    (if (<= (point) (1+ b))
		(error "Unfinished regular expression"))
	    (set-syntax-table reset-st)
	    (setq reset-st nil)
	    ;; Now the problem is with m;blah;;
	    (and (not ender)
		 (eq (preceding-char)
		     (char-after (- (point) 2)))
		 (save-excursion
		   (forward-char -2)
		   (= 0 (% (skip-chars-backward "\\\\") 2)))
		 (forward-char -1)))
	  ;; Now we are after the first part.
	  (and is-2arg			; Have trailing part
	       (not ender)
	       (eq (following-char) starter) ; Empty trailing part
	       (progn
		 (or (eq (char-syntax (following-char)) ?.)
		     ;; Make trailing letter into punctuation
		     (kurila-modify-syntax-type (point) kurila-st-punct))
		 (setq is-2arg nil go-forward t))) ; Ignore the tail
	  (if is-2arg			; Not number => have second part
	      (progn
		(setq i (point) i2 i)
		(if ender
		    (if (memq (following-char) '(?\  ?\t ?\n ?\f))
			(progn
			  (if (looking-at "[ \t\n\f]+\\(#[^\n]*\n[ \t\n\f]*\\)+")
			      (goto-char (match-end 0))
			    (skip-chars-forward " \t\n\f"))
			  (setq i2 (point))))
		  (forward-char -1))
		(modify-syntax-entry starter (if (eq starter ?\\) "\\" ".") st)
		(if ender (modify-syntax-entry ender "." st))
		(setq set-st nil)
		(setq ender (kurila-forward-re lim end nil st-l err-l
					      argument starter ender)
		      ender (nth 2 ender)))))
      (error (goto-char lim)
	     (setq set-st nil)
	     (if reset-st
		 (set-syntax-table reset-st))
	     (or end
		 (message
		  "End of `%s%s%c ... %c' string/RE not found: %s"
		  argument
		  (if ostart (format "%c ... %c" ostart (or oend ostart)) "")
		  starter (or ender starter) bb)
		 (or (car err-l) (setcar err-l b)))))
    (if set-st
	(progn
	  (modify-syntax-entry starter (if (eq starter ?\\) "\\" ".") st)
	  (if ender (modify-syntax-entry ender "." st))))
    ;; i: have 2 args, after end of the first arg
    ;; i2: start of the second arg, if any (before delim iff `ender').
    ;; ender: the last arg bounded by parens-like chars, the second one of them
    ;; starter: the starting delimiter of the first arg
    ;; go-forward: has 2 args, and the second part is empty
    (list i i2 ender starter go-forward)))

(defun kurila-forward-group-in-re (&optional st-l)
  "Find the end of a group in a REx.
Return the error message (if any).  Does not work if delimiter is `)'.
Works before syntax recognition is done."
  ;; Works *before* syntax recognition is done
  (or st-l (setq st-l (list nil)))	; Avoid overwriting '()
  (let (st b reset-st)
    (condition-case b
	(progn
	  (setq st (kurila-cached-syntax-table st-l))
	  (modify-syntax-entry ?\( "()" st)
	  (modify-syntax-entry ?\) ")(" st)
	  (setq reset-st (syntax-table))
	  (set-syntax-table st)
	  (forward-sexp 1))
      (error (message
	      "kurila-forward-group-in-re: error %s" b)))
    ;; now restore the initial state
    (if st
	(progn
	  (modify-syntax-entry ?\( "." st)
	  (modify-syntax-entry ?\) "." st)))
    (if reset-st
	(set-syntax-table reset-st))
    b))


(defvar font-lock-string-face)
;;(defvar font-lock-reference-face)
(defvar font-lock-constant-face)
(defsubst kurila-postpone-fontification (b e type val &optional now)
  ;; Do after syntactic fontification?
  (if kurila-syntaxify-by-font-lock
      (or now (put-text-property b e 'kurila-postpone (cons type val)))
    (put-text-property b e type val)))

;;; Here is how the global structures (those which cannot be
;;; recognized locally) are marked:
;;	a) PODs:
;;		Start-to-end is marked `in-pod' ==> t
;;		Each non-literal part is marked `syntax-type' ==> `pod'
;;		Each literal part is marked `syntax-type' ==> `in-pod'
;;	b) HEREs:
;;		Start-to-end is marked `here-doc-group' ==> t
;;		The body is marked `syntax-type' ==> `here-doc'
;;		The delimiter is marked `syntax-type' ==> `here-doc-delim'
;;	d) 'Q'uoted string:
;;		part between markers inclusive is marked `syntax-type' ==> `string'
;;		part between `q' and the first marker is marked `syntax-type' ==> `prestring'
;;		second part of s///e is marked `syntax-type' ==> `multiline'
;;	e) Attributes of subroutines: `attrib-group' ==> t
;;		(or 0 if declaration); up to `{' or ';': `syntax-type' => `sub-decl'.
;;      f) Multiline my/our declaration lists etc: `syntax-type' => `multiline'

;;; In addition, some parts of RExes may be marked as `REx-interpolated'
;;; (value: 0 in //o, 1 if "interpolated variable" is whole-REx, t otherwise).

(defun kurila-unwind-to-safe (before &optional end)
  ;; if BEFORE, go to the previous start-of-line on each step of unwinding
  (let ((pos (point)) opos)
    (while (and pos (progn
		      (beginning-of-line)
		      (get-text-property (setq pos (point)) 'syntax-type)))
      (setq opos pos
	    pos (kurila-beginning-of-property pos 'syntax-type))
      (if (eq pos (point-min))
	  (setq pos nil))
      (if pos
	  (if before
	      (progn
		(goto-char (kurila-1- pos))
		(beginning-of-line)
		(setq pos (point)))
	    (goto-char (setq pos (kurila-1- pos))))
	;; Up to the start
	(goto-char (point-min))))
    ;; Skip empty lines
    (and (looking-at "\n*=")
	 (/= 0 (skip-chars-backward "\n"))
	 (forward-char))
    (setq pos (point))
    (if end
	;; Do the same for end, going small steps
	(save-excursion
	  (while (and end (get-text-property end 'syntax-type))
	    (setq pos end
		  end (next-single-property-change end 'syntax-type nil (point-max)))
	    (if end (progn (goto-char end)
			   (or (bolp) (forward-line 1))
			   (setq end (point)))))
	  (or end pos)))))

;;; These are needed for byte-compile (at least with v19)
(defvar kurila-nonoverridable-face)
(defvar font-lock-variable-name-face)
(defvar font-lock-function-name-face)
(defvar font-lock-keyword-face)
(defvar font-lock-builtin-face)
(defvar font-lock-type-face)
(defvar font-lock-comment-face)
(defvar font-lock-warning-face)

(defun kurila-find-sub-attrs (&optional st-l b-fname e-fname pos)
  "Syntaxically mark (and fontify) attributes of a subroutine.
Should be called with the point before leading colon of an attribute."
  ;; Works *before* syntax recognition is done
  (or st-l (setq st-l (list nil)))	; Avoid overwriting '()
  (let (st b p reset-st after-first (start (point)) start1 end1)
    (condition-case b
	(while (looking-at
		(concat
		 "\\("			; 1=optional? colon
		   ":" kurila-maybe-white-and-comment-rex ; 2=whitespace/comment?
		 "\\)"
		 (if after-first "?" "")
		 ;; No space between name and paren allowed...
		 "\\(\\sw+\\)"		; 3=name
		 "\\((\\)?"))		; 4=optional paren
	  (and (match-beginning 1)
	       (kurila-postpone-fontification
		(match-beginning 0) (kurila-1+ (match-beginning 0))
		'face font-lock-constant-face))
	  (setq start1 (match-beginning 3) end1 (match-end 3))
	  (kurila-postpone-fontification start1 end1
					'face font-lock-constant-face)
	  (goto-char end1)		; end or before `('
	  (if (match-end 4)		; Have attribute arguments...
	      (progn
		(if st nil
		  (setq st (kurila-cached-syntax-table st-l))
		  (modify-syntax-entry ?\( "()" st)
		  (modify-syntax-entry ?\) ")(" st))
		(setq reset-st (syntax-table) p (point))
		(set-syntax-table st)
		(forward-sexp 1)
		(set-syntax-table reset-st)
		(setq reset-st nil)
		(kurila-commentify p (point) t))) ; mark as string
	  (forward-comment (buffer-size))
	  (setq after-first t))
      (error (message
	      "L%d: attribute `%s': %s"
	      (count-lines (point-min) (point))
	      (and start1 end1 (buffer-substring start1 end1)) b)
	     (setq start nil)))
    (and start
	 (progn
	   (put-text-property start (point)
			      'attrib-group (if (looking-at "{") t 0))
	   (and pos
		(< 1 (count-lines (+ 3 pos) (point))) ; end of `sub'
		;; Apparently, we do not need `multiline': faces added now
		(put-text-property (+ 3 pos) (kurila-1+ (point))
				   'syntax-type 'sub-decl))
	   (and b-fname			; Fontify here: the following condition
		(kurila-postpone-fontification ; is too hard to determine by
		 b-fname e-fname 'face ; a REx, so do it here
		(if (looking-at "{")
		    font-lock-function-name-face
		  font-lock-variable-name-face)))))
    ;; now restore the initial state
    (if st
	(progn
	  (modify-syntax-entry ?\( "." st)
	  (modify-syntax-entry ?\) "." st)))
    (if reset-st
	(set-syntax-table reset-st))))

(defsubst kurila-look-at-leading-count (is-x-REx e)
  (if (and
       (< (point) e)
       (re-search-forward (concat "\\=" (if is-x-REx "[ \t\n]*" "") "[{?+*]")
			  (1- e) t))	; return nil on failure, no moving
      (if (eq ?\{ (preceding-char)) nil
	(kurila-postpone-fontification
	 (1- (point)) (point)
	 'face font-lock-warning-face))))

;;; Debugging this may require (setq max-specpdl-size 2000)...
(defun kurila-find-pods-heres (&optional min max non-inter end ignore-max end-of-here-doc)
  "Scans the buffer for hard-to-parse Perl constructions.
If `kurila-pod-here-fontify' is not-nil after evaluation, will fontify
the sections using `kurila-pod-head-face', `kurila-pod-face',
`kurila-here-face'."
  (interactive)
 (or min (setq min (point-min)
		kurila-syntax-state nil
		kurila-syntax-done-to min))
  (or max (setq max (point-max)))
  (let* ((kurila-pod-here-fontify (eval kurila-pod-here-fontify)) go tmpend
	 face head-face here-face b e bb tag qtag b1 e1 argument i c tail tb
	 is-REx is-x-REx REx-subgr-start REx-subgr-end was-subgr i2 hairy-RE
	 (case-fold-search nil) (inhibit-read-only t) (buffer-undo-list t)
	 (modified (buffer-modified-p)) overshoot is-o-REx
	 (after-change-functions nil)
	 (kurila-font-locking t)
	 (use-syntax-state (and kurila-syntax-state
				(>= min (car kurila-syntax-state))))
	 (state-point (if use-syntax-state
			  (car kurila-syntax-state)
			(point-min)))
	 (state (if use-syntax-state
		    (cdr kurila-syntax-state)))
	 ;; (st-l '(nil)) (err-l '(nil)) ; Would overwrite - propagates from a function call to a function call!
	 (st-l (list nil)) (err-l (list nil))
	 ;; Somehow font-lock may be not loaded yet...
	 ;; (e.g., when building TAGS via command-line call)
	 (font-lock-string-face (if (boundp 'font-lock-string-face)
				    font-lock-string-face
				  'font-lock-string-face))
	 (my-kurila-delimiters-face (if (boundp 'font-lock-constant-face)
				      font-lock-constant-face
				    'font-lock-constant-face))
	 (my-kurila-REx-spec-char-face	; [] ^.$ and wrapper-of ({})
	  (if (boundp 'font-lock-function-name-face)
	      font-lock-function-name-face
	    'font-lock-function-name-face))
	 (font-lock-variable-name-face	; interpolated vars and ({})-code
	  (if (boundp 'font-lock-variable-name-face)
	      font-lock-variable-name-face
	    'font-lock-variable-name-face))
	 (font-lock-function-name-face	; used in `kurila-find-sub-attrs'
	  (if (boundp 'font-lock-function-name-face)
	      font-lock-function-name-face
	    'font-lock-function-name-face))
	 (font-lock-constant-face	; used in `kurila-find-sub-attrs'
	  (if (boundp 'font-lock-constant-face)
	      font-lock-constant-face
	    'font-lock-constant-face))
	 (my-kurila-REx-0length-face ; 0-length, (?:)etc, non-literal \
	  (if (boundp 'font-lock-builtin-face)
	      font-lock-builtin-face
	    'font-lock-builtin-face))
	 (font-lock-comment-face
	  (if (boundp 'font-lock-comment-face)
	      font-lock-comment-face
	    'font-lock-comment-face))
	 (font-lock-warning-face
	  (if (boundp 'font-lock-warning-face)
	      font-lock-warning-face
	    'font-lock-warning-face))
	 (my-kurila-REx-ctl-face		; (|)
	  (if (boundp 'font-lock-keyword-face)
	      font-lock-keyword-face
	    'font-lock-keyword-face))
	 (my-kurila-REx-modifiers-face	; //gims
	  (if (boundp 'kurila-nonoverridable-face)
	      kurila-nonoverridable-face
	    'kurila-nonoverridable-face))
	 (my-kurila-REx-length1-face	; length=1 escaped chars, POSIX classes
	  (if (boundp 'font-lock-type-face)
	      font-lock-type-face
	    'font-lock-type-face))
	 (stop-point (if ignore-max
			 (point-max)
		       max))
	 (search
	  (concat
	   "\\(\\`\n?\\|^\n\\)="	; POD
	   "\\|"
	   ;; One extra () before this:
	   "<<"				; HERE-DOC
	   "\\("			; 1 + 1
	   ;; First variant "BLAH" or just ``.
	   "[ \t]*"			; Yes, whitespace is allowed!
	   "\\([\"'`]\\)"		; 2 + 1 = 3
	   "\\([^\"'`\n]*\\)"		; 3 + 1
	   "\\3"
	   "\\|"
	   ;; Second variant: Identifier or \ID (same as 'ID') or empty
	   "\\\\?\\(\\([a-zA-Z_][a-zA-Z_0-9]*\\)?\\)" ; 4, 5
	   ;; Do not have <<= or << 30 or <<30 or << $blah.
	   ;; "\\([^= \t0-9$@%&]\\|[ \t]+[^ \t\n0-9$@%&]\\)" ; 6 + 1
	   "\\)"
	   (if kurila-use-syntax-table-text-property
	       (concat
		"\\|"
		"\\<\\(q[wxqr]?\\|[ms]\\)\\>" ; 7: QUOTED CONSTRUCT
		"\\|"
		"__\\(END\\|DATA\\)__"	; 8: __END__ or __DATA__
		"\\|"
		"\\\\\\(['`\"($]\\)")	; 9: BACKWACKED something-hairy
	     ""))))
    (unwind-protect
	(progn
	  (save-excursion
	    (or non-inter
		(message "Scanning for \"hard\" Perl constructions..."))
	    ;;(message "find: %s --> %s" min max)
	    (and kurila-pod-here-fontify
		 ;; We had evals here, do not know why...
		 (setq face kurila-pod-face
		       head-face kurila-pod-head-face
		       here-face kurila-here-face))
	    (remove-text-properties min max
				    '(syntax-type t in-pod t syntax-table t
						  attrib-group t
						  REx-interpolated t
						  kurila-postpone t
						  syntax-subtype t
						  rear-nonsticky t
						  front-sticky t
						  here-doc-group t
						  REx-part2 t
						  indentable t))
	    ;; Need to remove face as well...
	    (goto-char min)
	    (and (eq system-type 'emx)
		 (eq (point) 1)
		 (let ((case-fold-search t))
		   (looking-at "extproc[ \t]")) ; Analogue of #!
		 (kurila-commentify min
				   (save-excursion (end-of-line) (point))
				   nil))
	    (while (and
		    (< (point) max)
		    (re-search-forward search max t))
	      (setq tmpend nil)		; Valid for most cases
	      (setq b (match-beginning 0)
		    state (save-excursion (parse-partial-sexp
					   state-point b nil nil state))
		    state-point b)
	      (cond
	       ;; No processing in strings/comments beyond this point:
	       ((or (nth 3 state) (nth 4 state))
		t)			; Do nothing in comment/string
	       ((match-beginning 1)	; POD section
		;;  "\\(\\`\n?\\|^\n\\)="
		(setq b (match-beginning 0)
		      state (parse-partial-sexp
			     state-point b nil nil state)
		      state-point b)
		(if (or (nth 3 state) (nth 4 state)
			(looking-at "cut\\>"))
		    (if (or (nth 3 state) (nth 4 state) ignore-max)
			nil		; Doing a chunk only
		      (message "=cut is not preceded by a POD section")
		      (or (car err-l) (setcar err-l (point))))
		  (beginning-of-line)

		  (setq b (point)
			bb b
			tb (match-beginning 0)
			b1 nil)		; error condition
		  ;; We do not search to max, since we may be called from
		  ;; some hook of fontification, and max is random
		  (or (re-search-forward "^\n=cut\\>" stop-point 'toend)
		      (progn
			(goto-char b)
			(if (re-search-forward "\n=cut\\>" stop-point 'toend)
			    (progn
			      (message "=cut is not preceded by an empty line")
			      (setq b1 t)
			      (or (car err-l) (setcar err-l b))))))
		  (beginning-of-line 2)	; An empty line after =cut is not POD!
		  (setq e (point))
		  (and (> e max)
		       (progn
			 (remove-text-properties
			  max e '(syntax-type t in-pod t syntax-table t
					      attrib-group t
					      REx-interpolated t
					      kurila-postpone t
					      syntax-subtype t
					      here-doc-group t
					      rear-nonsticky t
					      front-sticky t
					      REx-part2 t
					      indentable t))
			 (setq tmpend tb)))
		  (put-text-property b e 'in-pod t)
		  (put-text-property b e 'syntax-type 'in-pod)
		  (goto-char b)
		  (while (re-search-forward "\n\n[ \t]" e t)
		    ;; We start 'pod 1 char earlier to include the preceding line
		    (beginning-of-line)
		    (put-text-property (kurila-1- b) (point) 'syntax-type 'pod)
		    (kurila-put-do-not-fontify b (point) t)
		    ;; mark the non-literal parts as PODs
		    (if kurila-pod-here-fontify
			(kurila-postpone-fontification b (point) 'face face t))
		    (re-search-forward "\n\n[^ \t\f\n]" e 'toend)
		    (beginning-of-line)
		    (setq b (point)))
		  (put-text-property (kurila-1- (point)) e 'syntax-type 'pod)
		  (kurila-put-do-not-fontify (point) e t)
		  (if kurila-pod-here-fontify
		      (progn
			;; mark the non-literal parts as PODs
			(kurila-postpone-fontification (point) e 'face face t)
			(goto-char bb)
			(if (looking-at
			     "=[a-zA-Z0-9_]+\\>[ \t]*\\(\\(\n?[^\n]\\)+\\)$")
			    ;; mark the headers
			    (kurila-postpone-fontification
			     (match-beginning 1) (match-end 1)
			     'face head-face))
			(while (re-search-forward
				;; One paragraph
				"^\n=[a-zA-Z0-9_]+\\>[ \t]*\\(\\(\n?[^\n]\\)+\\)$"
				e 'toend)
			  ;; mark the headers
			  (kurila-postpone-fontification
			   (match-beginning 1) (match-end 1)
			   'face head-face))))
		  (kurila-commentify bb e nil)
		  (goto-char e)
		  (or (eq e (point-max))
		      (forward-char -1)))) ; Prepare for immediate POD start.
	       ;; Here document
	       ;; We can do many here-per-line;
	       ;; but multiline quote on the same line as <<HERE confuses us...
               ;; ;; One extra () before this:
	       ;;"<<"
	       ;;  "\\("			; 1 + 1
	       ;;  ;; First variant "BLAH" or just ``.
	       ;;     "[ \t]*"			; Yes, whitespace is allowed!
	       ;;     "\\([\"'`]\\)"	; 2 + 1
	       ;;     "\\([^\"'`\n]*\\)"	; 3 + 1
	       ;;     "\\3"
	       ;;  "\\|"
	       ;;  ;; Second variant: Identifier or \ID or empty
	       ;;    "\\\\?\\(\\([a-zA-Z_][a-zA-Z_0-9]*\\)?\\)" ; 4 + 1, 5 + 1
	       ;;    ;; Do not have <<= or << 30 or <<30 or << $blah.
	       ;;    ;; "\\([^= \t0-9$@%&]\\|[ \t]+[^ \t\n0-9$@%&]\\)" ; 6 + 1
	       ;;    "\\(\\)"		; To preserve count of pars :-( 6 + 1
	       ;;  "\\)"
	       ((match-beginning 2)	; 1 + 1
		(setq b (point)
		      tb (match-beginning 0)
		      c (and		; not HERE-DOC
			 (match-beginning 5)
			 (save-match-data
			   (or (looking-at "[ \t]*(") ; << function_call()
			       (save-excursion ; 1 << func_name, or $foo << 10
				 (condition-case nil
				     (progn
				       (goto-char tb)
	       ;;; XXX What to do: foo <<bar ???
	       ;;; XXX Need to support print {a} <<B ???
				       (forward-sexp -1)
				       (save-match-data	
					; $foo << b; $f .= <<B;
					; ($f+1) << b; a($f) . <<B;
					; foo 1, <<B; $x{a} <<b;
					 (cond
					  ((looking-at "[0-9$({]")
					   (forward-sexp 1)
					   (and
					    (looking-at "[ \t]*<<")
					    (condition-case nil
						;; print $foo <<EOF
						(progn
						  (forward-sexp -2)
						  (not
						   (looking-at "\\(printf?\\|system\\|exec\\|sort\\)\\>")))
						(error t)))))))
				   (error nil))) ; func(<<EOF)
			       (and (not (match-beginning 6)) ; Empty
				    (looking-at
				     "[ \t]*[=0-9$@%&(]"))))))
		(if c			; Not here-doc
		    nil			; Skip it.
		  (setq c (match-end 2)) ; 1 + 1
		  (if (match-beginning 5) ;4 + 1
		      (setq b1 (match-beginning 5) ; 4 + 1
			    e1 (match-end 5)) ; 4 + 1
		    (setq b1 (match-beginning 4) ; 3 + 1
			  e1 (match-end 4))) ; 3 + 1
		  (setq tag (buffer-substring b1 e1)
			qtag (regexp-quote tag))
		  (cond (kurila-pod-here-fontify
			 ;; Highlight the starting delimiter
			 (kurila-postpone-fontification 
			  b1 e1 'face my-kurila-delimiters-face)
			 (kurila-put-do-not-fontify b1 e1 t)))
		  (forward-line)
		  (setq i (point))
		  (if end-of-here-doc
		      (goto-char end-of-here-doc))
		  (setq b (point))
		  ;; We do not search to max, since we may be called from
		  ;; some hook of fontification, and max is random
		  (or (and (re-search-forward (concat "^" qtag "$")
					      stop-point 'toend)
			   ;;;(eq (following-char) ?\n) ; XXXX WHY???
			   )
		    (progn		; Pretend we matched at the end
		      (goto-char (point-max))
		      (re-search-forward "\\'")
		      (message "End of here-document `%s' not found." tag)
		      (or (car err-l) (setcar err-l b))))
		  (if kurila-pod-here-fontify
		      (progn
			;; Highlight the ending delimiter
			(kurila-postpone-fontification
			 (match-beginning 0) (match-end 0)
			 'face my-kurila-delimiters-face)
			(kurila-put-do-not-fontify b (match-end 0) t)
			;; Highlight the HERE-DOC
			(kurila-postpone-fontification b (match-beginning 0)
						      'face here-face)))
		  (setq e1 (kurila-1+ (match-end 0)))
		  (put-text-property b (match-beginning 0)
				     'syntax-type 'here-doc)
		  (put-text-property (match-beginning 0) e1
				     'syntax-type 'here-doc-delim)
		  (put-text-property b e1 'here-doc-group t)
		  ;; This makes insertion at the start of HERE-DOC update
		  ;; the whole construct:
		  (put-text-property b (kurila-1+ b) 'front-sticky '(syntax-type))
		  (kurila-commentify b e1 nil)
		  (kurila-put-do-not-fontify b (match-end 0) t)
		  ;; Cache the syntax info...
		  (setq kurila-syntax-state (cons state-point state))
		  ;; ... and process the rest of the line...
		  (setq overshoot
			(elt		; non-inter ignore-max
			 (kurila-find-pods-heres c i t end t e1) 1))
		  (if (and overshoot (> overshoot (point)))
		      (goto-char overshoot)
		    (setq overshoot e1))
		  (if (> e1 max)
		      (setq tmpend tb))))
	       ;; 7: QUOTED CONSTRUCT
	       ((match-beginning 7)
		;; "\\<\\(q[wxqr]?\\|[ms]\\)\\>"
		(setq b1 7
		      argument (buffer-substring
				(match-beginning b1) (match-end b1))
		      b (point)		; end of qq etc
		      i b
		      c (char-after (match-beginning b1))
		      bb (char-after (1- (match-beginning b1))) ; tmp holder
		      ;; bb == "Not a stringy"
		      bb (and (memq bb (append "$@%*#_:-&>" nil)) ; $#y)
				  (cond ((eq bb ?-) (eq c ?s)) ; -s file test
					((eq bb ?\:) ; $opt::s
					 (eq (char-after
					      (- (match-beginning b1) 2))
					     ?\:))
					((eq bb ?\>) ; $foo->s
					 (eq (char-after
					      (- (match-beginning b1) 2))
					     ?\-))
					((eq bb ?\&)
					 (not (eq (char-after ; &&m/blah/
						   (- (match-beginning b1) 2))
						  ?\&)))
					(t t)))
		      tb (match-beginning 0))
		(goto-char (match-beginning b1))
		(kurila-backward-to-noncomment (point-min))
		(or bb
		    (progn
		      ;; s y tr m
		      ;; Check for $a -> y
		      (setq b1 (preceding-char)
			    go (point))
		      (if (and (eq b1 ?>)
			       (eq (char-after (- go 2)) ?-))
			  ;; Not a regexp
			  (setq bb t))))
		(or bb
		    (progn
		      (goto-char b)
		      (if (looking-at "[ \t\n\f]+\\(#[^\n]*\n[ \t\n\f]*\\)+")
			  (goto-char (match-end 0))
			(skip-chars-forward " \t\n\f"))
		      (cond ((and (eq (following-char) ?\})
				  (eq b1 ?\{))
			     ;; Check for $a[23]->{ s }, @{s} and *{s::foo}
			     (goto-char (1- go))
			     (skip-chars-backward " \t\n\f")
			     (if (memq (preceding-char) (append "$@%&*" nil))
				 (setq bb t) ; @{y}
			       (condition-case nil
				   (forward-sexp -1)
				 (error nil)))
			     (if (or bb
				     (looking-at ; $foo -> {s}
				      "[$@]\\$*\\([a-zA-Z0-9_:]+\\|[^{]\\)\\([ \t\n]*->\\)?[ \t\n]*{")
				     (and ; $foo[12] -> {s}
				      (memq (following-char) '(?\{ ?\[))
				      (progn
					(forward-sexp 1)
					(looking-at "\\([ \t\n]*->\\)?[ \t\n]*{"))))
				 (setq bb t)
			       (goto-char b)))
			    ((and (eq (following-char) ?=)
				  (eq (char-after (1+ (point))) ?\>))
			     ;; Check for { foo => 1, s => 2 }
			     ;; Apparently s=> is never a substitution...
			     (setq bb t))
			    ((and (eq (following-char) ?:)
				  (eq b1 ?\{) ; Check for $ { s::bar }
				  (looking-at "::[a-zA-Z0-9_:]*[ \t\n\f]*}")
				  (progn
				    (goto-char (1- go))
				    (skip-chars-backward " \t\n\f")
				    (memq (preceding-char)
					  (append "$@%&*" nil))))
			     (setq bb t))
			    ((eobp)
			     (setq bb t)))))
		(if bb
		    (goto-char i)
		  ;; Skip whitespace and comments...
		  (if (looking-at "[ \t\n\f]+\\(#[^\n]*\n[ \t\n\f]*\\)+")
		      (goto-char (match-end 0))
		    (skip-chars-forward " \t\n\f"))
		  (if (> (point) b)
		      (put-text-property b (point) 'syntax-type 'prestring))
		  ;; qtag means two-arg matcher, may be reset to
		  ;;   2 or 3 later if some special quoting is needed.
		  ;; e1 means matching-char matcher.
		  (setq b (point)	; before the first delimiter
			;; has 2 args
			i2 (string-match "^\\(s\\)$" argument)
			;; We do not search to max, since we may be called from
			;; some hook of fontification, and max is random
			i (kurila-forward-re stop-point end
					    i2
					    st-l err-l argument)
			;; If `go', then it is considered as 1-arg, `b1' is nil
			;; as in s/foo//x; the point is before final "slash"
			b1 (nth 1 i)	; start of the second part
			tag (nth 2 i)	; ender-char, true if second part
					; is with matching chars []
			go (nth 4 i)	; There is a 1-char part after the end
			i (car i)	; intermediate point
			e1 (point)	; end
			;; Before end of the second part if non-matching: ///
			tail (if (and i (not tag))
				 (1- e1))
			e (if i i e1)	; end of the first part
			qtag nil	; need to preserve backslashitis
			is-x-REx nil is-o-REx nil); REx has //x //o modifiers
		  ;; If s{} (), then b/b1 are at "{", "(", e1/i after ")", "}"
		  ;; Commenting \\ is dangerous, what about ( ?
		  (and i tail
		       (eq (char-after i) ?\\)
		       (setq qtag t))
		  (and (if go (looking-at ".\\sw*x")
			 (looking-at "\\sw*x")) ; qr//x
		       (setq is-x-REx t))
		  (and (if go (looking-at ".\\sw*o")
			 (looking-at "\\sw*o")) ; //o
		       (setq is-o-REx t))
		  (if (null i)
		      ;; Considered as 1arg form
		      (progn
			(kurila-commentify b (point) t)
			(put-text-property b (point) 'syntax-type 'string)
			(if (or is-x-REx
				;; ignore other text properties:
				(string-match "^qw$" argument))
			    (put-text-property b (point) 'indentable t))
			(and go
			     (setq e1 (kurila-1+ e1))
			     (or (eobp)
				 (forward-char 1))))
		    (kurila-commentify b i t)
                    (kurila-commentify b1 (point) t)
                    (put-text-property b (point) 'syntax-type 'string)
                    (if is-x-REx
                        (put-text-property b i 'indentable t))
                    (if qtag
                        (kurila-modify-syntax-type (1+ i) kurila-st-punct))
                    (setq tail nil))
		  (if (eq (char-syntax (following-char)) ?w)
		      (progn
			(forward-word 1) ; skip modifiers s///s
			(if tail (kurila-commentify tail (point) t))
			(kurila-postpone-fontification
			 e1 (point) 'face my-kurila-REx-modifiers-face)))
		  ;; Check whether it is m// which means "previous match"
		  ;; and highlight differently
		  (setq is-REx
			(and (string-match "^\\([sm]?\\|qr\\)$" argument)
			     (or (not (= (length argument) 0))
				 (not (eq c ?\<)))))
		  (if (and is-REx
			   (eq e (+ 2 b))
			   ;; split // *is* using zero-pattern
			   (save-excursion
			     (condition-case nil
				 (progn
				   (goto-char tb)
				   (forward-sexp -1)
				   (not (looking-at "split\\>")))
			       (error t))))
		      (kurila-postpone-fontification
		       b e 'face font-lock-warning-face)
		    (if (or i2		; Has 2 args
			    (and kurila-fontify-m-as-s
				 (or
				  (string-match "^\\(m\\|qr\\)$" argument)
				  (and (eq 0 (length argument))
				       (not (eq ?\< (char-after b)))))))
			(progn
			  (kurila-postpone-fontification
			   b (kurila-1+ b) 'face my-kurila-delimiters-face)
			  (kurila-postpone-fontification
			   (1- e) e 'face my-kurila-delimiters-face)))
		    (if (and is-REx kurila-regexp-scan)
			;; Process RExen: embedded comments, charclasses and ]
;;;/\3333\xFg\x{FFF}a\ppp\PPP\qqq\C\99f(?{  foo  })(??{  foo  })/;
;;;/a\.b[^a[:ff:]b]x$ab->$[|$,$ab->[cd]->[ef]|$ab[xy].|^${a,b}{c,d}/;
;;;/(?<=foo)(?<!bar)(x)(?:$ab|\$\/)$|\\\b\x888\776\[\:$/xxx;
;;;m?(\?\?{b,a})? + m/(??{aa})(?(?=xx)aa|bb)(?#aac)/;
;;;m$(^ab[c]\$)$ + m+(^ab[c]\$\+)+ + m](^ab[c\]$|.+)] + m)(^ab[c]$|.+\));
;;;m^a[\^b]c^ + m.a[^b]\.c.;
			(save-excursion
			  (goto-char (1+ b))
			  ;; First 
			  (kurila-look-at-leading-count is-x-REx e)
			  (setq hairy-RE
				(concat
				 (if is-x-REx
				     (if (eq (char-after b) ?\#)
					 "\\((\\?\\\\#\\)\\|\\(\\\\#\\)"
				       "\\((\\?#\\)\\|\\(#\\)")
				   ;; keep the same count: add a fake group
				   (if (eq (char-after b) ?\#)
				       "\\((\\?\\\\#\\)\\(\\)"
				     "\\((\\?#\\)\\(\\)"))
				 "\\|"
				    "\\(\\[\\)" ; 3=[
				 "\\|"
				    "\\(]\\)" ; 4=]
				 "\\|"
				 ;; XXXX Will not be able to use it in s)))
				 (if (eq (char-after b) ?\) )
				     "\\())))\\)" ; Will never match
				   (if (eq (char-after b) ?? )
				       ;;"\\((\\\\\\?\\(\\\\\\?\\)?{\\)"
				       "\\((\\\\\\?\\\\\\?{\\|()\\\\\\?{\\)"
				     "\\((\\?\\??{\\)")) ; 5= (??{ (?{
				 "\\|"	; 6= 0-length, 7: name, 8,9:code, 10:group
				    "\\(" ;; XXXX 1-char variables, exc. |()\s
				       "[$@]"
				       "\\("
				          "[_a-zA-Z:][_a-zA-Z0-9:]*"
				       "\\|"
				          "{[^{}]*}" ; only one-level allowed
				       "\\|"
				          "[^{(|) \t\r\n\f]"
				       "\\)"
				       "\\(" ;;8,9:code part of array/hash elt
				          "\\(" "->" "\\)?"
				          "\\[[^][]*\\]"
					  "\\|"
				          "{[^{}]*}"
				       "\\)*"
				    ;; XXXX: what if u is delim?
				    "\\|"
				       "[)^|$.*?+]"
				    "\\|"
				       "{[0-9]+}"
				    "\\|"
				       "{[0-9]+,[0-9]*}"
				    "\\|"
				       "\\\\[luLUEQbBAzZG]"
				    "\\|"
				       "(" ; Group opener
				       "\\(" ; 10 group opener follower
				          "\\?\\((\\?\\)" ; 11: in (?(?=C)A|B)
				       "\\|"
				          "\\?[:=!>?{]"	; "?" something
				       "\\|"
				          "\\?[-imsx]+[:)]" ; (?i) (?-s:.)
				       "\\|"
				          "\\?([0-9]+)"	; (?(1)foo|bar)
				       "\\|"
					  "\\?<[=!]"
				       ;;;"\\|"
				       ;;;   "\\?"
				       "\\)?"
				    "\\)"
				 "\\|"
				    "\\\\\\(.\\)" ; 12=\SYMBOL
				 ))
			  (while
			      (and (< (point) (1- e))
				   (re-search-forward hairy-RE (1- e) 'to-end))
			    (goto-char (match-beginning 0))
			    (setq REx-subgr-start (point)
				  was-subgr (following-char))
			    (cond
			     ((match-beginning 6) ; 0-length builtins, groups
			      (goto-char (match-end 0))
			      (if (match-beginning 11)
				  (goto-char (match-beginning 11)))
			      (if (>= (point) e)
				  (goto-char (1- e)))
			      (kurila-postpone-fontification
			       (match-beginning 0) (point)
			       'face
			       (cond
				((eq was-subgr ?\) )
				 (condition-case nil
				     (save-excursion
				       (forward-sexp -1)
				       (if (> (point) b)
					   (if (if (eq (char-after b) ?? )
						   (looking-at "(\\\\\\?")
						 (eq (char-after (1+ (point))) ?\?))
					       my-kurila-REx-0length-face
					     my-kurila-REx-ctl-face)
					 font-lock-warning-face))
				   (error font-lock-warning-face)))
				((eq was-subgr ?\| )
				 my-kurila-REx-ctl-face)
				((eq was-subgr ?\$ )
				 (if (> (point) (1+ REx-subgr-start))
				     (progn
				       (put-text-property
					(match-beginning 0) (point)
					'REx-interpolated
					(if is-o-REx 0
					    (if (and (eq (match-beginning 0)
							 (1+ b))
						     (eq (point)
							 (1- e))) 1 t)))
				       font-lock-variable-name-face)
				   my-kurila-REx-spec-char-face))
				((memq was-subgr (append "^." nil) )
				 my-kurila-REx-spec-char-face)
				((eq was-subgr ?\( )
				 (if (not (match-beginning 10))
				     my-kurila-REx-ctl-face
				   my-kurila-REx-0length-face))
				(t my-kurila-REx-0length-face)))
			      (if (and (memq was-subgr (append "(|" nil))
				       (not (string-match "(\\?[-imsx]+)"
							  (match-string 0))))
				  (kurila-look-at-leading-count is-x-REx e))
			      (setq was-subgr nil)) ; We do stuff here
			     ((match-beginning 12) ; \SYMBOL
			      (forward-char 2)
			      (if (>= (point) e)
				  (goto-char (1- e))
				;; How many chars to not highlight:
				;; 0-len special-alnums in other branch =>
				;; Generic:  \non-alnum (1), \alnum (1+face)
				;; Is-delim: \non-alnum (1/spec-2) alnum-1 (=what hai)
				(setq REx-subgr-start (point)
				      qtag (preceding-char))
				(kurila-postpone-fontification
				 (- (point) 2) (- (point) 1) 'face
				 (if (memq qtag
					   (append "ghijkmoqvFHIJKMORTVY" nil))
				     font-lock-warning-face
				   my-kurila-REx-0length-face))
				(if (and (eq (char-after b) qtag)
					 (memq qtag (append ".])^$|*?+" nil)))
				    (progn
				      (if (and kurila-use-syntax-table-text-property
					       (eq qtag ?\) ))
					  (put-text-property
					   REx-subgr-start (1- (point))
					   'syntax-table kurila-st-punct))
				      (kurila-postpone-fontification
				       (1- (point)) (point) 'face
					; \] can't appear below
				       (if (memq qtag (append ".]^$" nil))
					   'my-kurila-REx-spec-char-face
					 (if (memq qtag (append "*?+" nil))
					     'my-kurila-REx-0length-face
					   'my-kurila-REx-ctl-face))))) ; )|
				;; Test for arguments:
				(cond
				 ;; This is not pretty: the 5.8.7 logic:
				 ;; \0numx  -> octal (up to total 3 dig)
				 ;; \DIGIT  -> backref unless \0
				 ;; \DIGITs -> backref if legal
				 ;;	     otherwise up to 3 -> octal
				 ;; Do not try to distinguish, we guess
				 ((or (and (memq qtag (append "01234567" nil))
					   (re-search-forward
					    "\\=[01234567]?[01234567]?"
					    (1- e) 'to-end))
				      (and (memq qtag (append "89" nil))
					   (re-search-forward 
					    "\\=[0123456789]*" (1- e) 'to-end))
				      (and (eq qtag ?x)
					   (re-search-forward
					    "\\=[0-9a-fA-F][0-9a-fA-F]?\\|\\={[0-9a-fA-F]+}"
					    (1- e) 'to-end))
				      (and (memq qtag (append "pPN" nil))
					   (re-search-forward "\\={[^{}]+}\\|."
					    (1- e) 'to-end))
				      (eq (char-syntax qtag) ?w))
				  (kurila-postpone-fontification
				   (1- REx-subgr-start) (point)
				   'face my-kurila-REx-length1-face))))
			      (setq was-subgr nil)) ; We do stuff here
			     ((match-beginning 3) ; [charclass]
			      (forward-char 1)
			      (if (eq (char-after b) ?^ )
				  (and (eq (following-char) ?\\ )
				       (eq (char-after (kurila-1+ (point)))
					   ?^ )
				       (forward-char 2))
				(and (eq (following-char) ?^ )
				     (forward-char 1)))
			      (setq argument b ; continue?
				    tag nil ; list of POSIX classes
				    qtag (point))
			      (if (eq (char-after b) ?\] )
				  (and (eq (following-char) ?\\ )
				       (eq (char-after (kurila-1+ (point)))
					   ?\] )
				       (setq qtag (1+ qtag))
				       (forward-char 2))
				(and (eq (following-char) ?\] )
				     (forward-char 1)))
			      ;; Apparently, I can't put \] into a charclass
			      ;; in m]]: m][\\\]\]] produces [\\]]
;;; POSIX?  [:word:] [:^word:] only inside []
;;;				       "\\=\\(\\\\.\\|[^][\\\\]\\|\\[:\\^?\sw+:]\\|\\[[^:]\\)*]")
			      (while 
				  (and argument
				       (re-search-forward
					(if (eq (char-after b) ?\] )
					    "\\=\\(\\\\[^]]\\|[^]\\\\]\\)*\\\\]"
					  "\\=\\(\\\\.\\|[^]\\\\]\\)*]")
					(1- e) 'toend))
				;; Is this ] an end of POSIX class?
				(if (save-excursion
				      (and
				       (search-backward "[" argument t)
				       (< REx-subgr-start (point))
				       (not
					(and ; Should work with delim = \
					 (eq (preceding-char) ?\\ )
					 (= (% (skip-chars-backward
						"\\\\") 2) 0)))
				       (looking-at
					(cond
					 ((eq (char-after b) ?\] )
					  "\\\\*\\[:\\^?\\sw+:\\\\\\]")
					 ((eq (char-after b) ?\: )
					  "\\\\*\\[\\\\:\\^?\\sw+\\\\:]")
					 ((eq (char-after b) ?^ )
					  "\\\\*\\[:\\(\\\\\\^\\)?\\sw+:\]")
					 ((eq (char-syntax (char-after b))
					      ?w)
					  (concat
					   "\\\\*\\[:\\(\\\\\\^\\)?\\(\\\\"
					   (char-to-string (char-after b))
					   "\\|\\sw\\)+:\]"))
					 (t "\\\\*\\[:\\^?\\sw*:]")))
				       (setq argument (point))))
				    (setq tag (cons (cons argument (point))
						    tag)
					  argument (point)) ; continue
				  (setq argument nil)))
			      (and argument
				   (message "Couldn't find end of charclass in a REx, pos=%s"
					    REx-subgr-start))
			      (if (and kurila-use-syntax-table-text-property
				       (> (- (point) 2) REx-subgr-start))
				  (put-text-property
				   (1+ REx-subgr-start) (1- (point))
				   'syntax-table kurila-st-punct))
			      (kurila-postpone-fontification
			       REx-subgr-start qtag
			       'face my-kurila-REx-spec-char-face)
			      (kurila-postpone-fontification
			       (1- (point)) (point) 'face
			       my-kurila-REx-spec-char-face)
			      (if (eq (char-after b) ?\] )
				  (kurila-postpone-fontification
				   (- (point) 2) (1- (point))
				   'face my-kurila-REx-0length-face))
			      (while tag
				(kurila-postpone-fontification
				 (car (car tag)) (cdr (car tag))
				 'face my-kurila-REx-length1-face)
				(setq tag (cdr tag)))
			      (setq was-subgr nil)) ; did facing already
			     ;; Now rare stuff:
			     ((and (match-beginning 2) ; #-comment
				   (/= (match-beginning 2) (match-end 2)))
			      (beginning-of-line 2)
			      (if (> (point) e)
				  (goto-char (1- e))))
			     ((match-beginning 4) ; character "]"
			      (setq was-subgr nil) ; We do stuff here
			      (goto-char (match-end 0))
			      (if kurila-use-syntax-table-text-property
				  (put-text-property
				   (1- (point)) (point)
				   'syntax-table kurila-st-punct))
			      (kurila-postpone-fontification
			       (1- (point)) (point)
			       'face font-lock-warning-face))
			     ((match-beginning 5) ; before (?{}) (??{})
			      (setq tag (match-end 0))
			      (if (or (setq qtag
					    (kurila-forward-group-in-re st-l))
				      (and (>= (point) e)
					   (setq qtag "no matching `)' found"))
				      (and (not (eq (char-after (- (point) 2))
						    ?\} ))
					   (setq qtag "Can't find })")))
				  (progn
				    (goto-char (1- e))
				    (message qtag))
				(kurila-postpone-fontification
				 (1- tag) (1- (point))
				 'face font-lock-variable-name-face)
				(kurila-postpone-fontification
				 REx-subgr-start (1- tag)
				 'face my-kurila-REx-spec-char-face)
				(kurila-postpone-fontification
				 (1- (point)) (point)
				 'face my-kurila-REx-spec-char-face)
				(if kurila-use-syntax-table-text-property
				    (progn
				      (put-text-property
				       (- (point) 2) (1- (point))
				       'syntax-table kurila-st-cfence)
				      (put-text-property
				       (+ REx-subgr-start 2)
				       (+ REx-subgr-start 3)
				       'syntax-table kurila-st-cfence))))
			      (setq was-subgr nil))
			     (t		; (?#)-comment
			      ;; Inside "(" and "\" arn't special in any way
			      ;; Works also if the outside delimiters are ().
			      (or;;(if (eq (char-after b) ?\) )
			       ;;(re-search-forward
			       ;; "[^\\\\]\\(\\\\\\\\\\)*\\\\)"
			       ;; (1- e) 'toend)
			       (search-forward ")" (1- e) 'toend)
			       ;;)
			       (message
				"Couldn't find end of (?#...)-comment in a REx, pos=%s"
				REx-subgr-start))))
			    (if (>= (point) e)
				(goto-char (1- e)))
			    (cond
			     (was-subgr
			      (setq REx-subgr-end (point))
			      (kurila-commentify
			       REx-subgr-start REx-subgr-end nil)
			      (kurila-postpone-fontification
			       REx-subgr-start REx-subgr-end
			       'face font-lock-comment-face))))))
		    (if (and is-REx is-x-REx)
			(put-text-property (1+ b) (1- e)
					   'syntax-subtype 'x-REx)))
		  (if (and i2 e1 b1 (> e1 b1))
		      (progn		; No errors finding the second part...
			(kurila-postpone-fontification
			 (1- e1) e1 'face my-kurila-delimiters-face)
			(if (assoc (char-after b) kurila-starters)
			    (progn
			      (kurila-postpone-fontification
			       b1 (1+ b1) 'face my-kurila-delimiters-face)
			      (put-text-property b1 (1+ b1)
					   'REx-part2 t)))))
		  (if (> (point) max)
		      (setq tmpend tb))))
	       ;; 8: "__\\(END\\|DATA\\)__"
	       ((match-beginning 8)	; __END__, __DATA__
		(setq bb (match-end 0))
		;; (put-text-property b (1+ bb) 'syntax-type 'pod) ; Cheat
		(kurila-commentify b bb nil)
		(setq end t))
	       ;; 9: "\\\\\\(['`\"($]\\)"
	       ((match-beginning 9)
		;; Trailing backslash; make non-quoting outside string/comment
		(setq bb (match-end 0))
		(goto-char b)
		(skip-chars-backward "\\\\")
		;;;(setq i2 (= (% (skip-chars-backward "\\\\") 2) -1))
		(kurila-modify-syntax-type b kurila-st-punct)
		(goto-char bb))
	       (t (error "Error in regexp of the sniffer")))
	      (if (> (point) stop-point)
		  (progn
		    (if end
			(message "Garbage after __END__/__DATA__ ignored")
		      (message "Unbalanced syntax found while scanning")
		      (or (car err-l) (setcar err-l b)))
		    (goto-char stop-point))))
	    (setq kurila-syntax-state (cons state-point state)
		  ;; Do not mark syntax as done past tmpend???
		  kurila-syntax-done-to (or tmpend (max (point) max)))
	    ;;(message "state-at=%s, done-to=%s" state-point kurila-syntax-done-to)
	    )
	  (if (car err-l) (goto-char (car err-l))
	    (or non-inter
		(message "Scanning for \"hard\" Perl constructions... done"))))
      (and (buffer-modified-p)
	   (not modified)
	   (set-buffer-modified-p nil))
      (set-syntax-table kurila-mode-syntax-table))
    (list (car err-l) overshoot)))

(defun kurila-find-pods-heres-region (min max)
  (interactive "r")
  (kurila-find-pods-heres min max))

(defun kurila-backward-to-noncomment (lim)
  ;; Stops at lim or after non-whitespace that is not in comment
  ;; XXXX Wrongly understands end-of-multiline strings with # as comment
  (let (stop p pr)
    (while (and (not stop) (> (point) (or lim (point-min))))
      (skip-chars-backward " \t\n\f" lim)
      (setq p (point))
      (beginning-of-line)
      (if (memq (setq pr (get-text-property (point) 'syntax-type))
		'(pod here-doc here-doc-delim))
	  (progn
	    (kurila-unwind-to-safe nil)
	    (setq pr (get-text-property (point) 'syntax-type))))
      (or (and (looking-at "^[ \t]*\\(#\\|$\\)")
	       (not (memq pr '(string prestring))))
	  (progn (kurila-to-comment-or-eol) (bolp))
	  (progn
	    (skip-chars-backward " \t")
	    (if (< p (point)) (goto-char p))
	    (setq stop t))))))

;; Used only in `kurila-calculate-indent'...
(defun kurila-block-p ()		   ; Do not C-M-q !  One string contains ";" !
  ;; Positions is before ?\{.  Checks whether it starts a block.
  ;; No save-excursion!  This is more a distinguisher of a block/hash ref...
  (kurila-backward-to-noncomment (point-min))
  (or (memq (preceding-char) (append ";){}$@&%\C-@" nil)) ; Or label!  \C-@ at bobp
					; Label may be mixed up with `$blah :'
      (save-excursion (kurila-after-label))
      (get-text-property (kurila-1- (point)) 'attrib-group)
      (and (memq (char-syntax (preceding-char)) '(?w ?_))
	   (progn
	     (backward-sexp)
	     ;; sub {BLK}, print {BLK} $data, but NOT `bless', `return', `tr'
	     (or (and (looking-at "[a-zA-Z0-9_:]+[ \t\n\f]*[{#]") ; Method call syntax
		      (not (looking-at "\\(bless\\|return\\|q[wqrx]?\\|tr\\|[smy]\\)\\>")))
		 ;; sub bless::foo {}
		 (progn
		   (kurila-backward-to-noncomment (point-min))
		   (and (eq (preceding-char) ?b)
			(progn
			  (forward-sexp -1)
			  (looking-at "sub[ \t\n\f#]")))))))))

;;; What is the difference of (kurila-after-block-p lim t) and (kurila-block-p)?
;;; No save-excursion; condition-case ...  In (kurila-block-p) the block
;;; may be a part of an in-statement construct, such as
;;;   ${something()}, print {FH} $data.
;;; Moreover, one takes positive approach (looks for else,grep etc)
;;; another negative (looks for bless,tr etc)
(defun kurila-after-block-p (lim &optional pre-block)
  "Return true if the preceeding } (if PRE-BLOCK, following {) delimits a block.
Would not look before LIM.  Assumes that LIM is a good place to begin a
statement.  The kind of block we treat here is one after which a new
statement would start; thus the block in ${func()} does not count."
  (save-excursion
    (condition-case nil
	(progn
	  (or pre-block (forward-sexp -1))
	  (kurila-backward-to-noncomment lim)
	  (or (eq (point) lim)
	      ;; if () {}   // sub f () {}   // sub f :a(') {}
	      (eq (preceding-char) ?\) )
	      ;; label: {}
	      (save-excursion (kurila-after-label))
	      ;; sub :attr {}
	      (get-text-property (kurila-1- (point)) 'attrib-group)
	      (if (memq (char-syntax (preceding-char)) '(?w ?_)) ; else {}
		  (save-excursion
		    (forward-sexp -1)
		    ;; else {}     but not    else::func {}
		    (or (and (looking-at "\\(else\\|continue\\|grep\\|map\\|BEGIN\\|END\\|CHECK\\|INIT\\)\\>")
			     (not (looking-at "\\(\\sw\\|_\\)+::")))
			;; sub f {}
			(progn
			  (kurila-backward-to-noncomment lim)
			  (and (eq (preceding-char) ?b)
			       (progn
				 (forward-sexp -1)
				 (looking-at "sub[ \t\n\f#]"))))))
		;; What preceeds is not word...  XXXX Last statement in sub???
		(kurila-after-expr-p lim))))
      (error nil))))

(defun kurila-after-expr-p (&optional lim chars test)
  "Return true if the position is good for start of expression.
TEST is the expression to evaluate at the found position.  If absent,
CHARS is a string that contains good characters to have before us (however,
`}' is treated \"smartly\" if it is not in the list)."
  (let ((lim (or lim (point-min)))
	stop p pr)
    (kurila-update-syntaxification (point) (point))
    (save-excursion
      (while (and (not stop) (> (point) lim))
	(skip-chars-backward " \t\n\f" lim)
	(setq p (point))
	(beginning-of-line)
	;;(memq (setq pr (get-text-property (point) 'syntax-type))
	;;      '(pod here-doc here-doc-delim))
	(if (get-text-property (point) 'here-doc-group)
	    (progn
	      (goto-char
	       (kurila-beginning-of-property (point) 'here-doc-group))
	      (beginning-of-line 0)))
	(if (get-text-property (point) 'in-pod)
	    (progn
	      (goto-char
	       (kurila-beginning-of-property (point) 'in-pod))
	      (beginning-of-line 0)))
	(if (looking-at "^[ \t]*\\(#\\|$\\)") nil ; Only comment, skip
	  ;; Else: last iteration, or a label
	  (kurila-to-comment-or-eol)
	  (skip-chars-backward " \t")
	  (if (< p (point)) (goto-char p))
	  (setq p (point))
	  (if (and (eq (preceding-char) ?:)
		   (progn
		     (forward-char -1)
		     (skip-chars-backward " \t\n\f" lim)
		     (memq (char-syntax (preceding-char)) '(?w ?_))))
	      (forward-sexp -1)		; Possibly label.  Skip it
	    (goto-char p)
	    (setq stop t))))
      (or (bobp)			; ???? Needed
	  (eq (point) lim)
	  (looking-at "[ \t]*__\\(END\\|DATA\\)__") ; After this anything goes
	  (progn
	    (if test (eval test)
	      (or (memq (preceding-char) (append (or chars "{;") nil))
		  (and (eq (preceding-char) ?\})
		       (kurila-after-block-p lim)))))))))

(defun kurila-backward-to-start-of-expr (&optional lim)
  (condition-case nil
      (progn
	(while (and (or (not lim)
			(> (point) lim))
		    (not (kurila-after-expr-p lim)))
	  (forward-sexp -1)
	  ;; May be after $, @, $# etc of a variable
	  (skip-chars-backward "$@%#")))
    (error nil)))

(defun kurila-at-end-of-expr (&optional lim)
  ;; Since the SEXP approach below is very fragile, do some overengineering
  (or (looking-at (concat kurila-maybe-white-and-comment-rex "[;}]"))
      (condition-case nil
	  (save-excursion
	    ;; If nothing interesting after, does as (forward-sexp -1);
	    ;; otherwise fails, or ends at a start of following sexp.
	    ;; XXXX PROBLEMS: if what follows (after ";") @FOO, or ${bar}
	    ;; may be stuck after @ or $; just put some stupid workaround now:
	    (let ((p (point)))
	      (forward-sexp 1)
	      (forward-sexp -1)
	      (while (memq (preceding-char) (append "%&@$*" nil))
		(forward-char -1))
	      (or (< (point) p)
		  (kurila-after-expr-p lim))))
	(error t))))

(defun kurila-forward-to-end-of-expr (&optional lim)
  (let ((p (point))))
  (condition-case nil
      (progn
	(while (and (< (point) (or lim (point-max)))
		    (not (kurila-at-end-of-expr)))
	  (forward-sexp 1)))
    (error nil)))

(defun kurila-backward-to-start-of-continued-exp (lim)
  (if (memq (preceding-char) (append ")]}\"'`" nil))
      (forward-sexp -1))
  (beginning-of-line)
  (if (<= (point) lim)
      (goto-char (1+ lim)))
  (skip-chars-forward " \t"))

(defun kurila-after-block-and-statement-beg (lim)
  ;; We assume that we are after ?\}
  (and
   (kurila-after-block-p lim)
   (save-excursion
     (forward-sexp -1)
     (kurila-backward-to-noncomment (point-min))
     (or (bobp)
	 (eq (point) lim)
	 (not (= (char-syntax (preceding-char)) ?w))
	 (progn
	   (forward-sexp -1)
	   (not
	    (looking-at
	     "\\(map\\|grep\\|printf?\\|system\\|exec\\|tr\\|s\\)\\>")))))))


(defvar innerloop-done nil)
(defvar last-depth nil)

(defun kurila-indent-exp ()
  "Simple variant of indentation of continued-sexp.

Will not indent comment if it starts at `comment-indent' or looks like
continuation of the comment on the previous line.

If `kurila-indent-region-fix-constructs', will improve spacing on
conditional/loop constructs."
  (interactive)
  (save-excursion
    (let ((tmp-end (progn (end-of-line) (point))) top done)
      (save-excursion
	(beginning-of-line)
	(while (null done)
	  (setq top (point))
	  ;; Plan A: if line has an unfinished paren-group, go to end-of-group
	  (while (= -1 (nth 0 (parse-partial-sexp (point) tmp-end -1)))
	    (setq top (point)))		; Get the outermost parenths in line
	  (goto-char top)
	  (while (< (point) tmp-end)
	    (parse-partial-sexp (point) tmp-end nil t) ; To start-sexp or eol
	    (or (eolp) (forward-sexp 1)))
	  (if (> (point) tmp-end)	; Yes, there an unfinished block
	      nil
	    (if (eq ?\) (preceding-char))
		(progn ;; Plan B: find by REGEXP block followup this line
		  (setq top (point))
		  (condition-case nil
		      (progn
			(forward-sexp -2)
			(if (eq (following-char) ?$ ) ; for my $var (list)
			    (progn
			      (forward-sexp -1)
			      (if (looking-at "\\(my\\|local\\|our\\)\\>")
				  (forward-sexp -1))))
			(if (looking-at
			     (concat "\\(\\elsif\\|if\\|unless\\|while\\|until"
				     "\\|for\\(each\\)?\\>\\(\\("
				     kurila-maybe-white-and-comment-rex
				     "\\(my\\|local\\|our\\)\\)?"
				     kurila-maybe-white-and-comment-rex
				     "\\$[_a-zA-Z0-9]+\\)?\\)\\>"))
			    (progn
			      (goto-char top)
			      (forward-sexp 1)
			      (setq top (point)))))
		    (error (setq done t)))
		  (goto-char top))
	      (if (looking-at		; Try Plan C: continuation block
		   (concat kurila-maybe-white-and-comment-rex
			   "\\<\\(else\\|elsif\|continue\\)\\>"))
		  (progn
		    (goto-char (match-end 0))
		    (save-excursion
		      (end-of-line)
		      (setq tmp-end (point))))
		(setq done t))))
	  (save-excursion
	    (end-of-line)
	    (setq tmp-end (point))))
	(goto-char tmp-end)
	(setq tmp-end (point-marker)))
      (if kurila-indent-region-fix-constructs
	  (kurila-fix-line-spacing tmp-end))
      (kurila-indent-region (point) tmp-end))))

(defun kurila-fix-line-spacing (&optional end parse-data)
  "Improve whitespace in a conditional/loop construct.
Returns some position at the last line."
  (interactive)
  (or end
      (setq end (point-max)))
  (let ((ee (save-excursion (end-of-line) (point)))
	(kurila-indent-region-fix-constructs
	 (or kurila-indent-region-fix-constructs 1))
	p pp ml have-brace ret)
    (save-excursion
      (beginning-of-line)
      (setq ret (point))
      ;;  }? continue
      ;;  blah; }
      (if (not
	   (or (looking-at "[ \t]*\\(els\\(e\\|if\\)\\|continue\\|if\\|while\\|for\\(each\\)?\\|until\\)")
	       (setq have-brace (save-excursion (search-forward "}" ee t)))))
	  nil				; Do not need to do anything
	;; Looking at:
	;; }
	;; else
	(if kurila-merge-trailing-else
	    (if (looking-at
		 "[ \t]*}[ \t]*\n[ \t\n]*\\(els\\(e\\|if\\)\\|continue\\)\\>")
		(progn
		  (search-forward "}")
		  (setq p (point))
		  (skip-chars-forward " \t\n")
		  (delete-region p (point))
		  (insert (make-string kurila-indent-region-fix-constructs ?\ ))
		  (beginning-of-line)))
	  (if (looking-at "[ \t]*}[ \t]*\\(els\\(e\\|if\\)\\|continue\\)\\>")
	      (save-excursion
		  (search-forward "}")
		  (delete-horizontal-space)
		  (insert "\n")
		  (setq ret (point))
		  (if (kurila-indent-line parse-data)
		      (progn
			(kurila-fix-line-spacing end parse-data)
			(setq ret (point)))))))
	;; Looking at:
	;; }     else
	(if (looking-at "[ \t]*}\\(\t*\\|[ \t][ \t]+\\)\\<\\(els\\(e\\|if\\)\\|continue\\)\\>")
	    (progn
	      (search-forward "}")
	      (delete-horizontal-space)
	      (insert (make-string kurila-indent-region-fix-constructs ?\ ))
	      (beginning-of-line)))
	;; Looking at:
	;; else   {
	(if (looking-at
	     "[ \t]*}?[ \t]*\\<\\(\\els\\(e\\|if\\)\\|continue\\|unless\\|if\\|while\\|for\\(each\\)?\\|until\\)\\>\\(\t*\\|[ \t][ \t]+\\)[^ \t\n#]")
	    (progn
	      (forward-word 1)
	      (delete-horizontal-space)
	      (insert (make-string kurila-indent-region-fix-constructs ?\ ))
	      (beginning-of-line)))
	;; Looking at:
	;; foreach my    $var
	(if (looking-at
	     "[ \t]*\\<for\\(each\\)?[ \t]+\\(my\\|local\\|our\\)\\(\t*\\|[ \t][ \t]+\\)[^ \t\n]")
	    (progn
	      (forward-word 2)
	      (delete-horizontal-space)
	      (insert (make-string kurila-indent-region-fix-constructs ?\ ))
	      (beginning-of-line)))
	;; Looking at:
	;; foreach my $var     (
	(if (looking-at
	     "[ \t]*\\<for\\(each\\)?[ \t]+\\(my\\|local\\|our\\)[ \t]*\\$[_a-zA-Z0-9]+\\(\t*\\|[ \t][ \t]+\\)[^ \t\n#]")
	    (progn
	      (forward-sexp 3)
	      (delete-horizontal-space)
	      (insert
	       (make-string kurila-indent-region-fix-constructs ?\ ))
	      (beginning-of-line)))
	;; Looking at (with or without "}" at start, ending after "({"):
	;; } foreach my $var ()         OR   {
	(if (looking-at
	     "[ \t]*\\(}[ \t]*\\)?\\<\\(\\els\\(e\\|if\\)\\|continue\\|if\\|unless\\|while\\|for\\(each\\)?\\(\\([ \t]+\\(my\\|local\\|our\\)\\)?[ \t]*\\$[_a-zA-Z0-9]+\\)?\\|until\\)\\>\\([ \t]*(\\|[ \t\n]*{\\)\\|[ \t]*{")
	    (progn
	      (setq ml (match-beginning 8)) ; "(" or "{" after control word
	      (re-search-forward "[({]")
	      (forward-char -1)
	      (setq p (point))
	      (if (eq (following-char) ?\( )
		  (progn
		    (forward-sexp 1)
		    (setq pp (point)))	; past parenth-group
		;; after `else' or nothing
		(if ml			; after `else'
		    (skip-chars-backward " \t\n")
		  (beginning-of-line))
		(setq pp nil))
	      ;; Now after the sexp before the brace
	      ;; Multiline expr should be special
	      (setq ml (and pp (save-excursion (goto-char p)
					       (search-forward "\n" pp t))))
	      (if (and (or (not pp) (< pp end))	; Do not go too far...
		       (looking-at "[ \t\n]*{"))
		  (progn
		    (cond
		     ((bolp)		; Were before `{', no if/else/etc
		      nil)
		     ((looking-at "\\(\t*\\| [ \t]+\\){") ; Not exactly 1 SPACE
		      (delete-horizontal-space)
		      (if (if ml
			      kurila-extra-newline-before-brace-multiline
			    kurila-extra-newline-before-brace)
			  (progn
			    (delete-horizontal-space)
			    (insert "\n")
			    (setq ret (point))
			    (if (kurila-indent-line parse-data)
				(progn
				  (kurila-fix-line-spacing end parse-data)
				  (setq ret (point)))))
			(insert
			 (make-string kurila-indent-region-fix-constructs ?\ ))))
		     ((and (looking-at "[ \t]*\n")
			   (not (if ml
				    kurila-extra-newline-before-brace-multiline
				  kurila-extra-newline-before-brace)))
		      (setq pp (point))
		      (skip-chars-forward " \t\n")
		      (delete-region pp (point))
		      (insert
		       (make-string kurila-indent-region-fix-constructs ?\ )))
		     ((and (looking-at "[\t ]*{")
			   (if ml kurila-extra-newline-before-brace-multiline
			     kurila-extra-newline-before-brace))
		      (delete-horizontal-space)
		      (insert "\n")
		      (setq ret (point))
		      (if (kurila-indent-line parse-data)
			  (progn
			    (kurila-fix-line-spacing end parse-data)
			    (setq ret (point))))))
		    ;; Now we are before `{'
		    (if (looking-at "[ \t\n]*{[ \t]*[^ \t\n#]")
			(progn
			  (skip-chars-forward " \t\n")
			  (setq pp (point))
			  (forward-sexp 1)
			  (setq p (point))
			  (goto-char pp)
			  (setq ml (search-forward "\n" p t))
			  (if (or kurila-break-one-line-blocks-when-indent ml)
			      ;; not good: multi-line BLOCK
			      (progn
				(goto-char (1+ pp))
				(delete-horizontal-space)
				(insert "\n")
				(setq ret (point))
				(if (kurila-indent-line parse-data)
				    (setq ret (kurila-fix-line-spacing end parse-data)))))))))))
	(beginning-of-line)
	(setq p (point) pp (save-excursion (end-of-line) (point))) ; May be different from ee.
	;; Now check whether there is a hanging `}'
	;; Looking at:
	;; } blah
	(if (and
	     kurila-fix-hanging-brace-when-indent
	     have-brace
	     (not (looking-at "[ \t]*}[ \t]*\\(\\<\\(els\\(if\\|e\\)\\|continue\\|while\\|until\\)\\>\\|$\\|#\\)"))
	     (condition-case nil
		 (progn
		   (up-list 1)
		   (if (and (<= (point) pp)
			    (eq (preceding-char) ?\} )
			    (kurila-after-block-and-statement-beg (point-min)))
		       t
		     (goto-char p)
		     nil))
	       (error nil)))
	    (progn
	      (forward-char -1)
	      (skip-chars-backward " \t")
	      (if (bolp)
		  ;; `}' was the first thing on the line, insert NL *after* it.
		  (progn
		    (kurila-indent-line parse-data)
		    (search-forward "}")
		    (delete-horizontal-space)
		    (insert "\n"))
		(delete-horizontal-space)
		(or (eq (preceding-char) ?\;)
		    (bolp)
		    (and (eq (preceding-char) ?\} )
			 (kurila-after-block-p (point-min)))
		    (insert ";"))
		(insert "\n")
		(setq ret (point)))
	      (if (kurila-indent-line parse-data)
		  (setq ret (kurila-fix-line-spacing end parse-data)))
	      (beginning-of-line)))))
    ret))

(defvar kurila-update-start)		; Do not need to make them local
(defvar kurila-update-end)
(defun kurila-delay-update-hook (beg end old-len)
  (setq kurila-update-start (min beg (or kurila-update-start (point-max))))
  (setq kurila-update-end (max end (or kurila-update-end (point-min)))))

(defun kurila-indent-region (start end)
  "Simple variant of indentation of region in Kurila mode.
Should be slow.  Will not indent comment if it starts at `comment-indent'
or looks like continuation of the comment on the previous line.
Indents all the lines whose first character is between START and END
inclusive.

If `kurila-indent-region-fix-constructs', will improve spacing on
conditional/loop constructs."
  (interactive "r")
  (kurila-update-syntaxification end end)
  (save-excursion
    (let (kurila-update-start kurila-update-end (h-a-c after-change-functions))
      (let ((indent-info (if kurila-emacs-can-parse
			     (list nil nil nil)	; Cannot use '(), since will modify
			   nil))
	    (pm 0) (imenu-scanning-message "Indenting... (%3d%%)")
	    after-change-functions	; Speed it up!
	    st comm old-comm-indent new-comm-indent p pp i empty)
	(if h-a-c (add-hook 'after-change-functions 'kurila-delay-update-hook))
	(goto-char start)
	(setq old-comm-indent (and (kurila-to-comment-or-eol)
				   (current-column))
	      new-comm-indent old-comm-indent)
	(goto-char start)
	(setq end (set-marker (make-marker) end)) ; indentation changes pos
	(or (bolp) (beginning-of-line 2))
	(or (fboundp 'imenu-progress-message)
	    (message "Indenting... For feedback load `imenu'..."))
	(while (and (<= (point) end) (not (eobp))) ; bol to check start
	  (and (fboundp 'imenu-progress-message)
	       (imenu-progress-message
		pm (/ (* 100 (- (point) start)) (- end start -1))))
	  (setq st (point))
	  (if (or
	       (setq empty (looking-at "[ \t]*\n"))
	       (and (setq comm (looking-at "[ \t]*#"))
		    (or (eq (current-indentation) (or old-comm-indent
						      comment-column))
			(setq old-comm-indent nil))))
	      (if (and old-comm-indent
		       (not empty)
		       (= (current-indentation) old-comm-indent)
		       (not (eq (get-text-property (point) 'syntax-type) 'pod))
		       (not (eq (get-text-property (point) 'syntax-table)
				kurila-st-cfence)))
		  (let ((comment-column new-comm-indent))
		    (indent-for-comment)))
	    (progn
	      (setq i (kurila-indent-line indent-info))
	      (or comm
		  (not i)
		  (progn
		    (if kurila-indent-region-fix-constructs
			(goto-char (kurila-fix-line-spacing end indent-info)))
		    (if (setq old-comm-indent
			      (and (kurila-to-comment-or-eol)
				   (not (memq (get-text-property (point)
								 'syntax-type)
					      '(pod here-doc)))
				   (not (eq (get-text-property (point)
							       'syntax-table)
					    kurila-st-cfence))
				   (current-column)))
			(progn (indent-for-comment)
			       (skip-chars-backward " \t")
			       (skip-chars-backward "#")
			       (setq new-comm-indent (current-column))))))))
	  (beginning-of-line 2))
      	(if (fboundp 'imenu-progress-message)
	    (imenu-progress-message pm 100)
	  (message nil)))
      ;; Now run the update hooks
      (and after-change-functions
	   kurila-update-end
	   (save-excursion
	     (goto-char kurila-update-end)
	     (insert " ")
	     (delete-char -1)
	     (goto-char kurila-update-start)
	     (insert " ")
	     (delete-char -1))))))

;; Stolen from lisp-mode with a lot of improvements

(defun kurila-fill-paragraph (&optional justify iteration)
  "Like \\[fill-paragraph], but handle Kurila comments.
If any of the current line is a comment, fill the comment or the
block of it that point is in, preserving the comment's initial
indentation and initial hashes.  Behaves usually outside of comment."
  (interactive "P")
  (let (;; Non-nil if the current line contains a comment.
	has-comment
	fill-paragraph-function		; do not recurse
	;; If has-comment, the appropriate fill-prefix for the comment.
	comment-fill-prefix
	;; Line that contains code and comment (or nil)
	start
	c spaces len dc (comment-column comment-column))
    ;; Figure out what kind of comment we are looking at.
    (save-excursion
      (beginning-of-line)
      (cond

       ;; A line with nothing but a comment on it?
       ((looking-at "[ \t]*#[# \t]*")
	(setq has-comment t
	      comment-fill-prefix (buffer-substring (match-beginning 0)
						    (match-end 0))))

       ;; A line with some code, followed by a comment?  Remember that the
       ;; semi which starts the comment shouldn't be part of a string or
       ;; character.
       ((kurila-to-comment-or-eol)
	(setq has-comment t)
	(looking-at "#+[ \t]*")
	(setq start (point) c (current-column)
	      comment-fill-prefix
	      (concat (make-string (current-column) ?\ )
		      (buffer-substring (match-beginning 0) (match-end 0)))
	      spaces (progn (skip-chars-backward " \t")
			    (buffer-substring (point) start))
	      dc (- c (current-column)) len (- start (point))
	      start (point-marker))
	(delete-char len)
	(insert (make-string dc ?-)))))	; Placeholder (to avoid splitting???)
    (if (not has-comment)
	(fill-paragraph justify)       ; Do the usual thing outside of comment
      ;; Narrow to include only the comment, and then fill the region.
      (save-restriction
	(narrow-to-region
	 ;; Find the first line we should include in the region to fill.
	 (if start (progn (beginning-of-line) (point))
	   (save-excursion
	     (while (and (zerop (forward-line -1))
			 (looking-at "^[ \t]*#+[ \t]*[^ \t\n#]")))
	     ;; We may have gone to far.  Go forward again.
	     (or (looking-at "^[ \t]*#+[ \t]*[^ \t\n#]")
		 (forward-line 1))
	     (point)))
	 ;; Find the beginning of the first line past the region to fill.
	 (save-excursion
	   (while (progn (forward-line 1)
			 (looking-at "^[ \t]*#+[ \t]*[^ \t\n#]")))
	   (point)))
	;; Remove existing hashes
	(goto-char (point-min))
	(while (progn (forward-line 1) (< (point) (point-max)))
	  (skip-chars-forward " \t")
	  (if (looking-at "#+")
	      (progn
		(if (and (eq (point) (match-beginning 0))
			 (not (eq (point) (match-end 0)))) nil
		    (error
 "Bug in Emacs: `looking-at' in `narrow-to-region': match-data is garbage"))
		(delete-char (- (match-end 0) (match-beginning 0))))))

	;; Lines with only hashes on them can be paragraph boundaries.
	(let ((paragraph-start (concat paragraph-start "\\|^[ \t#]*$"))
	      (paragraph-separate (concat paragraph-start "\\|^[ \t#]*$"))
	      (fill-prefix comment-fill-prefix))
	  (fill-paragraph justify)))
      (if (and start)
	  (progn
	    (goto-char start)
	    (if (> dc 0)
		(progn (delete-char dc) (insert spaces)))
	    (if (or (= (current-column) c) iteration) nil
	      (setq comment-column c)
	      (indent-for-comment)
	      ;; Repeat once more, flagging as iteration
	      (kurila-fill-paragraph justify t))))))
  t)

(defun kurila-do-auto-fill ()
  ;; Break out if the line is short enough
  (if (> (save-excursion
	   (end-of-line)
	   (current-column))
	 fill-column)
      (let ((c (save-excursion (beginning-of-line)
			       (kurila-to-comment-or-eol) (point)))
	    (s (memq (following-char) '(?\ ?\t))) marker)
	(if (>= c (point)) nil
	  (setq marker (point-marker))
	  (kurila-fill-paragraph)
	  (goto-char marker)
	  ;; Is not enough, sometimes marker is a start of line
	  (if (bolp) (progn (re-search-forward "#+[ \t]*")
			    (goto-char (match-end 0))))
	  ;; Following space could have gone:
	  (if (or (not s) (memq (following-char) '(?\ ?\t))) nil
	    (insert " ")
	    (backward-char 1))
	  ;; Previous space could have gone:
	  (or (memq (preceding-char) '(?\ ?\t)) (insert " "))))))

(defun kurila-imenu-addback (lst &optional isback name)
  ;; We suppose that the lst is a DAG, unless the first element only
  ;; loops back, and ISBACK is set.  Thus this function cannot be
  ;; applied twice without ISBACK set.
  (cond ((not kurila-imenu-addback) lst)
	(t
	 (or name
	     (setq name "+++BACK+++"))
	 (mapcar (lambda (elt)
		   (if (and (listp elt) (listp (cdr elt)))
		       (progn
			 ;; In the other order it goes up
			 ;; one level only ;-(
			 (setcdr elt (cons (cons name lst)
					   (cdr elt)))
			 (kurila-imenu-addback (cdr elt) t name))))
		 (if isback (cdr lst) lst))
	 lst)))

(defun kurila-imenu--create-perl-index (&optional regexp)
  (require 'cl)
  (require 'imenu)			; May be called from TAGS creator
  (let ((index-alist '()) (index-pack-alist '()) (index-pod-alist '())
	(index-unsorted-alist '()) (i-s-f (default-value 'imenu-sort-function))
	(index-meth-alist '()) meth
	packages ends-ranges p marker is-proto
	(prev-pos 0) is-pack index index1 name (end-range 0) package)
    (goto-char (point-min))
    (if noninteractive
	(message "Scanning Perl for index")
      (imenu-progress-message prev-pos 0))
    (kurila-update-syntaxification (point-max) (point-max))
    ;; Search for the function
    (progn ;;save-match-data
      (while (re-search-forward
	      (or regexp kurila-imenu--function-name-regexp-perl)
	      nil t)
	(or noninteractive
	    (imenu-progress-message prev-pos))
	;; 2=package-group, 5=package-name 8=sub-name
	(cond
	 ((and				; Skip some noise if building tags
	   (match-beginning 5)		; package name
	   ;;(eq (char-after (match-beginning 2)) ?p) ; package
	   (not (save-match-data
		  (looking-at "[ \t\n]*;")))) ; Plain text word 'package'
	  nil)
	 ((and
	   (or (match-beginning 2)
	       (match-beginning 8))		; package or sub
	   ;; Skip if quoted (will not skip multi-line ''-strings :-():
	   (null (get-text-property (match-beginning 1) 'syntax-table))
	   (null (get-text-property (match-beginning 1) 'syntax-type))
	   (null (get-text-property (match-beginning 1) 'in-pod)))
	  (setq is-pack (match-beginning 2))
	  ;; (if (looking-at "([^()]*)[ \t\n\f]*")
	  ;;    (goto-char (match-end 0)))	; Messes what follows
	  (setq meth nil
		p (point))
	  (while (and ends-ranges (>= p (car ends-ranges)))
	    ;; delete obsolete entries
	    (setq ends-ranges (cdr ends-ranges) packages (cdr packages)))
	  (setq package (or (car packages) "")
		end-range (or (car ends-ranges) 0))
	  (if is-pack			; doing "package"
	      (progn
		(if (match-beginning 5)	; named package
		    (setq name (buffer-substring (match-beginning 5)
						 (match-end 5))
			  name (progn
				 (set-text-properties 0 (length name) nil name)
				 name)
			  package (concat name "::")
			  name (concat "package " name))
		  ;; Support nameless packages
		  (setq name "package;" package ""))
		(setq end-range
		      (save-excursion
			(parse-partial-sexp (point) (point-max) -1) (point))
		      ends-ranges (cons end-range ends-ranges)
		      packages (cons package packages)))
	    (setq is-proto
		  (or (eq (following-char) ?\;)
		      (eq 0 (get-text-property (point) 'attrib-group)))))
	  ;; Skip this function name if it is a prototype declaration.
	  (if (and is-proto (not is-pack)) nil
	    (or is-pack
		(setq name
		      (buffer-substring (match-beginning 8) (match-end 8)))
		(set-text-properties 0 (length name) nil name))
	    (setq marker (make-marker))
	    (set-marker marker (match-end (if is-pack 2 8)))
	    (cond (is-pack nil)
		  ((string-match "[:']" name)
		   (setq meth t))
		  ((> p end-range) nil)
		  (t
		   (setq name (concat package name) meth t)))
	    (setq index (cons name marker))
	    (if is-pack
		(push index index-pack-alist)
	      (push index index-alist))
	    (if meth (push index index-meth-alist))
	    (push index index-unsorted-alist)))
	 ((match-beginning 16)		; POD section
	  (setq name (buffer-substring (match-beginning 17) (match-end 17))
		marker (make-marker))
	  (set-marker marker (match-beginning 17))
	  (set-text-properties 0 (length name) nil name)
	  (setq name (concat (make-string
			      (* 3 (- (char-after (match-beginning 16)) ?1))
			      ?\ )
			     name)
		index (cons name marker))
	  (setq index1 (cons (concat "=" name) (cdr index)))
	  (push index index-pod-alist)
	  (push index1 index-unsorted-alist)))))
    (or noninteractive
	(imenu-progress-message prev-pos 100))
    (setq index-alist
	  (if (default-value 'imenu-sort-function)
	      (sort index-alist (default-value 'imenu-sort-function))
	    (nreverse index-alist)))
    (and index-pod-alist
	 (push (cons "+POD headers+..."
		     (nreverse index-pod-alist))
	       index-alist))
    (and (or index-pack-alist index-meth-alist)
	 (let ((lst index-pack-alist) hier-list pack elt group name)
	   ;; Remove "package ", reverse and uniquify.
	   (while lst
	     (setq elt (car lst) lst (cdr lst) name (substring (car elt) 8))
	     (if (assoc name hier-list) nil
	       (setq hier-list (cons (cons name (cdr elt)) hier-list))))
	   (setq lst index-meth-alist)
	   (while lst
	     (setq elt (car lst) lst (cdr lst))
	     (cond ((string-match "\\(::\\|'\\)[_a-zA-Z0-9]+$" (car elt))
		    (setq pack (substring (car elt) 0 (match-beginning 0)))
		    (if (setq group (assoc pack hier-list))
			(if (listp (cdr group))
			    ;; Have some functions already
			    (setcdr group
				    (cons (cons (substring
						 (car elt)
						 (+ 2 (match-beginning 0)))
						(cdr elt))
					  (cdr group)))
			  (setcdr group (list (cons (substring
						     (car elt)
						     (+ 2 (match-beginning 0)))
						    (cdr elt)))))
		      (setq hier-list
			    (cons (cons pack
					(list (cons (substring
						     (car elt)
						     (+ 2 (match-beginning 0)))
						    (cdr elt))))
				  hier-list))))))
	   (push (cons "+Hierarchy+..."
		       hier-list)
		 index-alist)))
    (and index-pack-alist
	 (push (cons "+Packages+..."
		     (nreverse index-pack-alist))
	       index-alist))
    (and (or index-pack-alist index-pod-alist
	     (default-value 'imenu-sort-function))
	 index-unsorted-alist
	 (push (cons "+Unsorted List+..."
		     (nreverse index-unsorted-alist))
	       index-alist))
    (kurila-imenu-addback index-alist)))


;; Suggested by Mark A. Hershberger
(defun kurila-outline-level ()
  (looking-at outline-regexp)
  (cond ((not (match-beginning 1)) 0)	; beginning-of-file
;;;; 2=package-group, 5=package-name 8=sub-name 16=head-level
	((match-beginning 2) 0)		; package
	((match-beginning 8) 1)		; sub
	((match-beginning 16)
	 (- (char-after (match-beginning 16)) ?0)) ; headN ==> N
	(t 5)))				; should not happen


(defvar kurila-compilation-error-regexp-alist
  ;; This look like a paranoiac regexp: could anybody find a better one? (which WORKS).
  '(("^[^\n]* \\(file\\|at\\) \\([^ \t\n]+\\) [^\n]*line \\([0-9]+\\)\\(?: character \\([0-9]+\\)\\)?[\\., \n]"
     2 3 4))
  "Alist that specifies how to match errors in perl output.")

(require 'compile)
(add-to-list 'compilation-error-regexp-alist
             '("^[^\n]* \\(file\\|at\\) \\([^ \t\n]+\\) [^\n]*line \\([0-9]+\\)\\(?: character \\([0-9]+\\)\\)?[\\., \n]"
               2 3 4))

(if (fboundp 'eval-after-load)
    (eval-after-load
	"mode-compile"
      '(setq perl-compilation-error-regexp-alist
	     kurila-compilation-error-regexp-alist)))


(defun kurila-windowed-init ()
  "Initialization under windowed version."
  (cond ((featurep 'ps-print)
	 (or kurila-faces-init
	     (progn
	       (and (boundp 'font-lock-multiline)
		    (setq kurila-font-lock-multiline t))
	       (kurila-init-faces))))
	((not kurila-faces-init)
	 (add-hook 'font-lock-mode-hook
		   (function
		    (lambda ()
		      (if (memq major-mode '(perl-mode kurila-mode))
			  (progn
			    (or kurila-faces-init (kurila-init-faces)))))))
	 (if (fboundp 'eval-after-load)
	     (eval-after-load
		 "ps-print"
	       '(or kurila-faces-init (kurila-init-faces)))))))

(defun kurila-load-font-lock-keywords ()
  (or kurila-faces-init (kurila-init-faces))
  perl-font-lock-keywords)

(defun kurila-load-font-lock-keywords-1 ()
  (or kurila-faces-init (kurila-init-faces))
  perl-font-lock-keywords-1)

(defun kurila-load-font-lock-keywords-2 ()
  (or kurila-faces-init (kurila-init-faces))
  perl-font-lock-keywords-2)

(defvar perl-font-lock-keywords-1 nil
  "Additional expressions to highlight in Perl mode.  Minimal set.")
(defvar perl-font-lock-keywords nil
  "Additional expressions to highlight in Perl mode.  Default set.")
(defvar perl-font-lock-keywords-2 nil
  "Additional expressions to highlight in Perl mode.  Maximal set.")

(defvar font-lock-background-mode)
(defvar font-lock-display-type)
(defun kurila-init-faces-weak ()
  ;; Allow `kurila-find-pods-heres' to run.
  (or (boundp 'font-lock-constant-face)
      (kurila-force-face font-lock-constant-face
                        "Face for constant and label names"))
  (or (boundp 'font-lock-warning-face)
      (kurila-force-face font-lock-warning-face
			"Face for things which should stand out"))
  ;;(setq font-lock-constant-face 'font-lock-constant-face)
  )

(defun kurila-init-faces ()
  (condition-case errs
      (progn
	(require 'font-lock)
	(and (fboundp 'font-lock-fontify-anchored-keywords)
	     (featurep 'font-lock-extra)
	     (message "You have an obsolete package `font-lock-extra'.  Install `choose-color'."))
	(let (t-font-lock-keywords t-font-lock-keywords-1 font-lock-anchored)
	  (if (fboundp 'font-lock-fontify-anchored-keywords)
	      (setq font-lock-anchored t))
	  (setq
	   t-font-lock-keywords
	   (list
	    (list "[ \t]+$" 0 kurila-invalid-face t)
	    (cons
	     (concat
	      "\\(^\\|[^$@%&\\]\\)\\<\\("
	      (mapconcat
	       'identity
	       '("if" "until" "while" "elsif" "else" "unless" "for"
		 "foreach" "continue" "exit" "die" "last" "goto" "next"
		 "redo" "return" "local" "exec" "sub" "do" "dump" "use" "our"
		 "require" "package" "eval" "my" "BEGIN" "END" "CHECK" "INIT")
	       "\\|")			; Flow control
	      "\\)\\>") 2)		; was "\\)[ \n\t;():,\|&]"
					; In what follows we use `type' style
					; for overwritable builtins
	    (list
	     (concat
	      "\\(^\\|[^$@%&\\]\\)\\<\\("
	      ;; "CORE" "__FILE__" "__LINE__" "abs" "accept" "alarm"
	      ;; "and" "atan2" "bind" "binmode" "bless" "caller"
	      ;; "chdir" "chmod" "chown" "chr" "chroot" "close"
	      ;; "closedir" "cmp" "connect" "continue" "cos" "crypt"
	      ;; "dbmclose" "dbmopen" "die" "dump" "endgrent"
	      ;; "endhostent" "endnetent" "endprotoent" "endpwent"
	      ;; "endservent" "eof" "eq" "exec" "exit" "exp" "fcntl"
	      ;; "fileno" "flock" "fork" "formline" "ge" "getc"
	      ;; "getgrent" "getgrgid" "getgrnam" "gethostbyaddr"
	      ;; "gethostbyname" "gethostent" "getlogin"
	      ;; "getnetbyaddr" "getnetbyname" "getnetent"
	      ;; "getpeername" "getpgrp" "getppid" "getpriority"
	      ;; "getprotobyname" "getprotobynumber" "getprotoent"
	      ;; "getpwent" "getpwnam" "getpwuid" "getservbyname"
	      ;; "getservbyport" "getservent" "getsockname"
	      ;; "getsockopt" "glob" "gmtime" "gt" "hex" "index" "int"
	      ;; "ioctl" "join" "kill" "lc" "lcfirst" "le" "length"
	      ;; "link" "listen" "localtime" "lock" "log" "lstat" "lt"
	      ;; "mkdir" "msgctl" "msgget" "msgrcv" "msgsnd" "ne"
	      ;; "not" "oct" "open" "opendir" "or" "ord" "pack" "pipe"
	      ;; "quotemeta" "rand" "read" "readdir" "readline"
	      ;; "readlink" "readpipe" "recv" "ref" "rename" "require"
	      ;; "reset" "reverse" "rewinddir" "rindex" "rmdir" "seek"
	      ;; "seekdir" "select" "semctl" "semget" "semop" "send"
	      ;; "setgrent" "sethostent" "setnetent" "setpgrp"
	      ;; "setpriority" "setprotoent" "setpwent" "setservent"
	      ;; "setsockopt" "shmctl" "shmget" "shmread" "shmwrite"
	      ;; "shutdown" "sin" "sleep" "socket" "socketpair"
	      ;; "sprintf" "sqrt" "srand" "stat" "substr" "symlink"
	      ;; "syscall" "sysopen" "sysread" "system" "syswrite" "tell"
	      ;; "telldir" "time" "times" "truncate" "uc" "ucfirst"
	      ;; "umask" "unlink" "unpack" "utime" "values" "vec"
	      ;; "wait" "waitpid" "wantarray" "warn" "write" "x" "xor"
	      "a\\(bs\\|ccept\\|tan2\\|larm\\|nd\\)\\|"
	      "b\\(in\\(d\\|mode\\)\\|less\\)\\|"
	      "c\\(h\\(r\\(\\|oot\\)\\|dir\\|mod\\|own\\)\\|aller\\|rypt\\|"
	      "lose\\(\\|dir\\)\\|mp\\|o\\(s\\|n\\(tinue\\|nect\\)\\)\\)\\|"
	      "CORE\\|d\\(ie\\|bm\\(close\\|open\\)\\|ump\\)\\|"
	      "e\\(x\\(p\\|it\\|ec\\)\\|q\\|nd\\(p\\(rotoent\\|went\\)\\|"
	      "hostent\\|servent\\|netent\\|grent\\)\\|of\\)\\|"
	      "f\\(ileno\\|cntl\\|lock\\|or\\(k\\|mline\\)\\)\\|"
	      "g\\(t\\|lob\\|mtime\\|e\\(\\|t\\(p\\(pid\\|r\\(iority\\|"
	      "oto\\(byn\\(ame\\|umber\\)\\|ent\\)\\)\\|eername\\|w"
	      "\\(uid\\|ent\\|nam\\)\\|grp\\)\\|host\\(by\\(addr\\|name\\)\\|"
	      "ent\\)\\|s\\(erv\\(by\\(port\\|name\\)\\|ent\\)\\|"
	      "ock\\(name\\|opt\\)\\)\\|c\\|login\\|net\\(by\\(addr\\|name\\)\\|"
	      "ent\\)\\|gr\\(ent\\|nam\\|gid\\)\\)\\)\\)\\|"
	      "hex\\|i\\(n\\(t\\|dex\\)\\|octl\\)\\|join\\|kill\\|"
	      "l\\(i\\(sten\\|nk\\)\\|stat\\|c\\(\\|first\\)\\|t\\|e"
	      "\\(\\|ngth\\)\\|o\\(c\\(altime\\|k\\)\\|g\\)\\)\\|m\\(sg\\(rcv\\|snd\\|"
	      "ctl\\|get\\)\\|kdir\\)\\|n\\(e\\|ot\\)\\|o\\(pen\\(\\|dir\\)\\|"
	      "r\\(\\|d\\)\\|ct\\)\\|p\\(ipe\\|ack\\)\\|quotemeta\\|"
	      "r\\(index\\|and\\|mdir\\|e\\(quire\\|ad\\(pipe\\|\\|lin"
	      "\\(k\\|e\\)\\|dir\\)\\|set\\|cv\\|verse\\|f\\|winddir\\|name"
	      "\\)\\)\\|s\\(printf\\|qrt\\|rand\\|tat\\|ubstr\\|e\\(t\\(p\\(r"
	      "\\(iority\\|otoent\\)\\|went\\|grp\\)\\|hostent\\|s\\(ervent\\|"
	      "ockopt\\)\\|netent\\|grent\\)\\|ek\\(\\|dir\\)\\|lect\\|"
	      "m\\(ctl\\|op\\|get\\)\\|nd\\)\\|h\\(utdown\\|m\\(read\\|ctl\\|"
	      "write\\|get\\)\\)\\|y\\(s\\(read\\|call\\|open\\|tem\\|write\\)\\|"
	      "mlink\\)\\|in\\|leep\\|ocket\\(pair\\|\\)\\)\\|t\\(runcate\\|"
	      "ell\\(\\|dir\\)\\|ime\\(\\|s\\)\\)\\|u\\(c\\(\\|first\\)\\|"
	      "time\\|mask\\|n\\(pack\\|link\\)\\)\\|v\\(alues\\|ec\\)\\|"
	      "w\\(a\\(rn\\|it\\(pid\\|\\)\\|ntarray\\)\\|rite\\)\\|"
	      "x\\(\\|or\\)\\|__\\(FILE__\\|LINE__\\|PACKAGE__\\)"
	      "\\)\\>") 2 'font-lock-type-face)
	    ;; In what follows we use `other' style
	    ;; for nonoverwritable builtins
	    ;; Somehow 's', 'm' are not auto-generated???
	    (list
	     (concat
	      "\\(^\\|[^$@%&\\]\\)\\<\\("
	      ;; "AUTOLOAD" "BEGIN" "CHECK" "DESTROY" "END" "INIT" "__END__" "chomp"
	      ;; "chop" "defined" "delete" "do" "each" "else" "elsif"
	      ;; "eval" "exists" "for" "foreach" "format" "goto"
	      ;; "grep" "if" "keys" "last" "local" "map" "my" "next"
	      ;; "no" "our" "package" "pop" "pos" "print" "printf" "push"
	      ;; "q" "qq" "qw" "qx" "redo" "return" "scalar" "shift"
	      ;; "sort" "splice" "split" "study" "sub" "tie" "tr"
	      ;; "undef" "unless" "unshift" "untie" "until" "use"
	      ;; "while" "y"
	      "AUTOLOAD\\|BEGIN\\|CHECK\\|cho\\(p\\|mp\\)\\|d\\(e\\(fined\\|lete\\)\\|"
	      "o\\)\\|DESTROY\\|e\\(ach\\|val\\|xists\\|ls\\(e\\|if\\)\\)\\|"
	      "END\\|for\\(\\|each\\|mat\\)\\|g\\(rep\\|oto\\)\\|INIT\\|if\\|keys\\|"
	      "l\\(ast\\|ocal\\)\\|m\\(ap\\|y\\)\\|n\\(ext\\|o\\)\\|our\\|"
	      "p\\(ackage\\|rint\\(\\|f\\)\\|ush\\|o\\(p\\|s\\)\\)\\|"
	      "q\\(\\|q\\|w\\|x\\|r\\)\\|re\\(turn\\|do\\)\\|s\\(pli\\(ce\\|t\\)\\|"
	      "calar\\|tudy\\|ub\\|hift\\|ort\\)\\|t\\(r\\|ie\\)\\|"
	      "u\\(se\\|n\\(shift\\|ti\\(l\\|e\\)\\|def\\|less\\)\\)\\|"
	      "while\\|y\\|__\\(END\\|DATA\\)__" ;__DATA__ added manually
	      "\\|[sm]"			; Added manually
	      "\\)\\>") 2 'kurila-nonoverridable-face)
	    ;;		(mapconcat 'identity
	    ;;			   '("#endif" "#else" "#ifdef" "#ifndef" "#if"
	    ;;			     "#include" "#define" "#undef")
	    ;;			   "\\|")
	    '("-[rwxoRWXOezsfdlpSbctugkTBMAC]\\>\\([ \t]+_\\>\\)?" 0
	      font-lock-function-name-face keep) ; Not very good, triggers at "[a-z]"
	    ;; This highlights declarations and definitions differenty.
	    ;; We do not try to highlight in the case of attributes:
	    ;; it is already done by `kurila-find-pods-heres'
	    (list (concat "\\<sub"
			  kurila-white-and-comment-rex ; whitespace/comments
			  "\\([^ \n\t{;()]+\\)" ; 2=name (assume non-anonymous)
			  "\\("
			    kurila-maybe-white-and-comment-rex ;whitespace/comments?
			    "([^()]*)\\)?") ; prototype
		  2 font-lock-function-name-face)
	    '("\\<\\(package\\|require\\|use\\|import\\|no\\|bootstrap\\)[ \t]+\\([a-zA-z_][a-zA-z_0-9:]*\\)[ \t;]" ; require A if B;
	      2 font-lock-function-name-face)
	    (cond ((featurep 'font-lock-extra)
		   '("\\([]}\\\\%@>*&]\\|\\$[a-zA-Z0-9_:]*\\)[ \t]*{[ ]*[+?]?[ ]*\\([a-zA-Z0-9_:]+\\)[ ]*}"
		     (2 font-lock-string-face t)
		     (0 '(restart 2 t)))) ; To highlight $a{bc}{ef}
		  (font-lock-anchored
		   '("\\([]}\\\\%@>*&]\\|\\$[a-zA-Z0-9_:]*\\)[ ]*{[ ]*[+?]?[ ]*\\([a-zA-Z0-9_:]+\\)[ ]*}"
		     (2 font-lock-string-face t)
		     ("\\=[ ]*{[ ]*[+?]?[ ]*\\([a-zA-Z0-9_:]+\\)[ ]*}"
		      nil nil
		      (1 font-lock-string-face t))))
		  (t '("\\([]}\\\\%@>*&]\\|\\$[a-zA-Z0-9_:]*\\)[ ]*{[ ]*[+?][ ]*\\([a-zA-Z0-9_:]+\\)[ ]*}"
		       2 font-lock-string-face t)))
	    '("[\[ {,(]\\([a-zA-Z0-9_:]+\\)[ ]*=>" 1
	      font-lock-string-face t)
	    '("^[ ]*\\([a-zA-Z0-9_]+[ ]*:\\)[ \t]*\\($\\|{\\|\\<\\(until\\|while\\|for\\(each\\)?\\|do\\)\\>\\)" 1
	      font-lock-constant-face)	; labels
	    '("\\<\\(continue\\|next\\|last\\|redo\\|goto\\)\\>[ \t]+\\([a-zA-Z0-9_:]+\\)" ; labels as targets
	      2 font-lock-constant-face)
	    (cond ((featurep 'font-lock-extra)
		   '("^[ \t]*\\(my\\|local\\|our\\)[ \t]*\\(([ \t]*\\)?\\([$@%*][a-zA-Z0-9_:]+\\)\\([ \t]*,\\)?"
		     (3 font-lock-variable-name-face)
		     (4 '(another 4 nil
				  ("\\=[ \t]*,[ \t]*\\([$@%*][a-zA-Z0-9_:]+\\)\\([ \t]*,\\)?"
				   (1 font-lock-variable-name-face)
				   (2 '(restart 2 nil) nil t)))
			nil t)))	; local variables, multiple
		  (font-lock-anchored
		   ;; 1=my_etc, 2=white? 3=(+white? 4=white? 5=var
		   (` ((, (concat "\\<\\(my\\|local\\|our\\)"
				  kurila-maybe-white-and-comment-rex
				  "\\(("
				     kurila-maybe-white-and-comment-rex
				  "\\)?\\([$@%*]\\([a-zA-Z0-9_:]+\\|[^a-zA-Z0-9_]\\)\\)"))
		       (5 (, (if kurila-font-lock-multiline
				 'font-lock-variable-name-face
			       '(progn  (setq kurila-font-lock-multiline-start
					      (match-beginning 0))
					'font-lock-variable-name-face))))
		       ((, (concat "\\="
				   kurila-maybe-white-and-comment-rex
				   ","
				   kurila-maybe-white-and-comment-rex
				   "\\([$@%*]\\([a-zA-Z0-9_:]+\\|[^a-zA-Z0-9_]\\)\\)"))
			;; Bug in font-lock: limit is used not only to limit 
			;; searches, but to set the "extend window for
			;; facification" property.  Thus we need to minimize.
			(, (if kurila-font-lock-multiline
			     '(if (match-beginning 3)
				  (save-excursion
				    (goto-char (match-beginning 3))
				    (condition-case nil
					(forward-sexp 1)
				      (error
				       (condition-case nil
					   (forward-char 200)
					 (error nil)))) ; typeahead
				    (1- (point))) ; report limit
				(forward-char -2)) ; disable continued expr
			     '(if (match-beginning 3)
				  (point-max) ; No limit for continuation
				(forward-char -2)))) ; disable continued expr
			(, (if kurila-font-lock-multiline
			       nil
			     '(progn	; Do at end
				;; "my" may be already fontified (POD),
				;; so kurila-font-lock-multiline-start is nil
				(if (or (not kurila-font-lock-multiline-start)
					(> 2 (count-lines
					      kurila-font-lock-multiline-start
					      (point))))
				    nil
				  (put-text-property
				   (1+ kurila-font-lock-multiline-start) (point)
				   'syntax-type 'multiline))
				(setq kurila-font-lock-multiline-start nil))))
			(3 font-lock-variable-name-face)))))
		  (t '("^[ \t{}]*\\(my\\|local\\|our\\)[ \t]*\\(([ \t]*\\)?\\([$@%*][a-zA-Z0-9_:]+\\)"
		       3 font-lock-variable-name-face)))
	    '("\\<for\\(each\\)?\\([ \t]+\\(my\\|local\\|our\\)\\)?[ \t]*\\(\\$[a-zA-Z_][a-zA-Z_0-9]*\\)[ \t]*("
	      4 font-lock-variable-name-face)))
	  (setq
	   t-font-lock-keywords-1
	   (and (fboundp 'turn-on-font-lock) ; Check for newer font-lock
		;; not yet as of XEmacs 19.12, works with 21.1.11
		(or
		 (not kurila-xemacs-p)
		 (string< "21.1.9" emacs-version)
		 (and (string< "21.1.10" emacs-version)
		      (string< emacs-version "21.1.2")))
		'(
		  ("\\(\\([$@%]\\)[a-zA-Z_:][a-zA-Z0-9_:]*\\)" 1
		   font-lock-variable-name-face
		   t)			; arrays and hashes
		  )))
	  (if kurila-highlight-variables-indiscriminately
	      (setq t-font-lock-keywords-1
		    (append t-font-lock-keywords-1
			    (list '("\\([$*]{?\\sw+\\)" 1
				    font-lock-variable-name-face)))))
	  (setq perl-font-lock-keywords-1
		(if kurila-syntaxify-by-font-lock
		    (cons 'kurila-fontify-update
			  t-font-lock-keywords)
		  t-font-lock-keywords)
		perl-font-lock-keywords perl-font-lock-keywords-1
		perl-font-lock-keywords-2 (append
					   perl-font-lock-keywords-1
					   t-font-lock-keywords-1)))
	(if (fboundp 'ps-print-buffer) (kurila-ps-print-init))
	(if (or (featurep 'choose-color) (featurep 'font-lock-extra))
	    (eval			; Avoid a warning
	     '(font-lock-require-faces
	       (list
		;; Color-light    Color-dark      Gray-light      Gray-dark Mono
		(list 'font-lock-comment-face
		      ["Firebrick"	"OrangeRed" 	"DimGray"	"Gray80"]
		      nil
		      [nil		nil		t		t	t]
		      [nil		nil		t		t	t]
		      nil)
		(list 'font-lock-string-face
		      ["RosyBrown"	"LightSalmon" 	"Gray50"	"LightGray"]
		      nil
		      nil
		      [nil		nil		t		t	t]
		      nil)
		(list 'font-lock-function-name-face
		      (vector
		       "Blue"		"LightSkyBlue"	"Gray50"	"LightGray"
		       (cdr (assq 'background-color ; if mono
				  (frame-parameters))))
		      (vector
		       nil		nil		nil		nil
		       (cdr (assq 'foreground-color ; if mono
				  (frame-parameters))))
		      [nil		nil		t		t	t]
		      nil
		      nil)
		(list 'font-lock-variable-name-face
		      ["DarkGoldenrod"	"LightGoldenrod" "DimGray"	"Gray90"]
		      nil
		      [nil		nil		t		t	t]
		      [nil		nil		t		t	t]
		      nil)
		(list 'font-lock-type-face
		      ["DarkOliveGreen"	"PaleGreen" 	"DimGray"	"Gray80"]
		      nil
		      [nil		nil		t		t	t]
		      nil
		      [nil		nil		t		t	t])
		(list 'font-lock-warning-face
		      ["Pink"		"Red"		"Gray50"	"LightGray"]
		      ["gray20"		"gray90"
							"gray80"	"gray20"]
		      [nil		nil		t		t	t]
		      nil
		      [nil		nil		t		t	t]
		      )
		(list 'font-lock-constant-face
		      ["CadetBlue"	"Aquamarine" 	"Gray50"	"LightGray"]
		      nil
		      [nil		nil		t		t	t]
		      nil
		      [nil		nil		t		t	t])
		(list 'kurila-nonoverridable-face
		      ["chartreuse3"	("orchid1" "orange")
		       nil		"Gray80"]
		      [nil		nil		"gray90"]
		      [nil		nil		nil		t	t]
		      [nil		nil		t		t]
		      [nil		nil		t		t	t])
		(list 'kurila-array-face
		      ["blue"		"yellow" 	nil		"Gray80"]
		      ["lightyellow2"	("navy" "os2blue" "darkgreen")
		       "gray90"]
		      t
		      nil
		      nil)
		(list 'kurila-hash-face
		      ["red"		"red"	 	nil		"Gray80"]
		      ["lightyellow2"	("navy" "os2blue" "darkgreen")
		       "gray90"]
		      t
		      t
		      nil))))
	  ;; Do it the dull way, without choose-color
	  (defvar kurila-guessed-background nil
	    "Display characteristics as guessed by kurila.")
	  (kurila-force-face font-lock-constant-face
			    "Face for constant and label names")
	  (kurila-force-face font-lock-variable-name-face
			    "Face for variable names")
	  (kurila-force-face font-lock-type-face
			    "Face for data types")
	  (kurila-force-face kurila-nonoverridable-face
			    "Face for data types from another group")
	  (kurila-force-face font-lock-warning-face
			    "Face for things which should stand out")
	  (kurila-force-face font-lock-comment-face
			    "Face for comments")
	  (kurila-force-face font-lock-function-name-face
			    "Face for function names")
	  (kurila-force-face kurila-hash-face
			    "Face for hashes")
	  (kurila-force-face kurila-array-face
			    "Face for arrays")
	  (if (and
	       (not (kurila-is-face 'kurila-array-face))
	       (kurila-is-face 'font-lock-emphasized-face))
	      (copy-face 'font-lock-emphasized-face 'kurila-array-face))
	  (if (and
	       (not (kurila-is-face 'kurila-hash-face))
	       (kurila-is-face 'font-lock-other-emphasized-face))
	      (copy-face 'font-lock-other-emphasized-face
			 'kurila-hash-face))
	  (if (and
	       (not (kurila-is-face 'kurila-nonoverridable-face))
	       (kurila-is-face 'font-lock-other-type-face))
	      (copy-face 'font-lock-other-type-face
			 'kurila-nonoverridable-face))
	  ;; Here we try to guess background
	  (let ((background
		 (if (boundp 'font-lock-background-mode)
		     font-lock-background-mode
		   'light))
		(face-list (and (fboundp 'face-list) (face-list))))
	    (defvar kurila-guessed-background
	      (if (and (boundp 'font-lock-display-type)
		       (eq font-lock-display-type 'grayscale))
		  'gray
		background)
	      "Background as guessed by Kurila mode")
	    (and (not (kurila-is-face 'font-lock-constant-face))
		 (kurila-is-face 'font-lock-reference-face)
		 (copy-face 'font-lock-reference-face 'font-lock-constant-face))
	    (if (kurila-is-face 'font-lock-type-face) nil
	      (copy-face 'default 'font-lock-type-face)
	      (cond
	       ((eq background 'light)
		(set-face-foreground 'font-lock-type-face
				     (if (x-color-defined-p "seagreen")
					 "seagreen"
				       "sea green")))
	       ((eq background 'dark)
		(set-face-foreground 'font-lock-type-face
				     (if (x-color-defined-p "os2pink")
					 "os2pink"
				       "pink")))
	       (t
		(set-face-background 'font-lock-type-face "gray90"))))
	    (if (kurila-is-face 'kurila-nonoverridable-face)
		nil
	      (copy-face 'font-lock-type-face 'kurila-nonoverridable-face)
	      (cond
	       ((eq background 'light)
		(set-face-foreground 'kurila-nonoverridable-face
				     (if (x-color-defined-p "chartreuse3")
					 "chartreuse3"
				       "chartreuse")))
	       ((eq background 'dark)
		(set-face-foreground 'kurila-nonoverridable-face
				     (if (x-color-defined-p "orchid1")
					 "orchid1"
				       "orange")))))
	    (if (kurila-is-face 'font-lock-variable-name-face) nil
	      (copy-face 'italic 'font-lock-variable-name-face))
	    (if (kurila-is-face 'font-lock-constant-face) nil
	      (copy-face 'italic 'font-lock-constant-face))))
	(setq kurila-faces-init t))
    (error (message "kurila-init-faces (ignored): %s" errs))))


(defun kurila-ps-print-init ()
  "Initialization of `ps-print' components for faces used in Kurila."
  (eval-after-load "ps-print"
    '(setq ps-bold-faces
	   ;; 			font-lock-variable-name-face
	   ;;			font-lock-constant-face
	   (append '(kurila-array-face
		     kurila-hash-face)
		   ps-bold-faces)
	   ps-italic-faces
	   ;;			font-lock-constant-face
	   (append '(kurila-nonoverridable-face
		     kurila-hash-face)
		   ps-italic-faces)
	   ps-underlined-faces
	   ;;	     font-lock-type-face
	   (append '(kurila-array-face
		     kurila-hash-face
		     underline
		     kurila-nonoverridable-face)
		   ps-underlined-faces))))

(defvar ps-print-face-extension-alist)

(defun kurila-ps-print (&optional file)
  "Pretty-print in Kurila style.
If optional argument FILE is an empty string, prints to printer, otherwise
to the file FILE.  If FILE is nil, prompts for a file name.

Style of printout regulated by the variable `kurila-ps-print-face-properties'."
  (interactive)
  (or file
      (setq file (read-from-minibuffer
		  "Print to file (if empty - to printer): "
		  (concat (buffer-file-name) ".ps")
		  nil nil 'file-name-history)))
  (or (> (length file) 0)
      (setq file nil))
  (require 'ps-print)			; To get ps-print-face-extension-alist
  (let ((ps-print-color-p t)
	(ps-print-face-extension-alist ps-print-face-extension-alist))
    (kurila-ps-extend-face-list kurila-ps-print-face-properties)
    (ps-print-buffer-with-faces file)))

(if (kurila-enable-font-lock) (kurila-windowed-init))

(defconst kurila-styles-entries
  '(kurila-indent-level kurila-brace-offset kurila-continued-brace-offset
    kurila-label-offset kurila-extra-newline-before-brace
    kurila-extra-newline-before-brace-multiline
    kurila-merge-trailing-else
    kurila-continued-statement-offset))

(defconst kurila-style-examples
"##### Numbers etc are: kurila-indent-level kurila-brace-offset
##### kurila-continued-brace-offset kurila-label-offset
##### kurila-continued-statement-offset
##### kurila-merge-trailing-else kurila-extra-newline-before-brace

########### (Do not forget kurila-extra-newline-before-brace-multiline)

### Kurila	(=GNU - extra-newline-before-brace + merge-trailing-else) 2/0/0/-2/2/t/nil
if (foo) {
  bar
    baz;
 label:
  {
    boon;
  }
} else {
  stop;
}

### PerlStyle	(=Kurila with 4 as indent)		4/0/0/-4/4/t/nil
if (foo) {
    bar
	baz;
 label:
    {
	boon;
    }
} else {
    stop;
}

### GNU							2/0/0/-2/2/nil/t
if (foo)
  {
    bar
      baz;
  label:
    {
      boon;
    }
  }
else
  {
    stop;
  }

### C++		(=PerlStyle with braces aligned with control words) 4/0/-4/-4/4/nil/t
if (foo)
{
    bar
	baz;
 label:
    {
	boon;
    }
}
else
{
    stop;
}

### BSD		(=C++, but will not change preexisting merge-trailing-else
###		 and extra-newline-before-brace )		4/0/-4/-4/4
if (foo)
{
    bar
	baz;
 label:
    {
	boon;
    }
}
else
{
    stop;
}

### K&R		(=C++ with indent 5 - merge-trailing-else, but will not
###		 change preexisting extra-newline-before-brace)	5/0/-5/-5/5/nil
if (foo)
{
     bar
	  baz;
 label:
     {
	  boon;
     }
}
else
{
     stop;
}

### Whitesmith	(=PerlStyle, but will not change preexisting
###		 extra-newline-before-brace and merge-trailing-else) 4/0/0/-4/4
if (foo)
    {
	bar
	    baz;
    label:
	{
	    boon;
	}
    }
else
    {
	stop;
    }
"
"Examples of if/else with different indent styles (with v4.23).")

(defconst kurila-style-alist
  '(("Kurila" ;; =GNU - extra-newline-before-brace + kurila-merge-trailing-else
     (kurila-indent-level               .  2)
     (kurila-brace-offset               .  0)
     (kurila-continued-brace-offset     .  0)
     (kurila-label-offset               . -2)
     (kurila-continued-statement-offset .  2)
     (kurila-extra-newline-before-brace .  nil)
     (kurila-extra-newline-before-brace-multiline .  nil)
     (kurila-merge-trailing-else	       .  t))

    ("PerlStyle"			; Kurila with 4 as indent
     (kurila-indent-level               .  4)
     (kurila-brace-offset               .  0)
     (kurila-continued-brace-offset     .  0)
     (kurila-label-offset               . -4)
     (kurila-continued-statement-offset .  4)
     (kurila-extra-newline-before-brace .  nil)
     (kurila-extra-newline-before-brace-multiline .  nil)
     (kurila-merge-trailing-else	       .  t))

    ("GNU"
     (kurila-indent-level               .  2)
     (kurila-brace-offset               .  0)
     (kurila-continued-brace-offset     .  0)
     (kurila-label-offset               . -2)
     (kurila-continued-statement-offset .  2)
     (kurila-extra-newline-before-brace .  t)
     (kurila-extra-newline-before-brace-multiline .  t)
     (kurila-merge-trailing-else	       .  nil))

    ("K&R"
     (kurila-indent-level               .  5)
     (kurila-brace-offset               .  0)
     (kurila-continued-brace-offset     . -5)
     (kurila-label-offset               . -5)
     (kurila-continued-statement-offset .  5)
     ;;(kurila-extra-newline-before-brace .  nil) ; ???
     ;;(kurila-extra-newline-before-brace-multiline .  nil)
     (kurila-merge-trailing-else	       .  nil))

    ("BSD"
     (kurila-indent-level               .  4)
     (kurila-brace-offset               .  0)
     (kurila-continued-brace-offset     . -4)
     (kurila-label-offset               . -4)
     (kurila-continued-statement-offset .  4)
     ;;(kurila-extra-newline-before-brace .  nil) ; ???
     ;;(kurila-extra-newline-before-brace-multiline .  nil)
     ;;(kurila-merge-trailing-else	       .  nil) ; ???
     )

    ("C++"
     (kurila-indent-level               .  4)
     (kurila-brace-offset               .  0)
     (kurila-continued-brace-offset     . -4)
     (kurila-label-offset               . -4)
     (kurila-continued-statement-offset .  4)
     (kurila-extra-newline-before-brace .  t)
     (kurila-extra-newline-before-brace-multiline .  t)
     (kurila-merge-trailing-else	       .  nil))

    ("Whitesmith"
     (kurila-indent-level               .  4)
     (kurila-brace-offset               .  0)
     (kurila-continued-brace-offset     .  0)
     (kurila-label-offset               . -4)
     (kurila-continued-statement-offset .  4)
     ;;(kurila-extra-newline-before-brace .  nil) ; ???
     ;;(kurila-extra-newline-before-brace-multiline .  nil)
     ;;(kurila-merge-trailing-else	       .  nil) ; ???
     )
    ("Current"))
  "List of variables to set to get a particular indentation style.
Should be used via `kurila-set-style' or via Perl menu.

See examples in `kurila-style-examples'.")

(defun kurila-set-style (style)
  "Set Kurila mode variables to use one of several different indentation styles.
The arguments are a string representing the desired style.
The list of styles is in `kurila-style-alist', available styles
are Kurila, PerlStyle, GNU, K&R, BSD, C++ and Whitesmith.

The current value of style is memorized (unless there is a memorized
data already), may be restored by `kurila-set-style-back'.

Chosing \"Current\" style will not change style, so this may be used for
side-effect of memorizing only.  Examples in `kurila-style-examples'."
  (interactive
   (let ((list (mapcar (function (lambda (elt) (list (car elt))))
		       kurila-style-alist)))
     (list (completing-read "Enter style: " list nil 'insist))))
  (or kurila-old-style
      (setq kurila-old-style
	    (mapcar (function
		     (lambda (name)
		       (cons name (eval name))))
		    kurila-styles-entries)))
  (let ((style (cdr (assoc style kurila-style-alist))) setting str sym)
    (while style
      (setq setting (car style) style (cdr style))
      (set (car setting) (cdr setting)))))

(defun kurila-set-style-back ()
  "Restore a style memorised by `kurila-set-style'."
  (interactive)
  (or kurila-old-style (error "The style was not changed"))
  (let (setting)
    (while kurila-old-style
      (setq setting (car kurila-old-style)
	    kurila-old-style (cdr kurila-old-style))
      (set (car setting) (cdr setting)))))

(defun kurila-check-syntax ()
  (interactive)
  (require 'mode-compile)
  (let ((perl-dbg-flags (concat kurila-extra-perl-args " -wc")))
    (eval '(mode-compile))))		; Avoid a warning

(defun kurila-info-buffer (type)
  ;; Returns buffer with documentation.  Creates if missing.
  ;; If TYPE, this vars buffer.
  ;; Special care is taken to not stomp over an existing info buffer
  (let* ((bname (if type "*info-perl-var*" "*info-perl*"))
	 (info (get-buffer bname))
	 (oldbuf (get-buffer "*info*")))
    (if info info
      (save-window-excursion
	;; Get Info running
	(require 'info)
	(cond (oldbuf
	       (set-buffer oldbuf)
	       (rename-buffer "*info-perl-tmp*")))
	(save-window-excursion
	  (info))
	(Info-find-node kurila-info-page (if type "perlvar" "perlfunc"))
	(set-buffer "*info*")
	(rename-buffer bname)
	(cond (oldbuf
	       (set-buffer "*info-perl-tmp*")
	       (rename-buffer "*info*")
	       (set-buffer bname)))
	(make-local-variable 'window-min-height)
	(setq window-min-height 2)
	(current-buffer)))))

(defun kurila-word-at-point (&optional p)
  "Return the word at point or at P."
  (save-excursion
    (if p (goto-char p))
    (or (kurila-word-at-point-hard)
	(progn
	  (require 'etags)
	  (funcall (or (and (boundp 'find-tag-default-function)
			    find-tag-default-function)
		       (get major-mode 'find-tag-default-function)
		       ;; XEmacs 19.12 has `find-tag-default-hook'; it is
		       ;; automatically used within `find-tag-default':
		       'find-tag-default))))))

(defun kurila-info-on-command (command)
  "Show documentation for Perl command COMMAND in other window.
If perl-info buffer is shown in some frame, uses this frame.
Customized by setting variables `kurila-shrink-wrap-info-frame',
`kurila-max-help-size'."
  (interactive
   (let* ((default (kurila-word-at-point))
	  (read (read-string
		 (format "Find doc for Perl function (default %s): "
			 default))))
     (list (if (equal read "")
	       default
	     read))))

  (let ((buffer (current-buffer))
	(cmd-desc (concat "^" (regexp-quote command) "[^a-zA-Z_0-9]")) ; "tr///"
	pos isvar height iniheight frheight buf win fr1 fr2 iniwin not-loner
	max-height char-height buf-list)
    (if (string-match "^-[a-zA-Z]$" command)
	(setq cmd-desc "^-X[ \t\n]"))
    (setq isvar (string-match "^[$@%]" command)
	  buf (kurila-info-buffer isvar)
	  iniwin (selected-window)
	  fr1 (window-frame iniwin))
    (set-buffer buf)
    (goto-char (point-min))
    (or isvar
	(progn (re-search-forward "^-X[ \t\n]")
	       (forward-line -1)))
    (if (re-search-forward cmd-desc nil t)
	(progn
	  ;; Go back to beginning of the group (ex, for qq)
	  (if (re-search-backward "^[ \t\n\f]")
	      (forward-line 1))
	  (beginning-of-line)
	  ;; Get some of
	  (setq pos (point)
		buf-list (list buf "*info-perl-var*" "*info-perl*"))
	  (while (and (not win) buf-list)
	    (setq win (get-buffer-window (car buf-list) t))
	    (setq buf-list (cdr buf-list)))
	  (or (not win)
	      (eq (window-buffer win) buf)
	      (set-window-buffer win buf))
	  (and win (setq fr2 (window-frame win)))
	  (if (or (not fr2) (eq fr1 fr2))
	      (pop-to-buffer buf)
	    (special-display-popup-frame buf) ; Make it visible
	    (select-window win))
	  (goto-char pos)		; Needed (?!).
	  ;; Resize
	  (setq iniheight (window-height)
		frheight (frame-height)
		not-loner (< iniheight (1- frheight))) ; Are not alone
	  (cond ((if not-loner kurila-max-help-size
		   kurila-shrink-wrap-info-frame)
		 (setq height
		       (+ 2
			  (count-lines
			   pos
			   (save-excursion
			     (if (re-search-forward
				  "^[ \t][^\n]*\n+\\([^ \t\n\f]\\|\\'\\)" nil t)
				 (match-beginning 0) (point-max)))))
		       max-height
		       (if not-loner
			   (/ (* (- frheight 3) kurila-max-help-size) 100)
			 (setq char-height (frame-char-height))
			 ;; Non-functioning under OS/2:
			 (if (eq char-height 1) (setq char-height 18))
			 ;; Title, menubar, + 2 for slack
			 (- (/ (x-display-pixel-height) char-height) 4)))
		 (if (> height max-height) (setq height max-height))
		 ;;(message "was %s doing %s" iniheight height)
		 (if not-loner
		     (enlarge-window (- height iniheight))
		   (set-frame-height (window-frame win) (1+ height)))))
	  (set-window-start (selected-window) pos))
      (message "No entry for %s found." command))
    ;;(pop-to-buffer buffer)
    (select-window iniwin)))

(defun kurila-info-on-current-command ()
  "Show documentation for Perl command at point in other window."
  (interactive)
  (kurila-info-on-command (kurila-word-at-point)))

(defun kurila-imenu-info-imenu-search ()
  (if (looking-at "^-X[ \t\n]") nil
    (re-search-backward
     "^\n\\([-a-zA-Z_]+\\)[ \t\n]")
    (forward-line 1)))

(defun kurila-imenu-info-imenu-name ()
  (buffer-substring
   (match-beginning 1) (match-end 1)))

(defun kurila-imenu-on-info ()
  "Shows imenu for Perl Info Buffer.
Opens Perl Info buffer if needed."
  (interactive)
  (let* ((buffer (current-buffer))
	 imenu-create-index-function
	 imenu-prev-index-position-function
	 imenu-extract-index-name-function
	 (index-item (save-restriction
		       (save-window-excursion
			 (set-buffer (kurila-info-buffer nil))
			 (setq imenu-create-index-function
			       'imenu-default-create-index-function
			       imenu-prev-index-position-function
			       'kurila-imenu-info-imenu-search
			       imenu-extract-index-name-function
			       'kurila-imenu-info-imenu-name)
			 (imenu-choose-buffer-index)))))
    (and index-item
	 (progn
	   (push-mark)
	   (pop-to-buffer "*info-perl*")
	   (cond
	    ((markerp (cdr index-item))
	     (goto-char (marker-position (cdr index-item))))
	    (t
	     (goto-char (cdr index-item))))
	   (set-window-start (selected-window) (point))
	   (pop-to-buffer buffer)))))

(defun kurila-lineup (beg end &optional step minshift)
  "Lineup construction in a region.
Beginning of region should be at the start of a construction.
All first occurrences of this construction in the lines that are
partially contained in the region are lined up at the same column.

MINSHIFT is the minimal amount of space to insert before the construction.
STEP is the tabwidth to position constructions.
If STEP is nil, `kurila-lineup-step' will be used
\(or `kurila-indent-level', if `kurila-lineup-step' is `nil').
Will not move the position at the start to the left."
  (interactive "r")
  (let (search col tcol seen b)
    (save-excursion
      (goto-char end)
      (end-of-line)
      (setq end (point-marker))
      (goto-char beg)
      (skip-chars-forward " \t\f")
      (setq beg (point-marker))
      (indent-region beg end nil)
      (goto-char beg)
      (setq col (current-column))
      (if (looking-at "[a-zA-Z0-9_]")
	  (if (looking-at "\\<[a-zA-Z0-9_]+\\>")
	      (setq search
		    (concat "\\<"
			    (regexp-quote
			     (buffer-substring (match-beginning 0)
					       (match-end 0))) "\\>"))
	    (error "Cannot line up in a middle of the word"))
	(if (looking-at "$")
	    (error "Cannot line up end of line"))
	(setq search (regexp-quote (char-to-string (following-char)))))
      (setq step (or step kurila-lineup-step kurila-indent-level))
      (or minshift (setq minshift 1))
      (while (progn
	       (beginning-of-line 2)
	       (and (< (point) end)
		    (re-search-forward search end t)
		    (goto-char (match-beginning 0))))
	(setq tcol (current-column) seen t)
	(if (> tcol col) (setq col tcol)))
      (or seen
	  (error "The construction to line up occurred only once"))
      (goto-char beg)
      (setq col (+ col minshift))
      (if (/= (% col step) 0) (setq step (* step (1+ (/ col step)))))
      (while
	  (progn
	    (kurila-make-indent col)
	    (beginning-of-line 2)
	    (and (< (point) end)
		 (re-search-forward search end t)
		 (goto-char (match-beginning 0)))))))) ; No body

(defun kurila-etags (&optional add all files) ;; NOT USED???
  "Run etags with appropriate options for Perl files.
If optional argument ALL is `recursive', will process Perl files
in subdirectories too."
  (interactive)
  (let ((cmd "etags")
	(args '("-l" "none" "-r"
		;;       1=fullname  2=package?             3=name                       4=proto?             5=attrs? (VERY APPROX!)
		"/\\<sub[ \\t]+\\(\\([a-zA-Z0-9:_]*::\\)?\\([a-zA-Z0-9_]+\\)\\)[ \\t]*\\(([^()]*)[ \t]*\\)?\\([ \t]*:[^#{;]*\\)?\\([{#]\\|$\\)/\\3/"
		"-r"
		"/\\<package[ \\t]+\\(\\([a-zA-Z0-9:_]*::\\)?\\([a-zA-Z0-9_]+\\)\\)[ \\t]*\\([#;]\\|$\\)/\\1/"
		"-r"
		"/\\<\\(package\\)[ \\t]*;/\\1;/"))
	res)
    (if add (setq args (cons "-a" args)))
    (or files (setq files (list buffer-file-name)))
    (cond
     ((eq all 'recursive)
      ;;(error "Not implemented: recursive")
      (setq args (append (list "-e"
			       "sub wanted {push @ARGV, $File::Find::name if /\\.[pP][Llm]$/}
				use File::Find;
				find(\\&wanted, '.');
				exec @ARGV;"
			       cmd) args)
	    cmd "perl"))
     (all
      ;;(error "Not implemented: all")
      (setq args (append (list "-e"
			       "push @ARGV, <*.PL *.pl *.pm>;
				exec @ARGV;"
			       cmd) args)
	    cmd "perl"))
     (t
      (setq args (append args files))))
    (setq res (apply 'call-process cmd nil nil nil args))
    (or (eq res 0)
	(message "etags returned \"%s\"" res))))

(defun kurila-toggle-auto-newline ()
  "Toggle the state of `kurila-auto-newline'."
  (interactive)
  (setq kurila-auto-newline (not kurila-auto-newline))
  (message "Newlines will %sbe auto-inserted now."
	   (if kurila-auto-newline "" "not ")))

(defun kurila-toggle-abbrev ()
  "Toggle the state of automatic keyword expansion in Kurila mode."
  (interactive)
  (abbrev-mode (if abbrev-mode 0 1))
  (message "Perl control structure will %sbe auto-inserted now."
	   (if abbrev-mode "" "not ")))


(defun kurila-toggle-electric ()
  "Toggle the state of parentheses doubling in Kurila mode."
  (interactive)
  (setq kurila-electric-parens (if (kurila-val 'kurila-electric-parens) 'null t))
  (message "Parentheses will %sbe auto-doubled now."
	   (if (kurila-val 'kurila-electric-parens) "" "not ")))

(defun kurila-toggle-autohelp ()
  "Toggle the state of Auto-Help on Perl constructs (put in the message area).
Delay of auto-help controlled by `kurila-lazy-help-time'."
  (interactive)
  (if (fboundp 'run-with-idle-timer)
      (progn
	(if kurila-lazy-installed
	    (kurila-lazy-unstall)
	  (kurila-lazy-install))
	(message "Perl help messages will %sbe automatically shown now."
		 (if kurila-lazy-installed "" "not ")))
    (message "Cannot automatically show Perl help messages - run-with-idle-timer missing.")))

(defun kurila-toggle-construct-fix ()
  "Toggle whether `indent-region'/`indent-sexp' fix whitespace too."
  (interactive)
  (setq kurila-indent-region-fix-constructs
	(if kurila-indent-region-fix-constructs
	    nil
	  1))
  (message "indent-region/indent-sexp will %sbe automatically fix whitespace."
	   (if kurila-indent-region-fix-constructs "" "not ")))

(defun kurila-toggle-set-debug-unwind (arg &optional backtrace)
  "Toggle (or, with numeric argument, set) debugging state of syntaxification.
Nonpositive numeric argument disables debugging messages.  The message
summarizes which regions it was decided to rescan for syntactic constructs.

The message looks like this:

  Syxify req=123..138 actual=101..146 done-to: 112=>146 statepos: 73=>117

Numbers are character positions in the buffer.  REQ provides the range to
rescan requested by `font-lock'.  ACTUAL is the range actually resyntaxified;
for correct operation it should start and end outside any special syntactic
construct.  DONE-TO and STATEPOS indicate changes to internal caches maintained
by Kurila."
  (interactive "P")
  (or arg
      (setq arg (if (eq kurila-syntaxify-by-font-lock 
			(if backtrace 'backtrace 'message)) 0 1)))
  (setq arg (if (> arg 0) (if backtrace 'backtrace 'message) t))
  (setq kurila-syntaxify-by-font-lock arg)
  (message "Debugging messages of syntax unwind %sabled."
	   (if (eq arg t) "dis" "en")))

;;;; Tags file creation.

(defvar kurila-tmp-buffer " *kurila-tmp*")

(defun kurila-setup-tmp-buf ()
  (set-buffer (get-buffer-create kurila-tmp-buffer))
  (set-syntax-table kurila-mode-syntax-table)
  (buffer-disable-undo)
  (auto-fill-mode 0)
  (if kurila-use-syntax-table-text-property-for-tags
      (progn
	(make-local-variable 'parse-sexp-lookup-properties)
	;; Do not introduce variable if not needed, we check it!
	(set 'parse-sexp-lookup-properties t))))

(defun kurila-xsub-scan ()
  (require 'cl)
  (require 'imenu)
  (let ((index-alist '())
	(prev-pos 0) index index1 name package prefix)
    (goto-char (point-min))
    (if noninteractive
	(message "Scanning XSUB for index")
      (imenu-progress-message prev-pos 0))
    ;; Search for the function
    (progn ;;save-match-data
      (while (re-search-forward
	      "^\\([ \t]*MODULE\\>[^\n]*\\<PACKAGE[ \t]*=[ \t]*\\([a-zA-Z_][a-zA-Z_0-9:]*\\)\\>\\|\\([a-zA-Z_][a-zA-Z_0-9]*\\)(\\|[ \t]*BOOT:\\)"
	      nil t)
	(or noninteractive
	    (imenu-progress-message prev-pos))
	(cond
	 ((match-beginning 2)		; SECTION
	  (setq package (buffer-substring (match-beginning 2) (match-end 2)))
	  (goto-char (match-beginning 0))
	  (skip-chars-forward " \t")
	  (forward-char 1)
	  (if (looking-at "[^\n]*\\<PREFIX[ \t]*=[ \t]*\\([a-zA-Z_][a-zA-Z_0-9]*\\)\\>")
	      (setq prefix (buffer-substring (match-beginning 1) (match-end 1)))
	    (setq prefix nil)))
	 ((not package) nil)		; C language section
	 ((match-beginning 3)		; XSUB
	  (goto-char (1+ (match-beginning 3)))
	  (setq index (imenu-example--name-and-position))
	  (setq name (buffer-substring (match-beginning 3) (match-end 3)))
	  (if (and prefix (string-match (concat "^" prefix) name))
	      (setq name (substring name (length prefix))))
	  (cond ((string-match "::" name) nil)
		(t
		 (setq index1 (cons (concat package "::" name) (cdr index)))
		 (push index1 index-alist)))
	  (setcar index name)
	  (push index index-alist))
	 (t				; BOOT: section
	  ;; (beginning-of-line)
	  (setq index (imenu-example--name-and-position))
	  (setcar index (concat package "::BOOT:"))
	  (push index index-alist)))))
    (or noninteractive
	(imenu-progress-message prev-pos 100))
    index-alist))

(defvar kurila-unreadable-ok nil)

(defun kurila-find-tags (ifile xs topdir)
  (let ((b (get-buffer kurila-tmp-buffer)) ind lst elt pos ret rel
	(kurila-pod-here-fontify nil) f file)
    (save-excursion
      (if b (set-buffer b)
	(kurila-setup-tmp-buf))
      (erase-buffer)
      (condition-case err
	  (setq file (car (insert-file-contents ifile)))
	(error (if kurila-unreadable-ok nil
		 (if (y-or-n-p
		      (format "File %s unreadable.  Continue? " ifile))
		     (setq kurila-unreadable-ok t)
		   (error "Aborting: unreadable file %s" ifile)))))
      (if (not file)
	  (message "Unreadable file %s" ifile)
	(message "Scanning file %s ..." file)
	(if (and kurila-use-syntax-table-text-property-for-tags
		 (not xs))
	    (condition-case err		; after __END__ may have garbage
		(kurila-find-pods-heres nil nil noninteractive)
	      (error (message "While scanning for syntax: %s" err))))
	(if xs
	    (setq lst (kurila-xsub-scan))
	  (setq ind (kurila-imenu--create-perl-index))
	  (setq lst (cdr (assoc "+Unsorted List+..." ind))))
	(setq lst
	      (mapcar
	       (function
		(lambda (elt)
		  (cond ((string-match "^[_a-zA-Z]" (car elt))
			 (goto-char (cdr elt))
			 (beginning-of-line) ; pos should be of the start of the line
			 (list (car elt)
			       (point)
			       (1+ (count-lines 1 (point))) ; 1+ since at beg-o-l
			       (buffer-substring (progn
						   (goto-char (cdr elt))
						   ;; After name now...
						   (or (eolp) (forward-char 1))
						   (point))
						 (progn
						   (beginning-of-line)
						   (point))))))))
	       lst))
	(erase-buffer)
	(while lst
	  (setq elt (car lst) lst (cdr lst))
	  (if elt
	      (progn
		(insert (elt elt 3)
			127
			(if (string-match "^package " (car elt))
			    (substring (car elt) 8)
			  (car elt) )
			1
			(number-to-string (elt elt 2)) ; Line
			","
			(number-to-string (1- (elt elt 1))) ; Char pos 0-based
			"\n")
		(if (and (string-match "^[_a-zA-Z]+::" (car elt))
			 (string-match "^sub[ \t]+\\([_a-zA-Z]+\\)[^:_a-zA-Z]"
				       (elt elt 3)))
		    ;; Need to insert the name without package as well
		    (setq lst (cons (cons (substring (elt elt 3)
						     (match-beginning 1)
						     (match-end 1))
					  (cdr elt))
				    lst))))))
	(setq pos (point))
	(goto-char 1)
	(setq rel file)
	;; On case-preserving filesystems (EMX on OS/2) case might be encoded in properties
	(set-text-properties 0 (length rel) nil rel)
	(and (equal topdir (substring rel 0 (length topdir)))
	     (setq rel (substring file (length topdir))))
	(insert "\f\n" rel "," (number-to-string (1- pos)) "\n")
	(setq ret (buffer-substring 1 (point-max)))
	(erase-buffer)
	(or noninteractive
	    (message "Scanning file %s finished" file))
	ret))))

(defun kurila-add-tags-recurse-noxs ()
  "Add to TAGS data for \"pure\" Perl files in the current directory and kids.
Use as
  emacs -batch -q -no-site-file -l emacs/kurila-mode.el \
        -f kurila-add-tags-recurse-noxs
"
  (kurila-write-tags nil nil t t nil t))

(defun kurila-add-tags-recurse-noxs-fullpath ()
  "Add to TAGS data for \"pure\" Perl in the current directory and kids.
Writes down fullpath, so TAGS is relocatable (but if the build directory
is relocated, the file TAGS inside it breaks). Use as
  emacs -batch -q -no-site-file -l emacs/kurila-mode.el \
        -f kurila-add-tags-recurse-noxs-fullpath
"
  (kurila-write-tags nil nil t t nil t ""))

(defun kurila-add-tags-recurse ()
  "Add to TAGS file data for Perl files in the current directory and kids.
Use as
  emacs -batch -q -no-site-file -l emacs/kurila-mode.el \
        -f kurila-add-tags-recurse
"
  (kurila-write-tags nil nil t t))

(defun kurila-write-tags (&optional file erase recurse dir inbuffer noxs topdir)
  ;; If INBUFFER, do not select buffer, and do not save
  ;; If ERASE is `ignore', do not erase, and do not try to delete old info.
  (require 'etags)
  (if file nil
    (setq file (if dir default-directory (buffer-file-name)))
    (if (and (not dir) (buffer-modified-p)) (error "Save buffer first!")))
  (or topdir
      (setq topdir default-directory))
  (let ((tags-file-name "TAGS")
	(case-fold-search (eq system-type 'emx))
	xs rel tm)
    (save-excursion
      (cond (inbuffer nil)		; Already there
	    ((file-exists-p tags-file-name)
	     (if kurila-xemacs-p
		 (visit-tags-table-buffer)
	       (visit-tags-table-buffer tags-file-name)))
	    (t (set-buffer (find-file-noselect tags-file-name))))
      (cond
       (dir
	(cond ((eq erase 'ignore))
	      (erase
	       (erase-buffer)
	       (setq erase 'ignore)))
	(let ((files
	       (condition-case err
		   (directory-files file t
				    (if recurse nil kurila-scan-files-regexp)
				    t)
		 (error
		  (if kurila-unreadable-ok nil
		    (if (y-or-n-p
			 (format "Directory %s unreadable.  Continue? " file))
			(setq kurila-unreadable-ok t
			      tm nil)	; Return empty list
		      (error "Aborting: unreadable directory %s" file)))))))
	  (mapcar (function
		   (lambda (file)
		     (cond
		      ((string-match kurila-noscan-files-regexp file)
		       nil)
		      ((not (file-directory-p file))
		       (if (string-match kurila-scan-files-regexp file)
			   (kurila-write-tags file erase recurse nil t noxs topdir)))
		      ((not recurse) nil)
		      (t (kurila-write-tags file erase recurse t t noxs topdir)))))
		  files)))
       (t
	(setq xs (string-match "\\.xs$" file))
	(if (not (and xs noxs))
	    (progn
	      (cond ((eq erase 'ignore) (goto-char (point-max)))
		    (erase (erase-buffer))
		    (t
		     (goto-char 1)
		     (setq rel file)
		     ;; On case-preserving filesystems (EMX on OS/2) case might be encoded in properties
		     (set-text-properties 0 (length rel) nil rel)
		     (and (equal topdir (substring rel 0 (length topdir)))
			  (setq rel (substring file (length topdir))))
		     (if (search-forward (concat "\f\n" rel ",") nil t)
			 (progn
			   (search-backward "\f\n")
			   (delete-region (point)
					  (save-excursion
					    (forward-char 1)
					    (if (search-forward "\f\n"
								nil 'toend)
						(- (point) 2)
					      (point-max)))))
		       (goto-char (point-max)))))
	      (insert (kurila-find-tags file xs topdir))))))
      (if inbuffer nil			; Delegate to the caller
	(save-buffer 0)			; No backup
	(if (fboundp 'initialize-new-tags-table) ; Do we need something special in XEmacs?
	    (initialize-new-tags-table))))))

(defvar kurila-tags-hier-regexp-list
  (concat
   "^\\("
      "\\(package\\)\\>"
     "\\|"
      "sub\\>[^\n]+::"
     "\\|"
      "[a-zA-Z_][a-zA-Z_0-9:]*(\C-?[^\n]+::" ; XSUB?
     "\\|"
      "[ \t]*BOOT:\C-?[^\n]+::"		; BOOT section
   "\\)"))

(defvar kurila-hierarchy '(() ())
  "Global hierarchy of classes.")

(defun kurila-tags-hier-fill ()
  ;; Suppose we are in a tag table cooked by kurila.
  (goto-char 1)
  (let (type pack name pos line chunk ord cons1 file str info fileind)
    (while (re-search-forward kurila-tags-hier-regexp-list nil t)
      (setq pos (match-beginning 0)
	    pack (match-beginning 2))
      (beginning-of-line)
      (if (looking-at (concat
		       "\\([^\n]+\\)"
		       "\C-?"
		       "\\([^\n]+\\)"
		       "\C-a"
		       "\\([0-9]+\\)"
		       ","
		       "\\([0-9]+\\)"))
	  (progn
	    (setq ;;str (buffer-substring (match-beginning 1) (match-end 1))
		  name (buffer-substring (match-beginning 2) (match-end 2))
		  ;;pos (buffer-substring (match-beginning 3) (match-end 3))
		  line (buffer-substring (match-beginning 3) (match-end 3))
		  ord (if pack 1 0)
		  file (file-of-tag)
		  fileind (format "%s:%s" file line)
		  ;; Moves to beginning of the next line:
		  info (kurila-etags-snarf-tag file line))
	    ;; Move back
	    (forward-char -1)
	    ;; Make new member of hierarchy name ==> file ==> pos if needed
	    (if (setq cons1 (assoc name (nth ord kurila-hierarchy)))
		;; Name known
		(setcdr cons1 (cons (cons fileind (vector file info))
				    (cdr cons1)))
	      ;; First occurrence of the name, start alist
	      (setq cons1 (cons name (list (cons fileind (vector file info)))))
	      (if pack
		  (setcar (cdr kurila-hierarchy)
			  (cons cons1 (nth 1 kurila-hierarchy)))
		(setcar kurila-hierarchy
			(cons cons1 (car kurila-hierarchy)))))))
      (end-of-line))))

(defun kurila-tags-hier-init (&optional update)
  "Show hierarchical menu of classes and methods.
Finds info about classes by a scan of loaded TAGS files.
Supposes that the TAGS files contain fully qualified function names.
One may build such TAGS files from Kurila mode menu."
  (interactive)
  (require 'etags)
  (require 'imenu)
  (if (or update (null (nth 2 kurila-hierarchy)))
      (let ((remover (function (lambda (elt) ; (name (file1...) (file2..))
				 (or (nthcdr 2 elt)
				     ;; Only in one file
				     (setcdr elt (cdr (nth 1 elt)))))))
	    pack name cons1 to l1 l2 l3 l4 b)
	;; (setq kurila-hierarchy '(() () ())) ; Would write into '() later!
	(setq kurila-hierarchy (list l1 l2 l3))
	(if kurila-xemacs-p		; Not checked
	    (progn
	      (or tags-file-name
		  ;; Does this work in XEmacs?
		  (call-interactively 'visit-tags-table))
	      (message "Updating list of classes...")
	      (set-buffer (get-file-buffer tags-file-name))
	      (kurila-tags-hier-fill))
	  (or tags-table-list
	      (call-interactively 'visit-tags-table))
	  (mapcar
	   (function
	    (lambda (tagsfile)
	      (message "Updating list of classes... %s" tagsfile)
	      (set-buffer (get-file-buffer tagsfile))
	      (kurila-tags-hier-fill)))
	   tags-table-list)
	  (message "Updating list of classes... postprocessing..."))
	(mapcar remover (car kurila-hierarchy))
	(mapcar remover (nth 1 kurila-hierarchy))
	(setq to (list nil (cons "Packages: " (nth 1 kurila-hierarchy))
		       (cons "Methods: " (car kurila-hierarchy))))
	(kurila-tags-treeify to 1)
	(setcar (nthcdr 2 kurila-hierarchy)
		(kurila-menu-to-keymap (cons '("+++UPDATE+++" . -999) (cdr to))))
	(message "Updating list of classes: done, requesting display...")
	;;(kurila-imenu-addback (nth 2 kurila-hierarchy))
	))
  (or (nth 2 kurila-hierarchy)
      (error "No items found"))
  (setq update
;;;	(imenu-choose-buffer-index "Packages: " (nth 2 kurila-hierarchy))
	(if (if (fboundp 'display-popup-menus-p)
		(let ((f 'display-popup-menus-p))
		  (funcall f))
	      window-system)
	    (x-popup-menu t (nth 2 kurila-hierarchy))
	  (require 'tmm)
	  (tmm-prompt (nth 2 kurila-hierarchy))))
  (if (and update (listp update))
      (progn (while (cdr update) (setq update (cdr update)))
	     (setq update (car update)))) ; Get the last from the list
  (if (vectorp update)
      (progn
	(find-file (elt update 0))
	(kurila-etags-goto-tag-location (elt update 1))))
  (if (eq update -999) (kurila-tags-hier-init t)))

(defun kurila-tags-treeify (to level)
  ;; cadr of `to' is read-write.  On start it is a cons
  (let* ((regexp (concat "^\\(" (mapconcat
				 'identity
				 (make-list level "[_a-zA-Z0-9]+")
				 "::")
			 "\\)\\(::\\)?"))
	 (packages (cdr (nth 1 to)))
	 (methods (cdr (nth 2 to)))
	 l1 head tail cons1 cons2 ord writeto packs recurse
	 root-packages root-functions ms many_ms same_name ps
	 (move-deeper
	  (function
	   (lambda (elt)
	     (cond ((and (string-match regexp (car elt))
			 (or (eq ord 1) (match-end 2)))
		    (setq head (substring (car elt) 0 (match-end 1))
			  tail (if (match-end 2) (substring (car elt)
							    (match-end 2)))
			  recurse t)
		    (if (setq cons1 (assoc head writeto)) nil
		      ;; Need to init new head
		      (setcdr writeto (cons (list head (list "Packages: ")
						  (list "Methods: "))
					    (cdr writeto)))
		      (setq cons1 (nth 1 writeto)))
		    (setq cons2 (nth ord cons1)) ; Either packs or meths
		    (setcdr cons2 (cons elt (cdr cons2))))
		   ((eq ord 2)
		    (setq root-functions (cons elt root-functions)))
		   (t
		    (setq root-packages (cons elt root-packages))))))))
    (setcdr to l1)			; Init to dynamic space
    (setq writeto to)
    (setq ord 1)
    (mapcar move-deeper packages)
    (setq ord 2)
    (mapcar move-deeper methods)
    (if recurse
	(mapcar (function (lambda (elt)
			  (kurila-tags-treeify elt (1+ level))))
		(cdr to)))
    ;;Now clean up leaders with one child only
    (mapcar (function (lambda (elt)
			(if (not (and (listp (cdr elt))
				      (eq (length elt) 2))) nil
			    (setcar elt (car (nth 1 elt)))
			    (setcdr elt (cdr (nth 1 elt))))))
	    (cdr to))
    ;; Sort the roots of subtrees
    (if (default-value 'imenu-sort-function)
	(setcdr to
		(sort (cdr to) (default-value 'imenu-sort-function))))
    ;; Now add back functions removed from display
    (mapcar (function (lambda (elt)
			(setcdr to (cons elt (cdr to)))))
	    (if (default-value 'imenu-sort-function)
		(nreverse
		 (sort root-functions (default-value 'imenu-sort-function)))
	      root-functions))
    ;; Now add back packages removed from display
    (mapcar (function (lambda (elt)
			(setcdr to (cons (cons (concat "package " (car elt))
					       (cdr elt))
					 (cdr to)))))
	    (if (default-value 'imenu-sort-function)
		(nreverse
		 (sort root-packages (default-value 'imenu-sort-function)))
	      root-packages))))

;;;(x-popup-menu t
;;;   '(keymap "Name1"
;;;	    ("Ret1" "aa")
;;;	    ("Head1" "ab"
;;;	     keymap "Name2"
;;;	     ("Tail1" "x") ("Tail2" "y"))))

(defun kurila-list-fold (list name limit)
  (let (list1 list2 elt1 (num 0))
    (if (<= (length list) limit) list
      (setq list1 nil list2 nil)
      (while list
	(setq num (1+ num)
	      elt1 (car list)
	      list (cdr list))
	(if (<= num imenu-max-items)
	    (setq list2 (cons elt1 list2))
	  (setq list1 (cons (cons name
				  (nreverse list2))
			    list1)
		list2 (list elt1)
		num 1)))
      (nreverse (cons (cons name
			    (nreverse list2))
		      list1)))))

(defun kurila-menu-to-keymap (menu &optional name)
  (let (list)
    (cons 'keymap
	  (mapcar
	   (function
	    (lambda (elt)
	      (cond ((listp (cdr elt))
		     (setq list (kurila-list-fold
				 (cdr elt) (car elt) imenu-max-items))
		     (cons nil
			   (cons (car elt)
				 (kurila-menu-to-keymap list))))
		    (t
		     (list (cdr elt) (car elt) t))))) ; t is needed in 19.34
	   (kurila-list-fold menu "Root" imenu-max-items)))))


(defvar kurila-bad-style-regexp
  (mapconcat 'identity
	     '("[^-\n\t <>=+!.&|(*/'`\"#^][-=+<>!|&^]" ; char sign
	       "[-<>=+^&|]+[^- \t\n=+<>~]") ; sign+ char
	     "\\|")
  "Finds places such that insertion of a whitespace may help a lot.")

(defvar kurila-not-bad-style-regexp
  (mapconcat
   'identity
   '("[^-\t <>=+]\\(--\\|\\+\\+\\)"	; var-- var++
     "[a-zA-Z0-9_][|&][a-zA-Z0-9_$]"	; abc|def abc&def are often used.
     "&[(a-zA-Z0-9_$]"			; &subroutine &(var->field)
     "<\\$?\\sw+\\(\\.\\(\\sw\\|_\\)+\\)?>"	; <IN> <stdin.h>
     "-[a-zA-Z][ \t]+[_$\"'`a-zA-Z]"	; -f file, -t STDIN
     "-[0-9]"				; -5
     "\\+\\+"				; ++var
     "--"				; --var
     ".->"				; a->b
     "->"				; a SPACE ->b
     "\\[-"				; a[-1]
     "\\\\[&$@*\\\\]"			; \&func
     "^="				; =head
     "\\$."				; $|
     "<<[a-zA-Z_'\"`]"			; <<FOO, <<'FOO'
     "||"
     "&&"
     "[CBIXSLFZ]<\\(\\sw\\|\\s \\|\\s_\\|[\n]\\)*>" ; C<code like text>
     "-[a-zA-Z_0-9]+[ \t]*=>"		; -option => value
     ;; Unaddressed trouble spots: = -abc, f(56, -abc) --- specialcased below
     ;;"[*/+-|&<.]+="
     )
   "\\|")
  "If matches at the start of match found by `my-bad-c-style-regexp',
insertion of a whitespace will not help.")

(defvar found-bad)

(defun kurila-find-bad-style ()
  "Find places in the buffer where insertion of a whitespace may help.
Prompts user for insertion of spaces.
Currently it is tuned to C and Perl syntax."
  (interactive)
  (let (found-bad (p (point)))
    (setq last-nonmenu-event 13)	; To disable popup
    (goto-char (point-min))
    (map-y-or-n-p "Insert space here? "
		  (lambda (arg) (insert " "))
		  'kurila-next-bad-style
		  '("location" "locations" "insert a space into")
		  '((?\C-r (lambda (arg)
			     (let ((buffer-quit-function
				    'exit-recursive-edit))
			       (message "Exit with Esc Esc")
			       (recursive-edit)
			       t))	; Consider acted upon
			   "edit, exit with Esc Esc")
		    (?e (lambda (arg)
			  (let ((buffer-quit-function
				 'exit-recursive-edit))
			    (message "Exit with Esc Esc")
			    (recursive-edit)
			    t))		; Consider acted upon
			"edit, exit with Esc Esc"))
		  t)
    (if found-bad (goto-char found-bad)
      (goto-char p)
      (message "No appropriate place found"))))

(defun kurila-next-bad-style ()
  (let (p (not-found t) (point (point)) found)
    (while (and not-found
		(re-search-forward kurila-bad-style-regexp nil 'to-end))
      (setq p (point))
      (goto-char (match-beginning 0))
      (if (or
	   (looking-at kurila-not-bad-style-regexp)
	   ;; Check for a < -b and friends
	   (and (eq (following-char) ?\-)
		(save-excursion
		  (skip-chars-backward " \t\n")
		  (memq (preceding-char) '(?\= ?\> ?\< ?\, ?\( ?\[ ?\{))))
	   ;; Now check for syntax type
	   (save-match-data
	     (setq found (point))
	     (beginning-of-defun)
	     (let ((pps (parse-partial-sexp (point) found)))
	       (or (nth 3 pps) (nth 4 pps) (nth 5 pps)))))
	  (goto-char (match-end 0))
	(goto-char (1- p))
	(setq not-found nil
	      found-bad found)))
    (not not-found)))


;;; Getting help
(defvar kurila-have-help-regexp
  ;;(concat "\\("
  (mapconcat
   'identity
   '("[$@%*&][0-9a-zA-Z_:]+\\([ \t]*[[{]\\)?" ; Usual variable
     "[$@]\\^[a-zA-Z]"			; Special variable
     "[$@][^ \n\t]"			; Special variable
     "-[a-zA-Z]"			; File test
     "\\\\[a-zA-Z0]"			; Special chars
     "^=[a-z][a-zA-Z0-9_]*"		; POD sections
     "[-!&*+,-./<=>?\\\\^|~]+"		; Operator
     "[a-zA-Z_0-9:]+"			; symbol or number
     "x="
     "#!")
   ;;"\\)\\|\\("
   "\\|")
  ;;"\\)"
  ;;)
  "Matches places in the buffer we can find help for.")

(defvar kurila-message-on-help-error t)
(defvar kurila-help-from-timer nil)

(defun kurila-word-at-point-hard ()
  ;; Does not save-excursion
  ;; Get to the something meaningful
  (or (eobp) (eolp) (forward-char 1))
  (re-search-backward "[-a-zA-Z0-9_:!&*+,-./<=>?\\\\^|~$%@]"
		      (save-excursion (beginning-of-line) (point))
		      'to-beg)
  ;;  (cond
  ;;   ((or (eobp) (looking-at "[][ \t\n{}();,]")) ; Not at a symbol
  ;;    (skip-chars-backward " \n\t\r({[]});,")
  ;;    (or (bobp) (backward-char 1))))
  ;; Try to backtrace
  (cond
   ((looking-at "[a-zA-Z0-9_:]")	; symbol
    (skip-chars-backward "a-zA-Z0-9_:")
    (cond
     ((and (eq (preceding-char) ?^)	; $^I
	   (eq (char-after (- (point) 2)) ?\$))
      (forward-char -2))
     ((memq (preceding-char) (append "*$@%&\\" nil)) ; *glob
      (forward-char -1))
     ((and (eq (preceding-char) ?\=)
	   (eq (current-column) 1))
      (forward-char -1)))		; =head1
    (if (and (eq (preceding-char) ?\<)
	     (looking-at "\\$?[a-zA-Z0-9_:]+>")) ; <FH>
	(forward-char -1)))
   ((and (looking-at "=") (eq (preceding-char) ?x)) ; x=
    (forward-char -1))
   ((and (looking-at "\\^") (eq (preceding-char) ?\$)) ; $^I
    (forward-char -1))
   ((looking-at "[-!&*+,-./<=>?\\\\^|~]")
    (skip-chars-backward "-!&*+,-./<=>?\\\\^|~")
    (cond
     ((and (eq (preceding-char) ?\$)
	   (not (eq (char-after (- (point) 2)) ?\$))) ; $-
      (forward-char -1))
     ((and (eq (following-char) ?\>)
	   (string-match "[a-zA-Z0-9_]" (char-to-string (preceding-char)))
	   (save-excursion
	     (forward-sexp -1)
	     (and (eq (preceding-char) ?\<)
		  (looking-at "\\$?[a-zA-Z0-9_:]+>")))) ; <FH>
      (search-backward "<"))))
   ((and (eq (following-char) ?\$)
	 (eq (preceding-char) ?\<)
	 (looking-at "\\$?[a-zA-Z0-9_:]+>")) ; <$fh>
    (forward-char -1)))
  (if (looking-at kurila-have-help-regexp)
      (buffer-substring (match-beginning 0) (match-end 0))))

(defun kurila-get-help ()
  "Get one-line docs on the symbol at the point.
The data for these docs is a little bit obsolete and may be in fact longer
than a line.  Your contribution to update/shorten it is appreciated."
  (interactive)
  (save-match-data			; May be called "inside" query-replace
    (save-excursion
      (let ((word (kurila-word-at-point-hard)))
	(if word
	    (if (and kurila-help-from-timer ; Bail out if not in mainland
		     (not (string-match "^#!\\|\\\\\\|^=" word)) ; Show help even in comments/strings.
		     (or (memq (get-text-property (point) 'face)
			       '(font-lock-comment-face font-lock-string-face))
			 (memq (get-text-property (point) 'syntax-type)
			       '(pod here-doc))))
		nil
	      (kurila-describe-perl-symbol word))
	  (if kurila-message-on-help-error
	      (message "Nothing found for %s..."
		       (buffer-substring (point) (min (+ 5 (point)) (point-max))))))))))

;;; Stolen from perl-descr.el by Johan Vromans:

(defvar kurila-doc-buffer " *perl-doc*"
  "Where the documentation can be found.")

(defun kurila-describe-perl-symbol (val)
  "Display the documentation of symbol at point, a Perl operator."
  (let ((enable-recursive-minibuffers t)
	args-file regexp)
    (cond
     ((string-match "^[&*][a-zA-Z_]" val)
      (setq val (concat (substring val 0 1) "NAME")))
     ((string-match "^[$@]\\([a-zA-Z_:0-9]+\\)[ \t]*\\[" val)
      (setq val (concat "@" (substring val 1 (match-end 1)))))
     ((string-match "^[$@]\\([a-zA-Z_:0-9]+\\)[ \t]*{" val)
      (setq val (concat "%" (substring val 1 (match-end 1)))))
     ((and (string= val "x") (string-match "^x=" val))
      (setq val "x="))
     ((string-match "^\\$[\C-a-\C-z]" val)
      (setq val (concat "$^" (char-to-string (+ ?A -1 (aref val 1))))))
     ((string-match "^CORE::" val)
      (setq val "CORE::"))
     ((string-match "^SUPER::" val)
      (setq val "SUPER::"))
     ((and (string= "<" val) (string-match "^<\\$?[a-zA-Z0-9_:]+>" val))
      (setq val "<NAME>")))
    (setq regexp (concat "^"
			 "\\([^a-zA-Z0-9_:]+[ \t]+\\)?"
			 (regexp-quote val)
			 "\\([ \t([/]\\|$\\)"))

    ;; get the buffer with the documentation text
    (kurila-switch-to-doc-buffer)

    ;; lookup in the doc
    (goto-char (point-min))
    (let ((case-fold-search nil))
      (list
       (if (re-search-forward regexp (point-max) t)
	   (save-excursion
	     (beginning-of-line 1)
	     (let ((lnstart (point)))
	       (end-of-line)
	       (message "%s" (buffer-substring lnstart (point)))))
	 (if kurila-message-on-help-error
	     (message "No definition for %s" val)))))))

(defvar kurila-short-docs 'please-ignore-this-line
  ;; Perl4 version was written by Johan Vromans (jvromans@squirrel.nl)
  "# based on '@(#)@ perl-descr.el 1.9 - describe-perl-symbol' [Perl 5]
...	Range (list context); flip/flop [no flop when flip] (scalar context).
! ...	Logical negation.
... != ...	Numeric inequality.
... !~ ...	Search pattern, substitution, or translation (negated).
$!	In numeric context: errno.  In a string context: error string.
$\"	The separator which joins elements of arrays interpolated in strings.
$#	The output format for printed numbers.  Default is %.15g or close.
$$	Process number of this script.  Changes in the fork()ed child process.
$%	The current page number of the currently selected output channel.

	The following variables are always local to the current block:

$1	Match of the 1st set of parentheses in the last match (auto-local).
$2	Match of the 2nd set of parentheses in the last match (auto-local).
$3	Match of the 3rd set of parentheses in the last match (auto-local).
$4	Match of the 4th set of parentheses in the last match (auto-local).
$5	Match of the 5th set of parentheses in the last match (auto-local).
$6	Match of the 6th set of parentheses in the last match (auto-local).
$7	Match of the 7th set of parentheses in the last match (auto-local).
$8	Match of the 8th set of parentheses in the last match (auto-local).
$9	Match of the 9th set of parentheses in the last match (auto-local).
$&	The string matched by the last pattern match (auto-local).
$'	The string after what was matched by the last match (auto-local).
$`	The string before what was matched by the last match (auto-local).

$(	The real gid of this process.
$)	The effective gid of this process.
$*	Deprecated: Set to 1 to do multiline matching within a string.
$+	The last bracket matched by the last search pattern.
$,	The output field separator for the print operator.
$-	The number of lines left on the page.
$.	The current input line number of the last filehandle that was read.
$/	The input record separator, newline by default.
$0	Name of the file containing the current perl script (read/write).
$:     String may be broken after these characters to fill ^-lines in a format.
$;	Subscript separator for multi-dim array emulation.  Default \"\\034\".
$<	The real uid of this process.
$=	The page length of the current output channel.  Default is 60 lines.
$>	The effective uid of this process.
$?	The status returned by the last ``, pipe close or `system'.
$@	The perl error message from the last eval or do @var{EXPR} command.
$ARGV	The name of the current file used with <> .
$[	Deprecated: The index of the first element/char in an array/string.
$\\	The output record separator for the print operator.
$]	The perl version string as displayed with perl -v.
$^	The name of the current top-of-page format.
$^A     The current value of the write() accumulator for format() lines.
$^D	The value of the perl debug (-D) flags.
$^E     Information about the last system error other than that provided by $!.
$^F	The highest system file descriptor, ordinarily 2.
$^H     The current set of syntax checks enabled by `use strict'.
$^I	The value of the in-place edit extension (perl -i option).
$^L     What formats output to perform a formfeed.  Default is \f.
$^M     A buffer for emergency memory allocation when running out of memory.
$^O     The operating system name under which this copy of Perl was built.
$^P	Internal debugging flag.
$^T	The time the script was started.  Used by -A/-M/-C file tests.
$^W	True if warnings are requested (perl -w flag).
$^X	The name under which perl was invoked (argv[0] in C-speech).
$_	The default input and pattern-searching space.
$|	Auto-flush after write/print on current output channel?  Default 0.
$~	The name of the current report format.
... % ...	Modulo division.
... %= ...	Modulo division assignment.
%ENV	Contains the current environment.
%INC	List of files that have been require-d or do-ne.
%SIG	Used to set signal handlers for various signals.
... & ...	Bitwise and.
... && ...	Logical and.
... &&= ...	Logical and assignment.
... &= ...	Bitwise and assignment.
... * ...	Multiplication.
... ** ...	Exponentiation.
*NAME	Glob: all objects refered by NAME.  *NAM1 = *NAM2 aliases NAM1 to NAM2.
&NAME(arg0, ...)	Subroutine call.  Arguments go to @_.
... + ...	Addition.		+EXPR	Makes EXPR into scalar context.
++	Auto-increment (magical on strings).	++EXPR	EXPR++
... += ...	Addition assignment.
,	Comma operator.
... - ...	Subtraction.
--	Auto-decrement (NOT magical on strings).	--EXPR	EXPR--
... -= ...	Subtraction assignment.
-A	Access time in days since script started.
-B	File is a non-text (binary) file.
-C	Inode change time in days since script started.
-M	Age in days since script started.
-O	File is owned by real uid.
-R	File is readable by real uid.
-S	File is a socket .
-T	File is a text file.
-W	File is writable by real uid.
-X	File is executable by real uid.
-b	File is a block special file.
-c	File is a character special file.
-d	File is a directory.
-e	File exists .
-f	File is a plain file.
-g	File has setgid bit set.
-k	File has sticky bit set.
-l	File is a symbolic link.
-o	File is owned by effective uid.
-p	File is a named pipe (FIFO).
-r	File is readable by effective uid.
-s	File has non-zero size.
-t	Tests if filehandle (STDIN by default) is opened to a tty.
-u	File has setuid bit set.
-w	File is writable by effective uid.
-x	File is executable by effective uid.
-z	File has zero size.
.	Concatenate strings.
..	Range (list context); flip/flop (scalar context) operator.
.=	Concatenate assignment strings
... / ...	Division.	/PATTERN/ioxsmg	Pattern match
... /= ...	Division assignment.
/PATTERN/ioxsmg	Pattern match.
... < ...    Numeric less than.	<pattern>	Glob.	See <NAME>, <> as well.
<NAME>	Reads line from filehandle NAME (a bareword or dollar-bareword).
<pattern>	Glob (Unless pattern is bareword/dollar-bareword - see <NAME>).
<>	Reads line from union of files in @ARGV (= command line) and STDIN.
... << ...	Bitwise shift left.	<<	start of HERE-DOCUMENT.
... <= ...	Numeric less than or equal to.
... <=> ...	Numeric compare.
... = ...	Assignment.
... == ...	Numeric equality.
... =~ ...	Search pattern, substitution, or translation
... > ...	Numeric greater than.
... >= ...	Numeric greater than or equal to.
... >> ...	Bitwise shift right.
... >>= ...	Bitwise shift right assignment.
... ? ... : ...	Condition=if-then-else operator.   ?PAT? One-time pattern match.
?PATTERN?	One-time pattern match.
@ARGV	Command line arguments (not including the command name - see $0).
$^INCLUDE_PATH	List of places to look for perl scripts during do/include/use.
@_    Parameter array for subroutines; result of split() unless in list context.
\\  Creates reference to what follows, like \$var, or quotes non-\w in strings.
\\0	Octal char, e.g. \\033.
\\E	Case modification terminator.  See \\Q, \\L, and \\U.
\\L	Lowercase until \\E .  See also \\l, lc.
\\U	Upcase until \\E .  See also \\u, uc.
\\Q	Quote metacharacters until \\E .  See also quotemeta.
\\a	Alarm character (octal 007).
\\b	Backspace character (octal 010).
\\c	Control character, e.g. \\c[ .
\\e	Escape character (octal 033).
\\f	Formfeed character (octal 014).
\\l	Lowercase the next character.  See also \\L and \\u, lcfirst.
\\n	Newline character (octal 012 on most systems).
\\r	Return character (octal 015 on most systems).
\\t	Tab character (octal 011).
\\u	Upcase the next character.  See also \\U and \\l, ucfirst.
\\x	Hex character, e.g. \\x1b.
... ^ ...	Bitwise exclusive or.
__END__	Ends program source.
__DATA__	Ends program source.
__FILE__	Current (source) filename.
__LINE__	Current line in current source.
__PACKAGE__	Current package.
ARGV	Default multi-file input filehandle.  <ARGV> is a synonym for <>.
ARGVOUT	Output filehandle with -i flag.
BEGIN { ... }	Immediately executed (during compilation) piece of code.
END { ... }	Pseudo-subroutine executed after the script finishes.
CHECK { ... }	Pseudo-subroutine executed after the script is compiled.
INIT { ... }	Pseudo-subroutine executed before the script starts running.
DATA	Input filehandle for what follows after __END__	or __DATA__.
accept(NEWSOCKET,GENERICSOCKET)
alarm(SECONDS)
atan2(X,Y)
bind(SOCKET,NAME)
binmode(FILEHANDLE)
caller[(LEVEL)]
chdir(EXPR)
chmod(LIST)
chop[(LIST|VAR)]
chown(LIST)
chroot(FILENAME)
close(FILEHANDLE)
closedir(DIRHANDLE)
... cmp ...	String compare.
connect(SOCKET,NAME)
continue of { block } continue { block }.  Is executed after `next' or at end.
cos(EXPR)
crypt(PLAINTEXT,SALT)
dbmclose(%HASH)
dbmopen(%HASH,DBNAME,MODE)
defined(EXPR)
delete($HASH{KEY})
die(LIST)
do { ... }|SUBR while|until EXPR	executes at least once
do(EXPR|SUBR([LIST]))	(with while|until executes at least once)
dump LABEL
each(%HASH)
endgrent
endhostent
endnetent
endprotoent
endpwent
endservent
eof[([FILEHANDLE])]
... eq ...	String equality.
eval(EXPR) or eval { BLOCK }
exec([TRUENAME] ARGV0, ARGVs)     or     exec(SHELL_COMMAND_LINE)
exit(EXPR)
exp(EXPR)
fcntl(FILEHANDLE,FUNCTION,SCALAR)
fileno(FILEHANDLE)
flock(FILEHANDLE,OPERATION)
for (EXPR;EXPR;EXPR) { ... }
foreach [VAR] (@ARRAY) { ... }
fork
... ge ...	String greater than or equal.
getc[(FILEHANDLE)]
getgrent
getgrgid(GID)
getgrnam(NAME)
gethostbyaddr(ADDR,ADDRTYPE)
gethostbyname(NAME)
gethostent
getlogin
getnetbyaddr(ADDR,ADDRTYPE)
getnetbyname(NAME)
getnetent
getpeername(SOCKET)
getpgrp(PID)
getppid
getpriority(WHICH,WHO)
getprotobyname(NAME)
getprotobynumber(NUMBER)
getprotoent
getpwent
getpwnam(NAME)
getpwuid(UID)
getservbyname(NAME,PROTO)
getservbyport(PORT,PROTO)
getservent
getsockname(SOCKET)
getsockopt(SOCKET,LEVEL,OPTNAME)
gmtime(EXPR)
goto LABEL
... gt ...	String greater than.
hex(EXPR)
if (EXPR) { ... } [ elsif (EXPR) { ... } ... ] [ else { ... } ] or EXPR if EXPR
index(STR,SUBSTR[,OFFSET])
int(EXPR)
ioctl(FILEHANDLE,FUNCTION,SCALAR)
join(EXPR,LIST)
keys(%HASH)
kill(LIST)
last [LABEL]
... le ...	String less than or equal.
length(EXPR)
link(OLDFILE,NEWFILE)
listen(SOCKET,QUEUESIZE)
local(LIST)
localtime(EXPR)
log(EXPR)
lstat(EXPR|FILEHANDLE|VAR)
... lt ...	String less than.
m/PATTERN/iogsmx
mkdir(FILENAME,MODE)
msgctl(ID,CMD,ARG)
msgget(KEY,FLAGS)
msgrcv(ID,VAR,SIZE,TYPE.FLAGS)
msgsnd(ID,MSG,FLAGS)
my VAR or my (VAR1,...)	Introduces a lexical variable ($VAR, @ARR, or %HASH).
our VAR or our (VAR1,...) Lexically enable a global variable ($V, @A, or %H).
... ne ...	String inequality.
next [LABEL]
oct(EXPR)
open(FILEHANDLE[,EXPR])
opendir(DIRHANDLE,EXPR)
ord(EXPR)	ASCII value of the first char of the string.
pack(TEMPLATE,LIST)
package NAME	Introduces package context.
pipe(READHANDLE,WRITEHANDLE)	Create a pair of filehandles on ends of a pipe.
pop(ARRAY)
print [FILEHANDLE] [(LIST)]
printf [FILEHANDLE] (FORMAT,LIST)
push(ARRAY,LIST)
q/STRING/	Synonym for 'STRING'
qq/STRING/	Synonym for \"STRING\"
qx/STRING/	Synonym for `STRING`
rand[(EXPR)]
read(FILEHANDLE,SCALAR,LENGTH[,OFFSET])
readdir(DIRHANDLE)
readlink(EXPR)
recv(SOCKET,SCALAR,LEN,FLAGS)
redo [LABEL]
rename(OLDNAME,NEWNAME)
require [FILENAME | PERL_VERSION]
reset[(EXPR)]
return(LIST)
reverse(LIST)
rewinddir(DIRHANDLE)
rindex(STR,SUBSTR[,OFFSET])
rmdir(FILENAME)
s/PATTERN/REPLACEMENT/gieoxsm
scalar(EXPR)
seek(FILEHANDLE,POSITION,WHENCE)
seekdir(DIRHANDLE,POS)
select(FILEHANDLE | RBITS,WBITS,EBITS,TIMEOUT)
semctl(ID,SEMNUM,CMD,ARG)
semget(KEY,NSEMS,SIZE,FLAGS)
semop(KEY,...)
send(SOCKET,MSG,FLAGS[,TO])
setgrent
sethostent(STAYOPEN)
setnetent(STAYOPEN)
setpgrp(PID,PGRP)
setpriority(WHICH,WHO,PRIORITY)
setprotoent(STAYOPEN)
setpwent
setservent(STAYOPEN)
setsockopt(SOCKET,LEVEL,OPTNAME,OPTVAL)
shift[(ARRAY)]
shmctl(ID,CMD,ARG)
shmget(KEY,SIZE,FLAGS)
shmread(ID,VAR,POS,SIZE)
shmwrite(ID,STRING,POS,SIZE)
shutdown(SOCKET,HOW)
sin(EXPR)
sleep[(EXPR)]
socket(SOCKET,DOMAIN,TYPE,PROTOCOL)
socketpair(SOCKET1,SOCKET2,DOMAIN,TYPE,PROTOCOL)
sort [SUBROUTINE] (LIST)
splice(ARRAY,OFFSET[,LENGTH[,LIST]])
split[(/PATTERN/[,EXPR[,LIMIT]])]
sprintf(FORMAT,LIST)
sqrt(EXPR)
srand(EXPR)
stat(EXPR|FILEHANDLE|VAR)
study[(SCALAR)]
sub [NAME [(format)]] { BODY }	sub NAME [(format)];	sub [(format)] {...}
substr(EXPR,OFFSET[,LEN])
symlink(OLDFILE,NEWFILE)
syscall(LIST)
sysread(FILEHANDLE,SCALAR,LENGTH[,OFFSET])
system([TRUENAME] ARGV0 [,ARGV])     or     system(SHELL_COMMAND_LINE)
syswrite(FILEHANDLE,SCALAR,LENGTH[,OFFSET])
tell[(FILEHANDLE)]
telldir(DIRHANDLE)
time
times
tr/SEARCHLIST/REPLACEMENTLIST/cds
truncate(FILE|EXPR,LENGTH)
umask[(EXPR)]
undef[(EXPR)]
unless (EXPR) { ... } [ else { ... } ] or EXPR unless EXPR
unlink(LIST)
unpack(TEMPLATE,EXPR)
unshift(ARRAY,LIST)
until (EXPR) { ... }					EXPR until EXPR
utime(LIST)
values(%HASH)
vec(EXPR,OFFSET,BITS)
wait
waitpid(PID,FLAGS)
wantarray	Returns true if the sub/eval is called in list context.
warn(LIST)
while  (EXPR) { ... }					EXPR while EXPR
write[(EXPR|FILEHANDLE)]
... x ...	Repeat string or array.
x= ...	Repetition assignment.
y/SEARCHLIST/REPLACEMENTLIST/
... | ...	Bitwise or.
... || ...	Logical or.
~ ...		Unary bitwise complement.
#!	OS interpreter indicator.  If contains `perl', used for options, and -x.
AUTOLOAD {...}	Shorthand for `sub AUTOLOAD {...}'.
CORE::		Prefix to access builtin function if imported sub obscures it.
SUPER::		Prefix to lookup for a method in @ISA classes.
DESTROY		Shorthand for `sub DESTROY {...}'.
... EQ ...	Obsolete synonym of `eq'.
... GE ...	Obsolete synonym of `ge'.
... GT ...	Obsolete synonym of `gt'.
... LE ...	Obsolete synonym of `le'.
... LT ...	Obsolete synonym of `lt'.
... NE ...	Obsolete synonym of `ne'.
abs [ EXPR ]	absolute value
... and ...		Low-precedence synonym for &&.
bless REFERENCE [, PACKAGE]	Makes reference into an object of a package.
chomp [LIST]	Strips $/ off LIST/$_.  Returns count.  Special if $/ eq ''!
chr		Converts a number to char with the same ordinal.
else		Part of if/unless {BLOCK} elsif {BLOCK} else {BLOCK}.
elsif		Part of if/unless {BLOCK} elsif {BLOCK} else {BLOCK}.
exists $HASH{KEY}	True if the key exists.
format [NAME] =	 Start of output format.  Ended by a single dot (.) on a line.
formline PICTURE, LIST	Backdoor into \"format\" processing.
glob EXPR	Synonym of <EXPR>.
lc [ EXPR ]	Returns lowercased EXPR.
lcfirst [ EXPR ]	Returns EXPR with lower-cased first letter.
grep EXPR,LIST  or grep {BLOCK} LIST	Filters LIST via EXPR/BLOCK.
map EXPR, LIST	or map {BLOCK} LIST	Applies EXPR/BLOCK to elts of LIST.
no PACKAGE [SYMBOL1, ...]  Partial reverse for `use'.  Runs `unimport' method.
not ...		Low-precedence synonym for ! - negation.
... or ...		Low-precedence synonym for ||.
pos STRING    Set/Get end-position of the last match over this string, see \\G.
quotemeta [ EXPR ]	Quote regexp metacharacters.
qw/WORD1 .../		Synonym of split('', 'WORD1 ...')
readline FH	Synonym of <FH>.
readpipe CMD	Synonym of `CMD`.
ref [ EXPR ]	Type of EXPR when dereferenced.
sysopen FH, FILENAME, MODE [, PERM]	(MODE is numeric, see Fcntl.)
tie VAR, PACKAGE, LIST	Hide an object behind a simple Perl variable.
tied		Returns internal object for a tied data.
uc [ EXPR ]	Returns upcased EXPR.
ucfirst [ EXPR ]	Returns EXPR with upcased first letter.
untie VAR	Unlink an object from a simple Perl variable.
use PACKAGE [SYMBOL1, ...]  Compile-time `require' with consequent `import'.
... xor ...		Low-precedence synonym for exclusive or.
prototype \&SUB	Returns prototype of the function given a reference.
=head1		Top-level heading.
=head2		Second-level heading.
=head3		Third-level heading (is there such?).
=over [ NUMBER ]	Start list.
=item [ TITLE ]		Start new item in the list.
=back		End list.
=cut		Switch from POD to Perl.
=pod		Switch from Perl to POD.
")

(defun kurila-switch-to-doc-buffer ()
  "Go to the perl documentation buffer and insert the documentation."
  (interactive)
  (let ((buf (get-buffer-create kurila-doc-buffer)))
    (if (interactive-p)
	(switch-to-buffer-other-window buf)
      (set-buffer buf))
    (if (= (buffer-size) 0)
	(progn
	  (insert (documentation-property 'kurila-short-docs
					  'variable-documentation))
	  (setq buffer-read-only t)))))

(defun kurila-beautify-regexp-piece (b e embed level)
  ;; b is before the starting delimiter, e before the ending
  ;; e should be a marker, may be changed, but remains "correct".
  ;; EMBED is nil iff we process the whole REx.
  ;; The REx is guaranteed to have //x
  ;; LEVEL shows how many levels deep to go
  ;; position at enter and at leave is not defined
  (let (s c tmp (m (make-marker)) (m1 (make-marker)) c1 spaces inline code pos)
    (if (not embed)
	(goto-char (1+ b))
      (goto-char b)
      (cond ((looking-at "(\\?\\\\#")	;  (?#) wrongly commented when //x-ing
	     (forward-char 2)
	     (delete-char 1)
	     (forward-char 1))
	    ((looking-at "(\\?[^a-zA-Z]")
	     (forward-char 3))
	    ((looking-at "(\\?")	; (?i)
	     (forward-char 2))
	    (t
	     (forward-char 1))))
    (setq c (if embed (current-indentation) (1- (current-column)))
	  c1 (+ c (or kurila-regexp-indent-step kurila-indent-level)))
    (or (looking-at "[ \t]*[\n#]")
	(progn
	  (insert "\n")))
    (goto-char e)
    (beginning-of-line)
    (if (re-search-forward "[^ \t]" e t)
	(progn			       ; Something before the ending delimiter
	  (goto-char e)
	  (delete-horizontal-space)
	  (insert "\n")
	  (kurila-make-indent c)
	  (set-marker e (point))))
    (goto-char b)
    (end-of-line 2)
    (while (< (point) (marker-position e))
      (beginning-of-line)
      (setq s (point)
	    inline t)
      (skip-chars-forward " \t")
      (delete-region s (point))
      (kurila-make-indent c1)
      (while (and
	      inline
	      (looking-at
	       (concat "\\([a-zA-Z0-9]+[^*+{?]\\)" ; 1 word
		       "\\|"		; Embedded variable
		       "\\$\\([a-zA-Z0-9_]+\\([[{]\\)?\\|[^\n \t)|]\\)" ; 2 3
		       "\\|"		; $ ^
		       "[$^]"
		       "\\|"		; simple-code simple-code*?
		       "\\(\\\\.\\|[^][()#|*+?\n]\\)\\([*+{?]\\??\\)?" ; 4 5
		       "\\|"		; Class
		       "\\(\\[\\)"	; 6
		       "\\|"		; Grouping
		       "\\((\\(\\?\\)?\\)" ; 7 8
		       "\\|"		; |
		       "\\(|\\)")))	; 9
	(goto-char (match-end 0))
	(setq spaces t)
	(cond ((match-beginning 1)	; Alphanum word + junk
	       (forward-char -1))
	      ((or (match-beginning 3)	; $ab[12]
		   (and (match-beginning 5) ; X* X+ X{2,3}
			(eq (preceding-char) ?\{)))
	       (forward-char -1)
	       (forward-sexp 1))
	      ((and			; [], already syntaxified
		(match-beginning 6)
		kurila-regexp-scan
		kurila-use-syntax-table-text-property)
	       (forward-char -1)
	       (forward-sexp 1)
	       (or (eq (preceding-char) ?\])
		   (error "[]-group not terminated"))
	       (re-search-forward
		"\\=\\([*+?]\\|{[0-9]+\\(,[0-9]*\\)?}\\)\\??" e t))
	      ((match-beginning 6)	; []
	       (setq tmp (point))
	       (if (looking-at "\\^?\\]")
		   (goto-char (match-end 0)))
	       ;; XXXX POSIX classes?!
	       (while (and (not pos)
			   (re-search-forward "\\[:\\|\\]" e t))
		 (if (eq (preceding-char) ?:)
		     (or (re-search-forward ":\\]" e t)
			 (error "[:POSIX:]-group in []-group not terminated"))
		   (setq pos t)))
	       (or (eq (preceding-char) ?\])
		   (error "[]-group not terminated"))
	       (re-search-forward
		"\\=\\([*+?]\\|{[0-9]+\\(,[0-9]*\\)?}\\)\\??" e t))
	      ((match-beginning 7)	; ()
	       (goto-char (match-beginning 0))
	       (setq pos (current-column))
	       (or (eq pos c1)
		   (progn
		     (delete-horizontal-space)
		     (insert "\n")
		     (kurila-make-indent c1)))
	       (setq tmp (point))
	       (forward-sexp 1)
	       ;;	       (or (forward-sexp 1)
	       ;;		   (progn
	       ;;		     (goto-char tmp)
	       ;;		     (error "()-group not terminated")))
	       (set-marker m (1- (point)))
	       (set-marker m1 (point))
	       (if (= level 1)
		   (if (progn		; indent rigidly if multiline
			 ;; In fact does not make a lot of sense, since
			 ;; the starting position can be already lost due
			 ;; to insertion of "\n" and " "
			 (goto-char tmp)
			 (search-forward "\n" m1 t))
		       (indent-rigidly (point) m1 (- c1 pos)))
		 (setq level (1- level))
		 (cond
		  ((not (match-beginning 8))
		   (kurila-beautify-regexp-piece tmp m t level))
		  ((eq (char-after (+ 2 tmp)) ?\{) ; Code
		   t)
		  ((eq (char-after (+ 2 tmp)) ?\() ; Conditional
		   (goto-char (+ 2 tmp))
		   (forward-sexp 1)
		   (kurila-beautify-regexp-piece (point) m t level))
		  ((eq (char-after (+ 2 tmp)) ?<) ; Lookbehind
		   (goto-char (+ 3 tmp))
		   (kurila-beautify-regexp-piece (point) m t level))
		  (t
		   (kurila-beautify-regexp-piece tmp m t level))))
	       (goto-char m1)
	       (cond ((looking-at "[*+?]\\??")
		      (goto-char (match-end 0)))
		     ((eq (following-char) ?\{)
		      (forward-sexp 1)
		      (if (eq (following-char) ?\?)
			  (forward-char))))
	       (skip-chars-forward " \t")
	       (setq spaces nil)
	       (if (looking-at "[#\n]")
		   (progn
		     (or (eolp) (indent-for-comment))
		     (beginning-of-line 2))
		 (delete-horizontal-space)
		 (insert "\n"))
	       (end-of-line)
	       (setq inline nil))
	      ((match-beginning 9)	; |
	       (forward-char -1)
	       (setq tmp (point))
	       (beginning-of-line)
	       (if (re-search-forward "[^ \t]" tmp t)
		   (progn
		     (goto-char tmp)
		     (delete-horizontal-space)
		     (insert "\n"))
		 ;; first at line
		 (delete-region (point) tmp))
	       (kurila-make-indent c)
	       (forward-char 1)
	       (skip-chars-forward " \t")
	       (setq spaces nil)
	       (if (looking-at "[#\n]")
		   (beginning-of-line 2)
		 (delete-horizontal-space)
		 (insert "\n"))
	       (end-of-line)
	       (setq inline nil)))
	(or (looking-at "[ \t\n]")
	    (not spaces)
	    (insert " "))
	(skip-chars-forward " \t"))
      (or (looking-at "[#\n]")
	  (error "Unknown code `%s' in a regexp"
		 (buffer-substring (point) (1+ (point)))))
      (and inline (end-of-line 2)))
    ;; Special-case the last line of group
    (if (and (>= (point) (marker-position e))
	     (/= (current-indentation) c))
	(progn
	  (beginning-of-line)
	  (kurila-make-indent c)))))

(defun kurila-make-regexp-x ()
  ;; Returns position of the start
  ;; XXX this is called too often!  Need to cache the result!
  (save-excursion
    (or kurila-use-syntax-table-text-property
	(error "I need to have a regexp marked!"))
    ;; Find the start
    (if (looking-at "\\s|")
	nil				; good already
      (if (looking-at "\\([smy]\\|qr\\)\\s|")
	  (forward-char 1)
	(re-search-backward "\\s|")))	; Assume it is scanned already.
    ;;(forward-char 1)
    (let ((b (point)) (e (make-marker)) have-x delim (c (current-column))
	  (sub-p (eq (preceding-char) ?s)) s)
      (forward-sexp 1)
      (set-marker e (1- (point)))
      (setq delim (preceding-char))
      (if (and sub-p (eq delim (char-after (- (point) 2))))
	  (error "Possible s/blah// - do not know how to deal with"))
      (if sub-p (forward-sexp 1))
      (if (looking-at "\\sw*x")
	  (setq have-x t)
	(insert "x"))
      ;; Protect fragile " ", "#"
      (if have-x nil
	(goto-char (1+ b))
	(while (re-search-forward "\\(\\=\\|[^\\\\]\\)\\(\\\\\\\\\\)*[ \t\n#]" e t) ; Need to include (?#) too?
	  (forward-char -1)
	  (insert "\\")
	  (forward-char 1)))
      b)))

(defun kurila-beautify-regexp (&optional deep)
  "Do it.  (Experimental, may change semantics, recheck the result.)
We suppose that the regexp is scanned already."
  (interactive "P")
  (setq deep (if deep (prefix-numeric-value deep) -1))
  (save-excursion
    (goto-char (kurila-make-regexp-x))
    (let ((b (point)) (e (make-marker)))
      (forward-sexp 1)
      (set-marker e (1- (point)))
      (kurila-beautify-regexp-piece b e nil deep))))

(defun kurila-regext-to-level-start ()
  "Goto start of an enclosing group in regexp.
We suppose that the regexp is scanned already."
  (interactive)
  (let ((limit (kurila-make-regexp-x)) done)
    (while (not done)
      (or (eq (following-char) ?\()
	  (search-backward "(" (1+ limit) t)
	  (error "Cannot find `(' which starts a group"))
      (setq done
	    (save-excursion
	      (skip-chars-backward "\\")
	      (looking-at "\\(\\\\\\\\\\)*(")))
      (or done (forward-char -1)))))

(defun kurila-contract-level ()
  "Find an enclosing group in regexp and contract it.
\(Experimental, may change semantics, recheck the result.)
We suppose that the regexp is scanned already."
  (interactive)
  ;; (save-excursion		; Can't, breaks `kurila-contract-levels'
  (kurila-regext-to-level-start)
  (let ((b (point)) (e (make-marker)) c)
    (forward-sexp 1)
    (set-marker e (1- (point)))
    (goto-char b)
    (while (re-search-forward "\\(#\\)\\|\n" e 'to-end)
      (cond
       ((match-beginning 1)		; #-comment
	(or c (setq c (current-indentation)))
	(beginning-of-line 2)		; Skip
	(kurila-make-indent c))
       (t
	(delete-char -1)
	(just-one-space))))))

(defun kurila-contract-levels ()
  "Find an enclosing group in regexp and contract all the kids.
\(Experimental, may change semantics, recheck the result.)
We suppose that the regexp is scanned already."
  (interactive)
  (save-excursion
    (condition-case nil
	(kurila-regext-to-level-start)
      (error				; We are outside outermost group
       (goto-char (kurila-make-regexp-x))))
    (let ((b (point)) (e (make-marker)) s c)
      (forward-sexp 1)
      (set-marker e (1- (point)))
      (goto-char (1+ b))
      (while (re-search-forward "\\(\\\\\\\\\\)\\|(" e t)
	(cond
	 ((match-beginning 1)		; Skip
	  nil)
	 (t				; Group
	  (kurila-contract-level)))))))

(defun kurila-beautify-level (&optional deep)
  "Find an enclosing group in regexp and beautify it.
\(Experimental, may change semantics, recheck the result.)
We suppose that the regexp is scanned already."
  (interactive "P")
  (setq deep (if deep (prefix-numeric-value deep) -1))
  (save-excursion
    (kurila-regext-to-level-start)
    (let ((b (point)) (e (make-marker)))
      (forward-sexp 1)
      (set-marker e (1- (point)))
      (kurila-beautify-regexp-piece b e nil deep))))

;;; By Anthony Foiani <afoiani@uswest.com>
;;; Getting help on modules in C-h f ?
;;; This is a modified version of `man'.
;;; Need to teach it how to lookup functions
;;;###autoload
(defun kurila-perldoc (word)
  "Run `perldoc' on WORD."
  (interactive
   (list (let* ((default-entry (kurila-word-at-point))
                (input (read-string
                        (format "perldoc entry%s: "
                                (if (string= default-entry "")
                                    ""
                                  (format " (default %s)" default-entry))))))
           (if (string= input "")
               (if (string= default-entry "")
                   (error "No perldoc args given")
                 default-entry)
             input))))
  (require 'man)
  (let* ((case-fold-search nil)
	 (is-func (and
		   (string-match "^[a-z]+$" word)
		   (string-match (concat "^" word "\\>")
				 (documentation-property
				  'kurila-short-docs
				  'variable-documentation))))
	 (manual-program (if is-func "perldoc -f" "perldoc")))
    (cond
     (kurila-xemacs-p
      (let ((Manual-program "perldoc")
	    (Manual-switches (if is-func (list "-f"))))
	(manual-entry word)))
     (t
      (Man-getpage-in-background word)))))

;;;###autoload
(defun kurila-perldoc-at-point ()
  "Run a `perldoc' on the word around point."
  (interactive)
  (kurila-perldoc (kurila-word-at-point)))

(defcustom pod2man-program "pod2man"
  "*File name for `pod2man'."
  :type 'file
  :group 'kurila)

;;; By Nick Roberts <Nick.Roberts@src.bae.co.uk> (with changes)
(defun kurila-pod-to-manpage ()
  "Create a virtual manpage in Emacs from the Perl Online Documentation."
  (interactive)
  (require 'man)
  (let* ((pod2man-args (concat buffer-file-name " | nroff -man "))
	 (bufname (concat "Man " buffer-file-name))
	 (buffer (generate-new-buffer bufname)))
    (save-excursion
      (set-buffer buffer)
      (let ((process-environment (copy-sequence process-environment)))
        ;; Prevent any attempt to use display terminal fanciness.
        (setenv "TERM" "dumb")
        (set-process-sentinel
         (start-process pod2man-program buffer "sh" "-c"
                        (format (kurila-pod2man-build-command) pod2man-args))
         'Man-bgproc-sentinel)))))

;;; Updated version by him too
(defun kurila-build-manpage ()
  "Create a virtual manpage in Emacs from the POD in the file."
  (interactive)
  (require 'man)
  (cond
   (kurila-xemacs-p
    (let ((Manual-program "perldoc"))
      (manual-entry buffer-file-name)))
   (t
    (let* ((manual-program "perldoc"))
      (Man-getpage-in-background buffer-file-name)))))

(defun kurila-pod2man-build-command ()
  "Builds the entire background manpage and cleaning command."
  (let ((command (concat pod2man-program " %s 2>/dev/null"))
        (flist (and (boundp 'Man-filter-list) Man-filter-list)))
    (while (and flist (car flist))
      (let ((pcom (car (car flist)))
            (pargs (cdr (car flist))))
        (setq command
              (concat command " | " pcom " "
                      (mapconcat '(lambda (phrase)
                                    (if (not (stringp phrase))
                                        (error "Malformed Man-filter-list"))
                                    phrase)
                                 pargs " ")))
        (setq flist (cdr flist))))
    command))


(defun kurila-next-interpolated-REx-1 ()
  "Move point to next REx which has interpolated parts without //o.
Skips RExes consisting of one interpolated variable.

Note that skipped RExen are not performance hits."
  (interactive "")
  (kurila-next-interpolated-REx 1))

(defun kurila-next-interpolated-REx-0 ()
  "Move point to next REx which has interpolated parts without //o."
  (interactive "")
  (kurila-next-interpolated-REx 0))

(defun kurila-next-interpolated-REx (&optional skip beg limit)
  "Move point to next REx which has interpolated parts.
SKIP is a list of possible types to skip, BEG and LIMIT are the starting
point and the limit of search (default to point and end of buffer).

SKIP may be a number, then it behaves as list of numbers up to SKIP; this
semantic may be used as a numeric argument.

Types are 0 for / $rex /o (interpolated once), 1 for /$rex/ (if $rex is
a result of qr//, this is not a performance hit), t for the rest."
  (interactive "P")
  (if (numberp skip) (setq skip (list 0 skip)))
  (or beg (setq beg (point)))
  (or limit (setq limit (point-max)))	; needed for n-s-p-c
  (let (pp)
    (and (eq (get-text-property beg 'syntax-type) 'string)
	 (setq beg (next-single-property-change beg 'syntax-type nil limit)))
    (kurila-map-pods-heres
     (function (lambda (s e p)
		 (if (memq (get-text-property s 'REx-interpolated) skip)
		     t
		   (setq pp s)
		   nil)))	; nil stops
     'REx-interpolated beg limit)
    (if pp (goto-char pp)
      (message "No more interpolated REx"))))

;;; Initial version contributed by Trey Belew
(defun kurila-here-doc-spell (&optional beg end)
  "Spell-check HERE-documents in the Perl buffer.
If a region is highlighted, restricts to the region."
  (interactive "")
  (kurila-pod-spell t beg end))

(defun kurila-pod-spell (&optional do-heres beg end)
  "Spell-check POD documentation.
If invoked with prefix argument, will do HERE-DOCs instead.
If a region is highlighted, restricts to the region."
  (interactive "P")
  (save-excursion
    (let (beg end)
      (if (kurila-mark-active)
	  (setq beg (min (mark) (point))
		end (max (mark) (point)))
	(setq beg (point-min)
	      end (point-max)))
      (kurila-map-pods-heres (function
			     (lambda (s e p)
			       (if do-heres
				   (setq e (save-excursion
					     (goto-char e)
					     (forward-line -1)
					     (point))))
			       (ispell-region s e)
			       t))
			    (if do-heres 'here-doc-group 'in-pod)
			    beg end))))

(defun kurila-map-pods-heres (func &optional prop s end)
  "Executes a function over regions of pods or here-documents.
PROP is the text-property to search for; default to `in-pod'.  Stop when
function returns nil."
  (let (pos posend has-prop (cont t))
    (or prop (setq prop 'in-pod))
    (or s (setq s (point-min)))
    (or end (setq end (point-max)))
    (kurila-update-syntaxification end end)
    (save-excursion
      (goto-char (setq pos s))
      (while (and cont (< pos end))
	(setq has-prop (get-text-property pos prop))
	(setq posend (next-single-property-change pos prop nil end))
	(and has-prop
	     (setq cont (funcall func pos posend prop)))
	(setq pos posend)))))

;;; Based on code by Masatake YAMATO:
(defun kurila-get-here-doc-region (&optional pos pod)
  "Return HERE document region around the point.
Return nil if the point is not in a HERE document region.  If POD is non-nil,
will return a POD section if point is in a POD section."
  (or pos (setq pos (point)))
  (kurila-update-syntaxification pos pos)
  (if (or (eq 'here-doc  (get-text-property pos 'syntax-type))
	  (and pod
	       (eq 'pod (get-text-property pos 'syntax-type))))
      (let ((b (kurila-beginning-of-property pos 'syntax-type))
	    (e (next-single-property-change pos 'syntax-type)))
	(cons b (or e (point-max))))))

(defun kurila-narrow-to-here-doc (&optional pos)
  "Narrows editing region to the HERE-DOC at POS.
POS defaults to the point."
  (interactive "d")
  (or pos (setq pos (point)))
  (let ((p (kurila-get-here-doc-region pos)))
    (or p (error "Not inside a HERE document"))
    (narrow-to-region (car p) (cdr p))
    (message
     "When you are finished with narrow editing, type C-x n w")))

(defun kurila-select-this-pod-or-here-doc (&optional pos)
  "Select the HERE-DOC (or POD section) at POS.
POS defaults to the point."
  (interactive "d")
  (let ((p (kurila-get-here-doc-region pos t)))
    (if p
	(progn
	  (goto-char (car p))
	  (push-mark (cdr p) nil t))	; Message, activate in transient-mode
      (message "I do not think POS is in POD or a HERE-doc..."))))

(defun kurila-facemenu-add-face-function (face end)
  "A callback to process user-initiated font-change requests.
Translates `bold', `italic', and `bold-italic' requests to insertion of
corresponding POD directives, and `underline' to C<> POD directive.

Such requests are usually bound to M-o LETTER."
  (or (get-text-property (point) 'in-pod)
      (error "Faces can only be set within POD"))
  (setq facemenu-end-add-face (if (eq face 'bold-italic) ">>" ">"))
  (cdr (or (assq face '((bold . "B<")
			(italic . "I<")
			(bold-italic . "B<I<")
			(underline . "C<")))
	   (error "Face %s not configured for kurila-mode"
		  face))))

(defun kurila-time-fontification (&optional l step lim)
  "Times how long it takes to do incremental fontification in a region.
L is the line to start at, STEP is the number of lines to skip when
doing next incremental fontification, LIM is the maximal number of
incremental fontification to perform.  Messages are accumulated in
*Messages* buffer.

May be used for pinpointing which construct slows down buffer fontification:
start with default arguments, then refine the slowdown regions."
  (interactive "nLine to start at: \nnStep to do incremental fontification: ")
  (or l (setq l 1))
  (or step (setq step 500))
  (or lim (setq lim 40))
  (let* ((timems (function (lambda ()
			     (let ((tt (current-time)))
			       (+ (* 1000 (nth 1 tt)) (/ (nth 2 tt) 1000))))))
	 (tt (funcall timems)) (c 0) delta tot)
    (goto-line l)
    (kurila-mode)
    (setq tot (- (- tt (setq tt (funcall timems)))))
    (message "kurila-mode at %s: %s" l tot)
    (while (and (< c lim) (not (eobp)))
      (forward-line step)
      (setq l (+ l step))
      (setq c (1+ c))
      (kurila-update-syntaxification (point) (point))
      (setq delta (- (- tt (setq tt (funcall timems)))) tot (+ tot delta))
      (message "to %s:%6s,%7s" l delta tot))
    tot))

(defun kurila-emulate-lazy-lock (&optional window-size)
  "Emulate `lazy-lock' without `condition-case', so `debug-on-error' works.
Start fontifying the buffer from the start (or end) using the given
WINDOW-SIZE (units is lines).  Negative WINDOW-SIZE starts at end, and
goes backwards; default is -50.  This function is not Kurila-specific; it
may be used to debug problems with delayed incremental fontification."
  (interactive
   "nSize of window for incremental fontification, negative goes backwards: ")
  (or window-size (setq window-size -50))
  (let ((pos (if (> window-size 0)
		 (point-min)
	       (point-max)))
	p)
    (goto-char pos)
    (normal-mode)
    ;; Why needed???  With older font-locks???
    (set (make-local-variable 'font-lock-cache-position) (make-marker))
    (while (if (> window-size 0)
	       (< pos (point-max))
	     (> pos (point-min)))
      (setq p (progn
		(forward-line window-size)
		(point)))
      (font-lock-fontify-region (min p pos) (max p pos))
      (setq pos p))))


(defun kurila-lazy-install ())		; Avoid a warning
(defun kurila-lazy-unstall ())		; Avoid a warning

(if (fboundp 'run-with-idle-timer)
    (progn
      (defvar kurila-help-shown nil
	"Non-nil means that the help was already shown now.")

      (defvar kurila-lazy-installed nil
	"Non-nil means that the lazy-help handlers are installed now.")

      (defun kurila-lazy-install ()
	"Switches on Auto-Help on Perl constructs (put in the message area).
Delay of auto-help controlled by `kurila-lazy-help-time'."
	(interactive)
	(make-variable-buffer-local 'kurila-help-shown)
	(if (and (kurila-val 'kurila-lazy-help-time)
		 (not kurila-lazy-installed))
	    (progn
	      (add-hook 'post-command-hook 'kurila-lazy-hook)
	      (run-with-idle-timer
	       (kurila-val 'kurila-lazy-help-time 1000000 5)
	       t
	       'kurila-get-help-defer)
	      (setq kurila-lazy-installed t))))

      (defun kurila-lazy-unstall ()
	"Switches off Auto-Help on Perl constructs (put in the message area).
Delay of auto-help controlled by `kurila-lazy-help-time'."
	(interactive)
	(remove-hook 'post-command-hook 'kurila-lazy-hook)
	(cancel-function-timers 'kurila-get-help-defer)
	(setq kurila-lazy-installed nil))

      (defun kurila-lazy-hook ()
	(setq kurila-help-shown nil))

      (defun kurila-get-help-defer ()
	(if (not (memq major-mode '(perl-mode kurila-mode))) nil
	  (let ((kurila-message-on-help-error nil) (kurila-help-from-timer t))
	    (kurila-get-help)
	    (setq kurila-help-shown t))))
      (kurila-lazy-install)))


;;; Plug for wrong font-lock:

(defun kurila-font-lock-unfontify-region-function (beg end)
  (let* ((modified (buffer-modified-p)) (buffer-undo-list t)
	 (inhibit-read-only t) (inhibit-point-motion-hooks t)
	 before-change-functions after-change-functions
	 deactivate-mark buffer-file-name buffer-file-truename)
    (remove-text-properties beg end '(face nil))
    (if (and (not modified) (buffer-modified-p))
      (set-buffer-modified-p nil))))

(defun kurila-font-lock-fontify-region-function (beg end loudly)
  "Extends the region to safe positions, then calls the default function.
Newer `font-lock's can do it themselves.
We unwind only as far as needed for fontification.  Syntaxification may
do extra unwind via `kurila-unwind-to-safe'."
  (save-excursion
    (goto-char beg)
    (while (and beg
		(progn
		  (beginning-of-line)
		  (eq (get-text-property (setq beg (point)) 'syntax-type)
		      'multiline)))
      (if (setq beg (kurila-beginning-of-property beg 'syntax-type))
	  (goto-char beg)))
    (setq beg (point))
    (goto-char end)
    (while (and end
		(progn
		  (or (bolp) (condition-case nil
				 (forward-line 1)
			       (error nil)))
		  (eq (get-text-property (setq end (point)) 'syntax-type)
		      'multiline)))
      (setq end (next-single-property-change end 'syntax-type nil (point-max)))
      (goto-char end))
    (setq end (point)))
  (font-lock-default-fontify-region beg end loudly))

(defvar kurila-d-l nil)
(defun kurila-fontify-syntaxically (end)
  ;; Some vars for debugging only
  ;; (message "Syntaxifying...")
  (let ((dbg (point)) (iend end) (idone kurila-syntax-done-to)
	(istate (car kurila-syntax-state))
	start from-start edebug-backtrace-buffer)
    (if (eq kurila-syntaxify-by-font-lock 'backtrace)
	(progn
	  (require 'edebug)
	  (let ((f 'edebug-backtrace))
	    (funcall f))))	; Avoid compile-time warning
    (or kurila-syntax-done-to
	(setq kurila-syntax-done-to (point-min)
	      from-start t))
    (setq start (if (and kurila-hook-after-change
			 (not from-start))
		    kurila-syntax-done-to ; Fontify without change; ignore start
		  ;; Need to forget what is after `start'
		  (min kurila-syntax-done-to (point))))
    (goto-char start)
    (beginning-of-line)
    (setq start (point))
    (and kurila-syntaxify-unwind
	 (setq end (kurila-unwind-to-safe t end)
	       start (point)))
    (and (> end start)
	 (setq kurila-syntax-done-to start) ; In case what follows fails
	 (kurila-find-pods-heres start end t nil t))
    (if (memq kurila-syntaxify-by-font-lock '(backtrace message))
	(message "Syxify req=%s..%s actual=%s..%s done-to: %s=>%s statepos: %s=>%s"
		 dbg iend start end idone kurila-syntax-done-to
		 istate (car kurila-syntax-state))) ; For debugging
    nil))				; Do not iterate

(defun kurila-fontify-update (end)
  (let ((pos (point-min)) prop posend)
    (setq end (point-max))
    (while (< pos end)
      (setq prop (get-text-property pos 'kurila-postpone)
	    posend (next-single-property-change pos 'kurila-postpone nil end))
      (and prop (put-text-property pos posend (car prop) (cdr prop)))
      (setq pos posend)))
  nil)					; Do not iterate

(defun kurila-fontify-update-bad (end)
  ;; Since fontification happens with different region than syntaxification,
  ;; do to the end of buffer, not to END;;; likewise, start earlier if needed
  (let* ((pos (point)) (prop (get-text-property pos 'kurila-postpone)) posend)
    (if prop
	(setq pos (or (kurila-beginning-of-property
		       (kurila-1+ pos) 'kurila-postpone)
		      (point-min))))
    (while (< pos end)
      (setq posend (next-single-property-change pos 'kurila-postpone))
      (and prop (put-text-property pos posend (car prop) (cdr prop)))
      (setq pos posend)
      (setq prop (get-text-property pos 'kurila-postpone))))
  nil)					; Do not iterate

;; Called when any modification is made to buffer text.
(defun kurila-after-change-function (beg end old-len)
  ;; We should have been informed about changes by `font-lock'.  Since it
  ;; does not inform as which calls are defered, do it ourselves
  (if kurila-syntax-done-to
      (setq kurila-syntax-done-to (min kurila-syntax-done-to beg))))

(defun kurila-update-syntaxification (from to)
  (if (and kurila-use-syntax-table-text-property
	   kurila-syntaxify-by-font-lock
	   (or (null kurila-syntax-done-to)
	       (< kurila-syntax-done-to to)))
      (progn
	(save-excursion
	  (goto-char from)
	  (kurila-fontify-syntaxically to)))))

(defvar kurila-version
  (let ((v  "$Revision: 5.23 $"))
    (string-match ":\\s *\\([0-9.]+\\)" v)
    (substring v (match-beginning 1) (match-end 1)))
  "Version of IZ-supported Kurila package this file is based on.")

(provide 'kurila-mode)

;;; kurila-mode.el ends here
