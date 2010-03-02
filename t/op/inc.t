#!./perl -w

print: $^STDOUT, "1..55\n"

my $test = 1

sub ok($pass, ?$err)
    if ($pass)
        print: $^STDOUT, "ok $test\n"
        $test = $test + 1 # Would be doubleplusbad to use ++ in the ++ test.
        return 1
    else
        printf: $^STDOUT, "not ok $test # line \%d\n", (@: caller)[2]

    $test = $test + 1
    return


# Verify that addition/subtraction properly upgrade to doubles.
# These tests are only significant on machines with 32 bit longs,
# and two's complement negation, but shouldn't fail anywhere.

my $a = 2147483647
my $c=$a++
ok: $a == 2147483648

$a = 2147483647
$c=++$a
ok: $a == 2147483648

$a = 2147483647
$a=$a+1
ok: $a == 2147483648

$a = -2147483648
$c=$a--
ok: $a == -2147483649

$a = -2147483648
$c=--$a
ok: $a == -2147483649

$a = -2147483648
$a=$a-1
ok: $a == -2147483649

$a = 2147483648
$a = -$a
$c=$a--
ok: $a == -2147483649

$a = 2147483648
$a = -$a
$c=--$a
ok: $a == -2147483649

$a = 2147483648
$a = -$a
$a=$a-1
ok: $a == -2147483649

$a = 2147483648
$b = -$a
$c=$b--
ok: $b == -$a-1

$a = 2147483648
$b = -$a
$c=--$b
ok: $b == -$a-1

$a = 2147483648
$b = -$a
$b=$b-1
ok: $b == -(++$a)

$a = undef
ok: $a++ eq '0', "postinc undef returns '0'"

$a = undef
ok: !(defined: $a--), "postdec undef returns undef"

# Verify that shared hash keys become unshared.

sub check_same($orig, $suspect)
    my $fail
    while (my (@: ?$key, ?$value) =(@:  each $suspect->%))
        if (exists $orig->{$key})
            if ($orig->{?$key} ne $value)
                print: $^STDOUT, "# key '$key' was '$orig->{?$key}' now '$value'\n"
                $fail = 1

        else
            print: $^STDOUT, "# key '$key' is '$orig->{?$key}', unexpect.\n"
            $fail = 1


    foreach (keys $orig->%)
        next if (exists $suspect->{$_})
        print: $^STDOUT, "# key '$_' was '$orig->{?$_}' now missing\n"
        $fail = 1

    ok: !$fail


my %orig = my %inc = my %dec = my %postinc = my %postdec
    = %: 1 => 1, ab => "ab"
my %up = %: 1=>2, ab => 'ac'
my %down = %: 1=>0, ab => -1

foreach (keys %inc)
    my $ans = %up{?$_}
    my $up
    try {$up = ++$_}
    ok: (defined $up and $up eq $ans), $up


check_same: \%orig, \%inc

foreach (keys %dec)
    my $ans = %down{?$_}
    my $down
    try {$down = --$_}
    ok: (defined $down and $down eq $ans), $down


check_same: \%orig, \%dec

foreach (keys %postinc)
    my $ans = %postinc{?$_}
    my $up
    try {$up = $_++}
    ok: (defined $up and $up eq $ans), $up


check_same: \%orig, \%postinc

foreach (keys %postdec)
    my $ans = %postdec{?$_}
    my $down
    try {$down = $_--}
    ok: defined $down and $down eq $ans


check_same: \%orig, \%postdec

do
    no warnings 'uninitialized'
    my ($x, $y)
    try {
        $y ="$x\n";
        ++$x;
    }
    ok: $x == 1, $x
    ok: $^EVAL_ERROR eq '', $^EVAL_ERROR

    my ($p, $q)
    try {
        $q ="$p\n";
        --$p;
    }
    ok: $p == -1, $p
    ok: $^EVAL_ERROR eq '', $^EVAL_ERROR


$a = 2147483648
$c=--$a
ok: $a == 2147483647, $a


$a = 2147483648
$c=$a--
ok: $a == 2147483647, $a

try { my $x = qw|aap noot mies|; $x++ }
ok: $^EVAL_ERROR->message =~ m/increment \(\+\+\) does not work on a ARRAY/

do
    use integer
    my $x = 0
    $x++
    ok: $x == 1, "(void) i_postinc"
    $x--
    ok: $x == 0, "(void) i_postdec"


# I'm sure that there's an IBM format with a 48 bit mantissa
# IEEE doubles have a 53 bit mantissa
# 80 bit long doubles have a 64 bit mantissa
# sparcs have a 112 bit mantissa for their long doubles. Just to be awkward :-)

sub check_some_code
    my (@: $start, $warn, $action, $description) =  @_
    my $warn_line = ($warn ?? 'use' !! 'no') . " warnings 'imprecision';"
    my @warnings
    local $^WARN_HOOK = sub (@< @_) {(push: @warnings, @_[0]->message)}

    print: $^STDOUT, "# checking $action under $warn_line\n"
    my $code = <<"EOC"
$warn_line
my \$i = \$start;
for(0 .. 3) \{
    my \$a = $action;
\}
1;
EOC
    eval $code or die: "# $^EVAL_ERROR\n$code"

    if ($warn)
        unless ((ok: scalar nelems @warnings == 2, scalar nelems @warnings))
            foreach (@warnings)
                print: $^STDERR, "# $_"
        foreach ( @warnings)
            unless ((ok: m/Lost precision when incrementing \d+/, $_))
                print: $^STDERR, "# $_"
    else
        unless ((ok: scalar nelems @warnings == 0))
            foreach (@warnings)
                print: $^STDERR, "# $((join: ' ',$_->@))"


my $h_uv_max = 1 + (^~^0 >> 1)
my $found
for my $n (47..113)
    my $power_of_2 = 2**$n
    my $plus_1 = $power_of_2 + 1
    next if $plus_1 != $power_of_2
    my ($start_p, $start_n)
    if ($h_uv_max +> $power_of_2 / 2)
        my $uv_max = 1 + 2 * (^~^0 >> 1)
        # UV_MAX is 2**$something - 1, so subtract 1 to get the start value
        $start_p = $uv_max - 1
        # whereas IV_MIN is -(2**$something), so subtract 2
        $start_n = -$h_uv_max + 2
        print: $^STDOUT, "# Mantissa overflows at 2**$n ($power_of_2)\n"
        print: $^STDOUT, "# But max UV ($uv_max) is greater so testing that\n"
    else
        print: $^STDOUT, "# Testing 2**$n ($power_of_2) which overflows the mantissa\n"
        $start_p = int: $power_of_2 - 2
        $start_n = -$start_p
        my $check = $power_of_2 - 2
        die: "Something wrong with our rounding assumptions: $check vs $start_p"
            unless $start_p == $check


    foreach my $warn ((@: 0, 1))
        foreach ((@: \(@: '++$i', 'pre-inc'), \(@: '$i++', 'post-inc')))
            check_some_code: $start_p, $warn, < $_->@

        foreach ((@: \(@: '--$i', 'pre-dec'), \(@: '$i--', 'post-dec')))
            check_some_code: $start_n, $warn, < $_->@



    $found = 1
    last

die: "Could not find a value which overflows the mantissa" unless $found

# these will segfault if they fail

sub PVBM () { 'foo' }
do
    my $dummy = (index: 'foo' (PVBM: ))

(ok: scalar try { my $pvbm = (PVBM: ); $pvbm++ })
(ok: scalar try { my $pvbm = (PVBM: ); $pvbm-- })
(ok: scalar try { my $pvbm = (PVBM: ); ++$pvbm })
(ok: scalar try { my $pvbm = (PVBM: ); --$pvbm })
