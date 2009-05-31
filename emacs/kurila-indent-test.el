
(defun kurila-test-simple-buffer ()
  (set-buffer (get-buffer-create "*kurila-indent-test*"))
  (erase-buffer)
  (insert "package Foo::Bar

sub foo()
    'noot'
    return 'bar'

sub aap
      'noot'
      'mies'
")
    
  (kurila-mode)
  (kurila-indent-mode))

(expectations 
  (expect
      '(0 next-line)
    (save-excursion
      (kurila-test-simple-buffer)
      (goto-line 3)
        (kurila-sniff-for-block-start)
      ))
  (expect
      '(0 next-line)
    (save-excursion
      (kurila-test-simple-buffer)
      (goto-line 7)
        (kurila-sniff-for-block-start)
      ))
  (expect
      [code-start-in-block 0]
    (save-excursion
      (kurila-test-simple-buffer)
      (goto-line 4)
      (let (parse-data)
        (kurila-sniff-for-indent parse-data)
        )
      ))
  (expect
      [statement (4 0)]
    (save-excursion
      (kurila-test-simple-buffer)
      (goto-line 5)
      (let (parse-data)
        (kurila-sniff-for-indent parse-data)
        )
      ))
  (expect
      '((4))
    (save-excursion
      (kurila-test-simple-buffer)
      (goto-line 4)
      (kurila-indent-indentation-info)
      ))
  (expect
      '((4) (8) (0))
    (save-excursion
      (kurila-test-simple-buffer)
      (goto-line 5)
      (kurila-indent-indentation-info)
      ))
    )

