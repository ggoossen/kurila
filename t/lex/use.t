#!./perl

# Testing of 'use'

BEGIN { require "./test.pl"; }
plan:  tests => 3 

eval 'use v5.5.640'
like:  $^EVAL_ERROR->{?description}, qr/use VERSION is not valid in Perl Kurila/, "use v5.5.640;"

# now do the same without the "v"
eval 'use 5.8'
like:  $^EVAL_ERROR->{?description}, qr/use VERSION is not valid in Perl Kurila/, "use 5.8"

eval 'use 5.5.640'
like:  $^EVAL_ERROR->{?description}, qr/use VERSION is not valid in Perl Kurila/, "use 5.5.640" 

