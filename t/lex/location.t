#!./perl

BEGIN {
    require './test.pl';
}

plan tests => 1;

my $ref = \ 1 ;
#line 8
try { "a" . $ref };
like $@->message, qr/line 8 character 10/;
