#!./perl

require "./test.pl"
plan:  tests => 54 

our ($aaa, $x, @aa, %aa, $aa)

$aa = 1
do { local $aa = undef;     $aa = 2; is: $aa,2; }
is: $aa,1
do { local $aa = undef;   $aa = 3; is: $aa,3; }
is: $aa,1
do { local (Symbol::fetch_glob: "aa")->*->$; $aa = 4; is: $aa,4; }
is: $aa,1
$x = \*aa
do { local $x->*->$;   $aa = 5; is: $aa,5; undef $x; is: $aa,5; }
is: $aa,1
$x = \*aa
do { local $x->*->$;     $aa = 7; is: $aa,7; undef $x; is: $aa,7; }
is: $aa,1

@aa = qw/a b/
do { local @aa;     @aa = qw/c d/; is: "$((join: ' ',@aa))","c d"; }
is: "$((join: ' ',@aa))","a b"
do { local @aa;   @aa = qw/e f/; is: "$((join: ' ',@aa))","e f"; }
is: "$((join: ' ',@aa))","a b"
do { local (Symbol::fetch_glob: "aa")->*->@; @aa = qw/g h/; is: "$((join: ' ',@aa))","g h"; }
is: "$((join: ' ',@aa))","a b"
$x = \*aa
do { local $x->*->@;   @aa = qw/i j/; is: "$((join: ' ',@aa))","i j"; undef $x; is: "$((join: ' ',@aa))","i j"; }
is: "$((join: ' ',@aa))","a b"
$x = \*aa
do { local $x->*->@;     @aa = qw/m n/; is: "$((join: ' ',@aa))","m n"; undef $x; is: "$((join: ' ',@aa))","m n"; }
is: "$((join: ' ',@aa))","a b"

%aa = %:  < qw/a b/ 
do { local %aa;     %aa = (%:  < qw/c d/ ); is: %aa{?c},"d"; }
is: %aa{?a},"b"
do { local %aa;   %aa = (%:  < qw/e f/ ); is: %aa{?e},"f"; }
is: %aa{?a},"b"
do { local (Symbol::fetch_glob: "aa")->*->%; %aa = (%:  < qw/g h/ ); is: %aa{?g},"h"; }
is: %aa{?a},"b"
$x = \*aa
do { local $x->*->%;   %aa = (%:  < qw/i j/ ); is: %aa{?i},"j"; undef $x; is: %aa{?i},"j"; }
is: %aa{?a},"b"
$x = \*aa
do { local $x->*->%;     %aa = (%:  < qw/m n/ ); is: %aa{?m},"n"; undef $x; is: %aa{?m},"n"; }
is: %aa{?a},"b"

sub test_err_localref ()
    local our $TODO = 1
    like: $^EVAL_ERROR && $^EVAL_ERROR->{?description},qr/Can't localize through a reference/,'error'

$x = \$aa
my $y = \$aa
try { local $x->$; }
(test_err_localref: )
try { local $x->$; }
(test_err_localref: )
try { local $y->$; }
(test_err_localref: )
try { local $y->$; }
(test_err_localref: )
try { local (\$aa)->$; }
(test_err_localref: )
$x = \@aa
$y = \@aa
try { local $x->@; }
(test_err_localref: )
try { local $x->@; }
(test_err_localref: )
try { local $y->@; }
(test_err_localref: )
try { local $y->@; }
(test_err_localref: )
try { local (\@aa)->@; }
(test_err_localref: )
try { local (\$@)->@; }
(test_err_localref: )
$x = \%aa
$y = \%aa
try { local $x->%; }
(test_err_localref: )
try { local $x->%; }
(test_err_localref: )
try { local $y->%; }
(test_err_localref: )
try { local $y->%; }
(test_err_localref: )
try { local (\%aa)->%; }
(test_err_localref: )
try { local (\%: a=>1)->%; }
(test_err_localref: )


do
    # [perl #27638] when restoring a localized variable, the thing being
    # freed shouldn't be visible
    my $ok
    $x = 0
    sub X::DESTROY { $ok = !(ref: $x); }
    do
        local $x = \ bless: \$%, 'X'
        1
    
    ok: $ok,'old value not visible during restore'

