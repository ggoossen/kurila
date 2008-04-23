#!./perl

BEGIN { require "./test.pl"; }
plan( tests => 6 );

my $x = \ @(qw|foo bar baz|);
is $x->[0], 'foo', "anon array ref construction";
is $x->[2], 'baz', "anon array ref construction";

is scalar(@(qw|foo bar baz|)), 3, "anon array returns count in scalar context";
is( (join '*', @(qw|foo bar baz|)), 'foo*bar*baz', "anon array is list in list context");

is @(qw|foo bar baz|)[2], 'baz', "using aelem directy on anon array";


{
    local $TODO = "deref of array";
    eval ' @(qw|foo bar baz|)->[1]; ';
    like $@ && $@->message, qr/Array may not be used as a reference/, "anon array as reference";
}
