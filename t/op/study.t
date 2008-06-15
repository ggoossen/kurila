#!./perl

our $Ok_Level = 0;
my $test = 1;
sub ok ($;$) {
    my($ok, $name) = < @_;

    local $_;

    # You have to do it this way or VMS will get confused.
    printf "\%s $test\%s\n", $ok   ? 'ok' : 'not ok',
                           $name ? " - $name" : '';

    printf "# Failed test at line \%d\n", (caller($Ok_Level))[[2]] unless $ok;

    $test++;
    return $ok;
}

sub nok ($;$) {
    my($nok, $name) = < @_;
    local $Ok_Level = 1;
    ok( !$nok, $name );
}

use Config;
my $have_alarm = %Config{d_alarm};
sub alarm_ok (&) {
    my $test = shift;

    local %SIG{ALRM} = sub { die "timeout\n" };
    
    my $match;
    try { 
        alarm(2) if $have_alarm;
        $match = $test->();
        alarm(0) if $have_alarm;
    };

    local $Ok_Level = 1;
    ok( !$match && !$@, 'testing studys that used to hang' );
}


print "1..26\n";

my $x = "abc\ndef\n";
study($x);

ok($x =~ m/^abc/);
ok($x !~ m/^def/);

# used to be a test for $*
ok($x =~ m/^def/m);

$_ = '123';
study;
ok(m/^([0-9][0-9]*)/);

nok($x =~ m/^xxx/);
nok($x !~ m/^abc/);

ok($x =~ m/def/);
nok($x !~ m/def/);

study($x);
ok($x !~ m/.def/);
nok($x =~ m/.def/);

ok($x =~ m/\ndef/);
nok($x !~ m/\ndef/);

$_ = 'aaabbbccc';
study;
ok(m/(a*b*)(c*)/ && $1 eq 'aaabbb' && $2 eq 'ccc');
ok(m/(a+b+c+)/ && $1 eq 'aaabbbccc');

nok(m/a+b?c+/);

$_ = 'aaabccc';
study;
ok(m/a+b?c+/);
ok(m/a*b+c*/);

$_ = 'aaaccc';
study;
ok(m/a*b?c*/);
nok(m/a*b+c*/);

$_ = 'abcdef';
study;
ok(m/bcd|xyz/);
ok(m/xyz|bcd/);

ok(m|bc/*d|);

ok(m/^$_$/);

# used to be a test for $*
ok("ab\ncd\n" =~ m/^cd/m);

if ($^O eq 'os390' or $^O eq 'posix-bc' or $^O eq 'MacOS') {
    # Even with the alarm() OS/390 and BS2000 can't manage these tests
    # (Perl just goes into a busy loop, luckily an interruptable one)
    for (25..26) { print "not ok $_ # TODO compiler bug?\n" }
    $test += 2;
} else {
    # [ID 20010618.006] tests 25..26 may loop

    $_ = 'FGF';
    study;
    alarm_ok { m/G.F$/ };
    alarm_ok { m/[F]F$/ };
}

