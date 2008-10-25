#!./perl

BEGIN {
    require './test.pl';
}

plan tests => 1;

my $ref = \ 1 ;
#line 8
try { "a" . $ref };
like $@->stacktrace, qr/line 8 character 10/;
