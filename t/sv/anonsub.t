#!./perl

# Note : we're not using t/test.pl here, because we would need
# fresh_perl_is, and fresh_perl_is uses a closure -- a special
# case of what this program tests for.


BEGIN { require "./test.pl" }

my $Is_VMS = $^OS_NAME eq 'VMS'
my $Is_MSWin32 = $^OS_NAME eq 'MSWin32'
my $Is_MacOS = $^OS_NAME eq 'MacOS'
my $Is_NetWare = $^OS_NAME eq 'NetWare'
(env::var: 'PERL5LIB' ) = "../lib" unless $Is_VMS

our $i = 0

$^OUTPUT_AUTOFLUSH=1

undef $^INPUT_RECORD_SEPARATOR
my @prgs = split: "\n########\n", ~< $^DATA
plan: 1 + scalar nelems @prgs

my $tmpfile = "asubtmp000"
1 while -f ++$tmpfile
END { if ($tmpfile) { 1 while (unlink: $tmpfile); } }

for ( @prgs)
    my $switch = ""
    if (s/^\s*(-\w+)//)
        $switch = $1
    
    my(@: $prog,$expected) =  split: m/\nEXPECT\n/, $_
    open: my $test, ">", "$tmpfile"
    print: $test, "$prog\n"
    close $test or die: "Could not close: $^OS_ERROR"
    my $results = $Is_VMS ??
        `$^EXECUTABLE_NAME "-I[-.lib]" $switch $tmpfile 2>&1` !!
        $Is_MSWin32 ??
        `.\\perl -I../lib $switch $tmpfile 2>&1` !!
        $Is_MacOS ??
        `$^EXECUTABLE_NAME -I::lib $switch $tmpfile` !!
        $Is_NetWare ??
        `perl -I../lib $switch $tmpfile 2>&1` !!
        `./perl $switch $tmpfile 2>&1`
    my $status = $^CHILD_ERROR
    $results =~ s/\n+$//
    # allow expected output to be written as if $prog is on STDIN
    $results =~ s/runltmp\d+/-/g
    $results =~ s/\n%[A-Z]+-[SIWEF]-.*$// if $Is_VMS  # clip off DCL status msg
    $expected =~ s/\n+$//
    if ($results ne $expected)
        print: $^STDERR, "PROG: $switch\n$prog\n"
    
    is: $results, $expected


eval "sub #foo\n \{ print \$^STDOUT, 1 \}"
is: $^EVAL_ERROR, '', "No error"

__DATA__
do {
sub X {
    my $n = "ok 1\n";
    sub { print $^STDOUT, $n };
}
my $x = X();
undef &X;
$x->();
};
EXPECT
ok 1
########
do {
sub X {
    my $n = "ok 1\n";
    sub {
        my $dummy = $n; # eval can't close on $n without internal reference
        eval 'print $^STDOUT, $n';
        die $^EVAL_ERROR if $^EVAL_ERROR;
    };
}
my $x = X();
undef &X;
$x->();
};
EXPECT
ok 1
########
do {
sub X {
    my $n = "ok 1\n";
    eval 'sub { print $^STDOUT, $n }';
}
my $x = X();
die $^EVAL_ERROR if $^EVAL_ERROR;
undef &X;
$x->();
};
EXPECT
ok 1
########
print $^STDOUT, sub { return "ok 1\n" } -> ()
EXPECT
ok 1
