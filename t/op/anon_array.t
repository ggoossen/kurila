#!./perl

BEGIN { require "./test.pl"; }
plan:  tests => 7 

my $x = \qw|foo bar baz|
is: $x->[0], 'foo', "anon array ref construction"
is: $x->[2], 'baz', "anon array ref construction"

is:  ((join: '*',qw|foo bar baz|)), 'foo*bar*baz', "anon array is list in list context"

is: qw|foo bar baz|[2], 'baz', "using aelem directy on anon array"

my $x = \ $@
is: (Internals::SvREFCNT: $x), 1, "there is only one reference"
eval_dies_like:  ' (@: qw|foo bar baz|)->[1]; '
                 qr/Array may not be used as a reference/
                 "anon array as reference" 

is: (ref: \qw()), "ARRAY", "empty qw() is an array"
