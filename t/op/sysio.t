#!./perl

print: $^STDOUT, "1..44\n"

(chdir: 'op') || die: "sysio.t: cannot look for myself: $^OS_NAME"
$^INCLUDE_PATH = @: '../../lib'
require '../test.pl'

(open: my $i_fh, "<", 'sysio.t') || die: "sysio.t: cannot find myself: $^OS_ERROR"

my $reopen = ($^OS_NAME eq 'VMS' ||
           $^OS_NAME eq 'os2' ||
           $^OS_NAME eq 'MSWin32' ||
           $^OS_NAME eq 'NetWare' ||
           $^OS_NAME eq 'dos' ||
           $^OS_NAME eq 'mpeix')

my $x = 'abc'

# should not be able to do negative lengths
try { (sysread: $i_fh, $x, -1) }
print: $^STDOUT, 'not ' unless ($^EVAL_ERROR->{?description} =~ m/^Negative length/)
print: $^STDOUT, "ok 1\n"

# $x should be intact
print: $^STDOUT, 'not ' unless ($x eq 'abc')
print: $^STDOUT, "ok 2\n"

# should not be able to read before the buffer
try { (sysread: $i_fh, $x, 1, -4) }
print: $^STDOUT, 'not ' unless ($x eq 'abc')
print: $^STDOUT, "ok 3\n"

# $x should be intact
print: $^STDOUT, 'not ' unless ($x eq 'abc')
print: $^STDOUT, "ok 4\n"

$a ='0123456789'

# default offset 0
print: $^STDOUT, 'not ' unless((sysread: $i_fh, $a, 3) == 3)
print: $^STDOUT, "ok 5\n"

# $a should be as follows
print: $^STDOUT, 'not ' unless ($a eq '#!.')
print: $^STDOUT, "ok 6\n"

# reading past the buffer should zero pad
print: $^STDOUT, 'not ' unless((sysread: $i_fh, $a, 2, 5) == 2)
print: $^STDOUT, "ok 7\n"

# the zero pad should be seen now
print: $^STDOUT, 'not ' unless ($a eq "#!.\0\0/p")
print: $^STDOUT, "ok 8\n"

# try changing the last two characters of $a
print: $^STDOUT, 'not ' unless((sysread: $i_fh, $a, 3, -2) == 3)
print: $^STDOUT, "ok 9\n"

# the last two characters of $a should have changed (into three)
print: $^STDOUT, 'not ' unless ($a eq "#!.\0\0erl")
print: $^STDOUT, "ok 10\n"

my $outfile = (tempfile: )

(open: my $o_fh, ">", "$outfile") || die: "sysio.t: cannot write $outfile: $^OS_ERROR"

iohandle::output_autoflush: $o_fh, 1

# cannot write negative lengths
try { (syswrite: $o_fh, $x, -1) }
print: $^STDOUT, 'not ' unless ($^EVAL_ERROR->{?description} =~ m/^Negative length/)
print: $^STDOUT, "ok 11\n"

# $x still intact
print: $^STDOUT, 'not ' unless ($x eq 'abc')
print: $^STDOUT, "ok 12\n"

# $outfile still intact
print: $^STDOUT, 'not ' if (-s $outfile)
print: $^STDOUT, "ok 13\n"

# should not be able to write from after the buffer
try { (syswrite: $o_fh, $x, 1, 3) }
print: $^STDOUT, 'not ' unless ($^EVAL_ERROR->{?description} =~ m/^Offset outside string/)
print: $^STDOUT, "ok 14\n"

# $x still intact
print: $^STDOUT, 'not ' unless ($x eq 'abc')
print: $^STDOUT, "ok 15\n"

# $outfile still intact
if ($reopen)  # must close file to update EOF marker for stat
    close $o_fh; (open: $o_fh, ">>", "$outfile") || die: "sysio.t: cannot write $outfile: $^OS_ERROR"

print: $^STDOUT, 'not ' if (-s $outfile)
print: $^STDOUT, "ok 16\n"

# should not be able to write from before the buffer

try { (syswrite: $o_fh, $x, 1, -4) }
print: $^STDOUT, 'not ' unless ($^EVAL_ERROR->{?description} =~ m/^Offset outside string/)
print: $^STDOUT, "ok 17\n"

# $x still intact
print: $^STDOUT, 'not ' unless ($x eq 'abc')
print: $^STDOUT, "ok 18\n"

# $outfile still intact
if ($reopen)  # must close file to update EOF marker for stat
    close $o_fh; (open: $o_fh, ">>", "$outfile") || die: "sysio.t: cannot write $outfile: $^OS_ERROR"

print: $^STDOUT, 'not ' if (-s $outfile)
print: $^STDOUT, "ok 19\n"

# default offset 0
if ((syswrite: $o_fh, $a, 2) == 2)
    print: $^STDOUT, "ok 20\n"
else
    print: $^STDOUT, "# $^OS_ERROR\nnot ok 20\n"
    # most other tests make no sense after e.g. "No space left on device"
    die: $^OS_ERROR



# $a still intact
print: $^STDOUT, 'not ' unless ($a eq "#!.\0\0erl")
print: $^STDOUT, "ok 21\n"

# $outfile should have grown now
if ($reopen)  # must close file to update EOF marker for stat
    close $o_fh; (open: $o_fh, ">>", "$outfile") || die: "sysio.t: cannot write $outfile: $^OS_ERROR"

print: $^STDOUT, 'not ' unless (-s $outfile == 2)
print: $^STDOUT, "ok 22\n"

# with offset
print: $^STDOUT, 'not ' unless ((syswrite: $o_fh, $a, 2, 5) == 2)
print: $^STDOUT, "ok 23\n"

# $a still intact
print: $^STDOUT, 'not ' unless ($a eq "#!.\0\0erl")
print: $^STDOUT, "ok 24\n"

# $outfile should have grown now
if ($reopen)  # must close file to update EOF marker for stat
    close $o_fh; (open: $o_fh, ">>", "$outfile") || die: "sysio.t: cannot write $outfile: $^OS_ERROR"

print: $^STDOUT, 'not ' unless (-s $outfile == 4)
print: $^STDOUT, "ok 25\n"

# with negative offset and a bit too much length
print: $^STDOUT, 'not ' unless ((syswrite: $o_fh, $a, 5, -3) == 3)
print: $^STDOUT, "ok 26\n"

# $a still intact
print: $^STDOUT, 'not ' unless ($a eq "#!.\0\0erl")
print: $^STDOUT, "ok 27\n"

# $outfile should have grown now
if ($reopen)  # must close file to update EOF marker for stat
    close $o_fh; (open: $o_fh, ">>", "$outfile") || die: "sysio.t: cannot write $outfile: $^OS_ERROR"

print: $^STDOUT, 'not ' unless (-s $outfile == 7)
print: $^STDOUT, "ok 28\n"

# with implicit length argument
print: $^STDOUT, 'not ' unless ((syswrite: $o_fh, $x) == 3)
print: $^STDOUT, "ok 29\n"

# $a still intact
print: $^STDOUT, 'not ' unless ($x eq "abc")
print: $^STDOUT, "ok 30\n"

# $outfile should have grown now
if ($reopen)  # must close file to update EOF marker for stat
    close $o_fh; (open: $o_fh, ">>", "$outfile") || die: "sysio.t: cannot write $outfile: $^OS_ERROR"

print: $^STDOUT, 'not ' unless (-s $outfile == 10)
print: $^STDOUT, "ok 31\n"

(open: $i_fh, "<", $outfile) || die: "sysio.t: cannot read $outfile: $^OS_ERROR"

$b = 'xyz'

# reading too much only return as much as available
print: $^STDOUT, 'not ' unless ((sysread: $i_fh, $b, 100) == 10)
print: $^STDOUT, "ok 32\n"
# this we should have
print: $^STDOUT, 'not ' unless ($b eq '#!ererlabc')
print: $^STDOUT, "ok 33\n"

# test sysseek

print: $^STDOUT, 'not ' unless (sysseek: $i_fh, 2, 0) == 2
print: $^STDOUT, "ok 34\n"
sysread: $i_fh, $b, 3
print: $^STDOUT, 'not ' unless $b eq 'ere'
print: $^STDOUT, "ok 35\n"

print: $^STDOUT, 'not ' unless (sysseek: $i_fh, -2, 1) == 3
print: $^STDOUT, "ok 36\n"
sysread: $i_fh, $b, 4
print: $^STDOUT, 'not ' unless $b eq 'rerl'
print: $^STDOUT, "ok 37\n"

print: $^STDOUT, 'not ' unless (sysseek: $i_fh, 0, 0) eq '0 but true'
print: $^STDOUT, "ok 38\n"
print: $^STDOUT, 'not ' if defined sysseek: $i_fh, -1, 1
print: $^STDOUT, "ok 39\n"

close: $i_fh

unlink: $outfile

# Check that utf8 IO doesn't upgrade the scalar
(open: $i_fh, ">", "$outfile") || die: "sysio.t: cannot write $outfile: $^OS_ERROR"
# Will skip harmlessly on stdioperl
try {(binmode: $^STDOUT, ":utf8")}
die: $^EVAL_ERROR if $^EVAL_ERROR and $^EVAL_ERROR->{?description} !~ m/^IO layers \(like ':utf8'\) unavailable/

$a = "\x[FF]"

print: $^STDOUT, $a ne "\x[FF]" ?? "not ok 40\n" !! "ok 40\n"

syswrite: $i_fh, $a

# Should not be changed as a side effect of syswrite.
print: $^STDOUT, $a ne "\x[FF]" ?? "not ok 41\n" !! "ok 41\n"

# This should work
try {(syswrite: $i_fh, 2);}
print: $^STDOUT, $^EVAL_ERROR eq "" ?? "ok 42\n" !! "not ok 42 # $^EVAL_ERROR"

close: $i_fh
unlink: $outfile

chdir: '..'

# [perl #67912] syswrite prints garbage if called with empty scalar and non-zero offset
try { my $buf = ''; (syswrite: $o_fh, $buf, 1, 0) }
print: $^STDOUT, 'not ' unless ($^EVAL_ERROR->message =~ m/^Offset outside string /)
print: $^STDOUT, "ok 43\n"

try { my $buf = 'x'; (syswrite: $o_fh, $buf, 1, 1) }
print: $^STDOUT, 'not ' unless ($^EVAL_ERROR->message =~ m/^Offset outside string /)
print: $^STDOUT,  "ok 44\n"

close: $o_fh

1

# eof
