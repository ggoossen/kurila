#!./perl

# tests for both real and emulated fork()

use Config

BEGIN 
    unless (config_value: 'd_fork' or config_value: 'd_pseudofork')
        print: $^STDOUT, "1..0 # Skip: no fork\n"
        exit 0
    
    (env::var: 'PERL5LIB' ) = "../lib"


if ($^OS_NAME eq 'mpeix')
    print: $^STDOUT, "1..0 # Skip: fork/status problems on MPE/iX\n"
    exit 0

$^OUTPUT_AUTOFLUSH=1

our (@prgs, $tmpfile, $CAT, $status, $i)

$^INPUT_RECORD_SEPARATOR = undef
@prgs = split: "\n########\n", ~< $^DATA
print: $^STDOUT, "1..", scalar nelems @prgs, "\n"

$tmpfile = "forktmp000"
1 while -f ++$tmpfile
my $test_fh
END { close $test_fh; unlink: $tmpfile if $tmpfile; }

$CAT = (($^OS_NAME eq 'MSWin32')
        ?? '.\perl -e "print \$^STDOUT, ~< *ARGV"'
        !! (($^OS_NAME eq 'NetWare')
            ?? 'perl -e "print \$^STDOUT, ~< *ARGV"'
            !! 'cat'))

for ( @prgs)
    my $switch
    if (s/^\s*(-\w.*)//)
        $switch = $1
    
    my(@: $prog,$expected) =  split: m/\nEXPECT\n/, $_
    $expected =~ s/\n+$//
    # results can be in any order, so sort 'em
    my @expected = sort: split: m/\n/, $expected
    open: $test_fh, ">", "$tmpfile" or die: "Cannot open $tmpfile: $^OS_ERROR"
    print: $test_fh, $prog, "\n"
    close $test_fh or die: "Cannot close $tmpfile: $^OS_ERROR"
    my $results
    if ($^OS_NAME eq 'MSWin32')
        $results = `.\\perl -I../lib $switch $tmpfile 2>&1`
    elsif ($^OS_NAME eq 'NetWare')
        $results = `perl -I../lib $switch $tmpfile 2>&1`
    else
        $results = `./perl $switch $tmpfile 2>&1`
    
    $status = $^CHILD_ERROR
    $results =~ s/\n+$//
    $results =~ s/at\s+forktmp\d+\s+line/at - line/g
    $results =~ s/of\s+forktmp\d+\s+aborted/of - aborted/g
    # bison says 'parse error' instead of 'syntax error',
    # various yaccs may or may not capitalize 'syntax'.
    $results =~ s/^(syntax|parse) error/syntax error/mig
    $results =~ s/^\n*Process terminated by SIG\w+\n?//mg
        if $^OS_NAME eq 'os2'
    my @results = sort: split: m/\n/, $results
    if ( "$((join: ' ',@results))" ne "$((join: ' ',@expected))" )
        print: $^STDERR, "PROG: $switch\n$prog\n"
        print: $^STDERR, "EXPECTED:\n$expected\n"
        print: $^STDERR, "GOT:\n$results\n"
        print: $^STDOUT, "not "
    
    print: $^STDOUT, "ok ", ++$i, "\n"


__END__
$^OUTPUT_AUTOFLUSH = 1;
if (my $cid = fork) {
    sleep 1;
    if (my $result = (kill 9, $cid)) {
        print $^STDOUT, "ok 2\n";
    }
    else {
        print $^STDOUT, "not ok 2 $result\n";
    }
    sleep 1 if $^OS_NAME eq 'MSWin32';  # avoid WinNT race bug
}
else {
    print $^STDOUT, "ok 1\n";
    sleep 10;
}
EXPECT
ok 1
ok 2
########
$^OUTPUT_AUTOFLUSH = 1;
if (my $cid = fork) {
    sleep 1;
    print $^STDOUT, "not " unless kill 'INT', $cid;
    print $^STDOUT, "ok 2\n";
}
else {
    # XXX On Windows the default signal handler kills the
    # XXX whole process, not just the thread (pseudo-process)
    use signals;
    signals::handler("INT") = sub { exit };
    print $^STDOUT, "ok 1\n";
    sleep 5;
    die;
}
EXPECT
ok 1
ok 2
########
$^OUTPUT_AUTOFLUSH = 1;
our $i;
sub forkit {
    print $^STDOUT, "iteration $i start\n";
    my $x = fork;
    if (defined $x) {
        if ($x) {
            print $^STDOUT, "iteration $i parent\n";
        }
        else {
            print $^STDOUT, "iteration $i child\n";
        }
    }
    else {
        print $^STDOUT, "pid $^PID failed to fork\n";
    }
}
while ($i++ +< 3) { do { forkit(); }; }
EXPECT
iteration 1 start
iteration 1 parent
iteration 1 child
iteration 2 start
iteration 2 parent
iteration 2 child
iteration 2 start
iteration 2 parent
iteration 2 child
iteration 3 start
iteration 3 parent
iteration 3 child
iteration 3 start
iteration 3 parent
iteration 3 child
iteration 3 start
iteration 3 parent
iteration 3 child
iteration 3 start
iteration 3 parent
iteration 3 child
########
$^OUTPUT_AUTOFLUSH = 1;
fork()
 ?? (print($^STDOUT, "parent\n"),sleep(1))
 !! (print($^STDOUT, "child\n"),exit) ;
EXPECT
parent
child
########
$^OUTPUT_AUTOFLUSH = 1;
fork()
 ?? (print($^STDOUT, "parent\n"),exit)
 !! (print($^STDOUT, "child\n"),sleep(1)) ;
EXPECT
parent
child
########
$^OUTPUT_AUTOFLUSH = 1;
my @a = 1..3;
for (@a) {
    if (fork) {
        print $^STDOUT, "parent $_\n";
        $_ = "[$_]";
    }
    else {
        print $^STDOUT, "child $_\n";
        $_ = "-$_-";
    }
}
print $^STDOUT, "$(join ' ', @a)\n";
EXPECT
parent 1
child 1
parent 2
child 2
parent 2
child 2
parent 3
child 3
parent 3
child 3
parent 3
child 3
parent 3
child 3
[1] [2] [3]
-1- [2] [3]
[1] -2- [3]
[1] [2] -3-
-1- -2- [3]
-1- [2] -3-
[1] -2- -3-
-1- -2- -3-
########
$^OUTPUT_AUTOFLUSH = 1;
foreach my $c (@: 1,2,3) {
    if (fork) {
        print $^STDOUT, "parent $c\n";
    }
    else {
        print $^STDOUT, "child $c\n";
        exit;
    }
}
while (wait() != -1) { print $^STDOUT, "waited\n" }
EXPECT
child 1
child 2
child 3
parent 1
parent 2
parent 3
waited
waited
waited
########
use Config;
$^OUTPUT_AUTOFLUSH = 1;
fork()
 ?? print($^STDOUT, config_value('osname') eq $^OS_NAME, qq[\n])
 !! print($^STDOUT, config_value('osname') eq $^OS_NAME, qq[\n]) ;
EXPECT
1
1
########
$^OUTPUT_AUTOFLUSH = 1;
fork()
 ?? do { require Config; print($^STDOUT, Config::config_value("osname") eq $^OS_NAME, qq[\n]); }
 !! do { require Config; print($^STDOUT, Config::config_value("osname") eq $^OS_NAME, qq[\n]); }
EXPECT
1
1
########
$^OUTPUT_AUTOFLUSH = 1;
use Cwd;
my $cwd = cwd(); # Make sure we load Win32.pm while "../lib" still works.
my $dir;
if (fork) {
    $dir = "f$^PID.tst";
    mkdir $dir, 0755;
    chdir $dir;
    print $^STDOUT, cwd() =~ m/\Q$dir/i ?? "ok 1 parent\n" !! "not ok 1 parent\n";
    chdir "..";
    rmdir $dir;
}
else {
    sleep 2;
    $dir = "f$^PID.tst";
    mkdir $dir, 0755;
    chdir $dir;
    print $^STDOUT, cwd() =~ m/\Q$dir/i ?? "ok 1 child\n" !! "not ok 1 child\n";
    chdir "..";
    rmdir $dir;
}
EXPECT
ok 1 parent
ok 1 child
########
$^OUTPUT_AUTOFLUSH = 1;
my $getenv;
if ($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare') {
    $getenv = qq[$^EXECUTABLE_NAME -e "print \\\$^STDOUT, \$(env::var(q[TST]))"];
}
else {
    $getenv = qq[$^EXECUTABLE_NAME -e 'print \$^STDOUT, \$(env::var(q[TST]))'];
}
env::var("TST") = 'foo';
if (fork) {
    sleep 1;
    print $^STDOUT, "parent before: " . `$getenv` . "\n";
    env::var("TST") = 'bar';
    print $^STDOUT, "parent after: " . `$getenv` . "\n";
}
else {
    print $^STDOUT, "child before: " . `$getenv` . "\n";
    env::var("TST") = 'baz';
    print $^STDOUT, "child after: " . `$getenv` . "\n";
}
EXPECT
child before: foo
child after: baz
parent before: foo
parent after: bar
########
$^OUTPUT_AUTOFLUSH = 1;
if (my $pid = fork) {
    waitpid($pid,0);
    print $^STDOUT, "parent got $^CHILD_ERROR\n"
}
else {
    exit(42);
}
EXPECT
parent got 10752
########
$^OUTPUT_AUTOFLUSH = 1;
my $echo = 'echo';
if (my $pid = fork) {
    waitpid($pid,0);
    print $^STDOUT, "parent got $^CHILD_ERROR\n"
}
else {
    exec("$echo foo");
}
EXPECT
foo
parent got 0
########
if (fork) {
    die "parent died";
}
else {
    sleep 1; die "child died";
}
EXPECT
parent died at - line 2 character 5.
child died at - line 5 character 14.
########
if (my $pid = fork) {
    try { die "parent died" };
    print $^STDOUT, $^EVAL_ERROR->message;
}
else {
    sleep 1; try { die "child died" };
    print $^STDOUT, $^EVAL_ERROR->message;
}
EXPECT
parent died at - line 2 character 11.
    (try) called at - line 2 character 5.
child died at - line 6 character 20.
    (try) called at - line 6 character 14.
########
my $pid;
if (eval q{$pid = fork}) {
    eval q{ die "parent died" };
    print $^STDOUT, $^EVAL_ERROR->message;
}
else {
    sleep 1; eval q{ die "child died" };
    print $^STDOUT, $^EVAL_ERROR->message;
}
EXPECT
parent died at (eval 2) line 1 character 2.
    (eval) called at - line 3 character 5.
child died at (eval 2) line 1 character 2.
    (eval) called at - line 7 character 14.
########
BEGIN {
    $^OUTPUT_AUTOFLUSH = 1;
    fork and exit;
    print $^STDOUT, "inner\n";
}
# XXX In emulated fork(), the child will not execute anything after
# the BEGIN block, due to difficulties in recreating the parse stacks
# and restarting yyparse() midstream in the child.  This can potentially
# be overcome by treating what's after the BEGIN{} as a brand new parse.
#print "outer\n"
EXPECT
inner
########
sub pipe_to_fork ($parent, $child) {
    pipe($child, $parent) or die;
    my $pid = fork();
    die "fork() failed: $^OS_ERROR" unless defined $pid;
    close($pid ?? $child !! $parent);
    $pid;
}

my ($parent, $child);

open $parent, "<", '';
open $child, "<", '';
if (pipe_to_fork($parent, $child)) {
    # parent
    print $parent, "pipe_to_fork\n";
    close $parent;
}
else {
    # child
    while (~< $child) { print $^STDOUT, $_; }
    close $child;
    exit;
}

sub pipe_from_fork ($parent, $child) {
    pipe($parent, $child) or die;
    my $pid = fork();
    die "fork() failed: $^OS_ERROR" unless defined $pid;
    close($pid ?? $child !! $parent);
    $pid;
}

if (pipe_from_fork($parent, $child)) {
    # parent
    while (~< $parent) { print $^STDOUT, $_; }
    close $parent;
}
else {
    # child
    print $child, "pipe_from_fork\n";
    close $child;
    exit;
}
EXPECT
pipe_from_fork
pipe_to_fork
########
$^OUTPUT_AUTOFLUSH=1;
if (my $pid = fork()) {
    print $^STDOUT, "forked first kid\n";
    print $^STDOUT, "waitpid() returned ok\n" if waitpid($pid,0) == $pid;
}
else {
    print $^STDOUT, "first child\n";
    exit(0);
}
if (my $pid = fork()) {
    print $^STDOUT, "forked second kid\n";
    print $^STDOUT, "wait() returned ok\n" if wait() == $pid;
}
else {
    print $^STDOUT, "second child\n";
    exit(0);
}
EXPECT
forked first kid
first child
waitpid() returned ok
forked second kid
second child
wait() returned ok
########
pipe(my $rdr, my $wtr) or die $^OS_ERROR;
my $pid = fork;
die "fork: $^OS_ERROR" if !defined $pid;
if ($pid == 0) {
    my $rand_child = rand;
    close $rdr;
    print $wtr, $rand_child, "\n";
    close $wtr;
} else {
    my $rand_parent = rand;
    close $wtr;
    chomp(my $rand_child  = ~< $rdr);
    close $rdr;
    print $^STDOUT, $rand_child ne $rand_parent, "\n";
}
EXPECT
1
########
# [perl #39145] Perl_dounwind() crashing with Win32's fork() emulation
sub { @_ = @: 3; fork ?? die "1" !! die "1" }->(2);
EXPECT
1 at - line 2 character 37.
    main::__ANON__ called at - line 2 character 46.
1 at - line 2 character 26.
    main::__ANON__ called at - line 2 character 46.
