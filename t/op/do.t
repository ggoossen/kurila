#!./perl

our (@x, @y, $result, $x, $y, @t, $u)

my $test = 1
sub ok($ok, ?$name)

    # You have to do it this way or VMS will get confused.
    printf: $^STDOUT, "\%s \%d\%s\n", $ok ?? "ok" !! "not ok"
            $test
            defined $name ?? " - $name" !! ''

    printf: $^STDOUT, "# Failed test at line \%d\n", (@: caller)[2] unless $ok

    $test++
    return $ok


print: $^STDOUT, "1..13\n"

$result = do { ok: 1; 'value';}
ok:  $result eq 'value',  ":$result: eq :value:" 

unshift: $^INCLUDE_PATH, '.'

# bug ID 20010920.007
eval qq{ evalfile qq(a file that does not exist); }
ok:  !$^EVAL_ERROR, "do on a non-existing file, first try" 

eval qq{ evalfile uc qq(a file that does not exist); }
ok:  !$^EVAL_ERROR, "do on a non-existing file, second try"  

# 6 must be interpreted as a file name here
ok:  (!defined evalfile 6) && $^OS_ERROR, "'do 6' : $^OS_ERROR" 

# [perl #19545]
push: @t, ($u = (do {} . "This should be pushed."))
ok:  ((nelems @t)-1) == 0, "empty do result value" 

END 
    1 while unlink: "$^PID.16", "$^PID.17", "$^PID.18"

# [perl #38809]
our @a = @: 7, 8
$x =( sub { do { return do { 1; @a } }; 3 }->& <: )
ok: defined $x && (nelems: $x) == 2, 'return do { } receives caller scalar context'
@a = @: 7, 8, 9
$x =( sub { do { do { 1; return @a } }; 4 }->& <: )
ok: defined $x && (nelems: $x) == 3, 'do { return } receives caller scalar context'
@a = @: 7, 8, 9, 10
$x =( sub { do { return do { 1; do { 2; @a } } }; 5 }->& <: )
ok: defined $x && (nelems: $x) == 4, 'return do { do { } } receives caller scalar context'

# Do blocks created by constant folding
# [perl #68108]
$x =( sub { if (1) { 20 } }->& <: )
ok: $x == 20, 'if (1) { $x } receives caller scalar context'

@a = (21 .. 23)
$x =( sub { if (1) { @a } }->& <: )
ok: (nelems: $x) == 3, 'if (1) { @a } receives caller scalar context'

$x =( sub { if (1) { 0; 20 } }->& <: )
ok: $x == 20, 'if (1) { ...; $x } receives caller scalar context'

@a = (24 .. 27)
$x =( sub { if (1) { 0; @a } }->& <: )
ok: (nelems: $x) == 4, 'if (1) { ...; @a } receives caller scalar context'

