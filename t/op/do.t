#!./perl

our (@x, @y, $result, $x, $y, @t, $u);

sub foo1
{
    ok(@_[0]);
    'value';
}

sub foo2
{
    shift;
    ok(@_[0]);
    $x = 'value';
    $x;
}

my $test = 1;
sub ok {
    my($ok, $name) = < @_;

    # You have to do it this way or VMS will get confused.
    printf "\%s \%d\%s\n", $ok ? "ok" : "not ok", 
                        $test,
                        defined $name ? " - $name" : '';

    printf "# Failed test at line \%d\n", (caller)[[2]] unless $ok;

    $test++;
    return $ok;
}

print "1..19\n";

# Test do &sub and proper @_ handling.
@_[0] = 0;
$result = do foo1(1);

ok( $result eq 'value',  ":$result: eq :value:" );
ok( @_[0] == 0 );

@_[0] = 0;
$result = do foo2(0,1,0);
ok( $result eq 'value', ":$result: eq :value:" );
ok( @_[0] == 0 );

$result = do{ ok 1; 'value';};
ok( $result eq 'value',  ":$result: eq :value:" );

sub blather {
    ok 1 foreach < @_;
}

do blather("ayep","sho nuff");
@x = @("jeepers", "okydoke");
@y = @("uhhuh", "yeppers");
do blather(< @x,"noofie",< @y);

unshift @INC, '.';

# bug ID 20010920.007
eval qq{ do qq(a file that does not exist); };
ok( !$@, "do on a non-existing file, first try" );

eval qq{ do uc qq(a file that does not exist); };
ok( !$@, "do on a non-existing file, second try"  );

# 6 must be interpreted as a file name here
ok( (!defined do 6) && $!, "'do 6' : $!" );

# [perl #19545]
push @t, ($u = (do {} . "This should be pushed."));
ok( ((nelems @t)-1) == 0, "empty do result value" );

END {
    1 while unlink("$$.16", "$$.17", "$$.18");
}
