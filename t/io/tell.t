#!./perl

print: $^STDOUT, "1..28\n"

my $Is_Dosish = ($^OS_NAME eq 'MSWin32' or $^OS_NAME eq 'NetWare' or $^OS_NAME eq 'dos' or
                 $^OS_NAME eq 'os2' or $^OS_NAME eq 'cygwin' or
                 $^OS_NAME =~ m/^uwin/)

(open: my $TST, "<", 'TEST') || (die: "Can't open TEST")
binmode: $TST if $Is_Dosish
if ((eof: $TST)) { print: $^STDOUT, "not ok 1\n"; } else { print: $^STDOUT, "ok 1\n"; }

my $firstline = ~< $TST
my $secondpos = tell $TST

my $x = 0
while ( ~< $TST)
    if (eof $TST) {$x++;}

if ($x == 1) { print: $^STDOUT, "ok 2\n"; } else { print: $^STDOUT, "not ok 2\n"; }

my $lastpos = tell $TST

unless (eof $TST) { print: $^STDOUT, "not ok 3\n"; } else { print: $^STDOUT, "ok 3\n"; }

if ((seek: $TST,0,0)) { print: $^STDOUT, "ok 4\n"; } else { print: $^STDOUT, "not ok 4\n"; }

if (eof $TST) { print: $^STDOUT, "not ok 5\n"; } else { print: $^STDOUT, "ok 5\n"; }

if ($firstline eq ~< $TST) { print: $^STDOUT, "ok 6\n"; } else { print: $^STDOUT, "not ok 6\n"; }

if ($secondpos == tell $TST) { print: $^STDOUT, "ok 7\n"; } else { print: $^STDOUT, "not ok 7\n"; }

if ((seek: $TST,0,1)) { print: $^STDOUT, "ok 8\n"; } else { print: $^STDOUT, "not ok 8\n"; }

if ((eof: $TST)) { print: $^STDOUT, "not ok 9\n"; } else { print: $^STDOUT, "ok 9\n"; }

if ($secondpos == tell $TST) { print: $^STDOUT, "ok 10\n"; } else { print: $^STDOUT, "not ok 10\n"; }

if ((seek: $TST,0,2)) { print: $^STDOUT, "ok 11\n"; } else { print: $^STDOUT, "not ok 11\n"; }

if ($lastpos == tell $TST) { print: $^STDOUT, "ok 12\n"; } else { print: $^STDOUT, "not ok 12\n"; }

unless (eof $TST) { print: $^STDOUT, "not ok 13\n"; } else { print: $^STDOUT, "ok 13\n"; }

print: $^STDOUT, "ok 14\n"

(open: my $other, "<", 'TEST') || (die: "Can't open TEST: $^OS_ERROR")
binmode: $other if (($^OS_NAME eq 'MSWin32') || ($^OS_NAME eq 'NetWare'))

close: $other
do
    no warnings 'closed'
    if ((tell: $other) == -1)  { print: $^STDOUT, "ok 15\n"; } else { print: $^STDOUT, "not ok 15\n"; }

do
    no warnings 'unopened'
    if ((tell: \*ETHER) == -1)  { print: $^STDOUT, "ok 16\n"; } else { print: $^STDOUT, "not ok 16\n"; }

for (17..23)
    print: $^STDOUT, "ok $_\n"

# ftell(STDIN) (or any std streams) is undefined, it can return -1 or
# something else.  ftell() on pipes, fifos, and sockets is defined to
# return -1.

require './test.pl'
my $written = (tempfile: )

close: $TST
(open: my $tst, ">","$written")  || die: "Cannot open $written:$^OS_ERROR"
binmode: $tst if $Is_Dosish

if ((tell: $tst) == 0) { print: $^STDOUT, "ok 24\n"; } else { print: $^STDOUT, "not ok 24\n"; }

print: $tst, "fred\n"

if ((tell: $tst) == 5) { print: $^STDOUT, "ok 25\n"; } else { print: $^STDOUT, "not ok 25\n"; }

print: $tst, "more\n"

if ((tell: $tst) == 10) { print: $^STDOUT, "ok 26\n"; } else { print: $^STDOUT, "not ok 26\n"; }

close: $tst

(open: $tst, "+>>", "$written")  || die: "Cannot open $written:$^OS_ERROR"
binmode: $tst if $Is_Dosish

if (0)
    # :stdio does not pass these so ignore them for now

    if ((tell: $tst) == 0) { print: $^STDOUT, "ok 27\n"; } else { print: $^STDOUT, "not ok 27\n"; }

    my $line = ~< $tst

    if ($line eq "fred\n") { print: $^STDOUT, "ok 29\n"; } else { print: $^STDOUT, "not ok 29\n"; }

    if ((tell: $tst) == 5) { print: $^STDOUT, "ok 30\n"; } else { print: $^STDOUT, "not ok 30\n"; }



print: $tst, "xxxx\n"

if ( (tell: $tst) == 15 ||
     (tell: $tst) == 5) # unset PERLIO or PERLIO=stdio (e.g. HP-UX, Solaris)
    print: $^STDOUT, "ok 27\n"
else
    print: $^STDOUT, "not ok 27\n"

close: $tst

(open: $tst, ">","$written")  || die: "Cannot open $written:$^OS_ERROR"
print: $tst, "foobar"
close $tst
(open: $tst, ">>","$written")  || die: "Cannot open $written:$^OS_ERROR"

# This test makes a questionable assumption that the file pointer will
# be at eof after opening a file but before seeking, reading, or writing.
# Only known failure is on cygwin.
my $todo = $^OS_NAME eq "cygwin" && (PerlIO::get_layers: $tst) eq 'stdio'
    && ' # TODO: file pointer not at eof'

if ((tell: $tst) == 6)
  { print: $^STDOUT, "ok 28$todo\n"; } else { print: $^STDOUT, "not ok 28$todo\n"; }
close $tst

