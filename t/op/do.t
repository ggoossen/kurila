#!./perl

our (@x, @y, $result, $x, $y, @t, $u);

my $test = 1;
sub ok($ok, ?$name) {

    # You have to do it this way or VMS will get confused.
    printf $^STDOUT, "\%s \%d\%s\n", $ok ?? "ok" !! "not ok", 
                        $test,
                        defined $name ?? " - $name" !! '';

    printf $^STDOUT, "# Failed test at line \%d\n", (caller)[[2]] unless $ok;

    $test++;
    return $ok;
}

print $^STDOUT, "1..6\n";

$result = do { ok 1; 'value';};
ok( $result eq 'value',  ":$result: eq :value:" );

unshift $^INCLUDE_PATH, '.';

# bug ID 20010920.007
eval qq{ do qq(a file that does not exist); };
ok( !$^EVAL_ERROR, "do on a non-existing file, first try" );

eval qq{ do uc qq(a file that does not exist); };
ok( !$^EVAL_ERROR, "do on a non-existing file, second try"  );

# 6 must be interpreted as a file name here
ok( (!defined do 6) && $^OS_ERROR, "'do 6' : $^OS_ERROR" );

# [perl #19545]
push @t, ($u = (do {} . "This should be pushed."));
ok( ((nelems @t)-1) == 0, "empty do result value" );

END {
    1 while unlink("$^PID.16", "$^PID.17", "$^PID.18");
}
