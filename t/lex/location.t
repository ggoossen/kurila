#!./perl

BEGIN 
    require './test.pl'

plan: tests => 2

do
    my $ref = \ 1 ;
    my $expected_line = __LINE__ + 1
    try "a" . $ref
    like: $^EVAL_ERROR->stacktrace, qr/line $($expected_line) character 13[.]/

do
    sub foo
        die: 'trace'
    my $expected_line = __LINE__ + 1
    try foo:
           1 
    like: $^EVAL_ERROR->stacktrace, qr/line $($expected_line) character 9[.]/
          'function call with arguments on the next line'
