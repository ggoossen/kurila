#!./perl

our (@x, @y, $result, $x, $y, @t, $u);

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

print "1..6\n";

$result = do { ok 1; 'value';};
ok( $result eq 'value',  ":$result: eq :value:" );

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
