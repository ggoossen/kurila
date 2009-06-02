
(require 'etest)

(defun kt-simple-buffer ()
  "package Foo::Bar

sub foo()
    'noot'
    return 'bar'
")

(defun kt-buffer-if-block ()
  "package Foo::Bar

sub aap
      'noot'
      'mies'
      if ('mies')
        'wim'
        'zus'
")

(defun kt-buffer-paren ()
  "package Foo::Bar

sub aap
    noot('mies',
         'wim')
")

(defun kt-is (buffer line exp func)
  (save-excursion
    (set-buffer (get-buffer-create "*kurila-indent-test*"))
    (erase-buffer)
    (insert (eval buffer))
    (kurila-mode)
    (kurila-indent-mode)
    (goto-line line)
    (etest-equality-test 'equal exp func)
    )
)

(deftest '(kt-is 4) 'kt-is)

(setq debug-on-error t)

(etest 
 (kt-is (kt-simple-buffer)
        3
        '(0 next-line)
        (kurila-sniff-for-block-start))
 (kt-is (kt-simple-buffer) 
        3
        nil
        (kurila-sniff-for-paren-open))
 (kt-is (kt-simple-buffer)
        4
        [code-start-in-block 0]
        (kurila-sniff-for-indent))
 (kt-is (kt-simple-buffer) 
        4
        '((4))
        (kurila-indent-indentation-info))
 (kt-is (kt-simple-buffer)
        5
        [statement (4 0)]
        (kurila-sniff-for-indent))
 (kt-is (kt-simple-buffer)
        5
        '((4) (8) (0))
        (kurila-indent-indentation-info))
 
 (kt-is (kt-buffer-if-block)
        5
        [statement (6 0)]
        (kurila-sniff-for-indent))
 (kt-is (kt-buffer-if-block)
        6
        '(6 next-line)
        (kurila-sniff-for-block-start))
 (kt-is (kt-buffer-if-block)
        6
        '()
        (kurila-sniff-for-paren-open))
 (kt-is (kt-buffer-if-block)
        7
        '((10))
        (kurila-indent-indentation-info))
 (kt-is (kt-buffer-if-block)
        8
        '((8) (12) (6) (0))
        (kurila-indent-indentation-info))
 
 (kt-is (kt-buffer-paren)
        4
        '(9)
        (kurila-sniff-for-paren-open))
 (kt-is (kt-buffer-paren)
        5
        [cont-expr (9 4)]
        (kurila-sniff-for-indent))
 (kt-is (kt-buffer-paren)
        5
        '((9) (13) (8))
        (kurila-indent-indentation-info))
 )

