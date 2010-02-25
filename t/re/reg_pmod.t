#!./perl

BEGIN 
    require './test.pl'


use warnings

our @tests = @:
    # /p      Pattern   PRE     MATCH   POST
    \(@:  '/p',   "456",    "123-", "456",  "-789")
    \(@:  '(?p)', "456",    "123-", "456",  "-789")
    \(@:  '',     "(456)",  "123-", "456",  "-789")
    \(@:  '',     "456",    undef,  undef,  undef )
    

plan: tests => 4 * (nelems @tests) + 2
my $W = ""

$^WARN_HOOK = sub (@< @_) { $W.=(join: "", @_); }
sub _u($x, $y) { "$x is ".(defined $y ?? "'$y'" !! "undef") }

$_ = '123-456-789'
foreach my $test ( @tests)
    my (@: $p, $pat,$l,$m,$r) =  $test->@
    my $test_name = $p eq '/p'   ?? "/$pat/p"
        !! $p eq '(?p)' ?? "/(?p)$pat/"
        !!                "/$pat/"

    #
    # Cannot use if/else due to the scope invalidating $^MATCH and friends.
    #
    my $ok = ok: $p eq '/p'   ?? m/$pat/p
                             !! $p eq '(?p)' ?? m/(?p)$pat/
                             !!                m/$pat/
                 => $test_name
    :SKIP do
        skip: "/$pat/$p failed to match", 3
            unless $ok
        is: $^PREMATCH,  $l, (_u: "$test_name: ^PREMATCH",$l)
        is: $^MATCH,     $m, (_u: "$test_name: ^MATCH",$m) 
        is: $^POSTMATCH, $r, (_u: "$test_name: ^POSTMATCH",$r) 
    

is: $W,"","No warnings should be produced"
ok: !defined $^MATCH, "No /p in scope so ^MATCH is undef"
