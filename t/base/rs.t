#!./perl
# Test $!

print "1..17\n";

our ($teststring, $bar, $foo, $throwaway);

$teststring = "1\n12\n123\n1234\n1234\n12345\n\n123456\n1234567\n";

# Create our test datafile
1 while unlink 'foo';                # in case junk left around
rmdir 'foo';
open TESTFILE, ">", "./foo" or die "error $^OS_ERROR $^E opening";
binmode TESTFILE;
print TESTFILE $teststring;
close TESTFILE or die "error $^OS_ERROR $^E closing";

open TESTFILE, "<", "./foo";
binmode TESTFILE;

# Check the default $/
$bar = ~< *TESTFILE;
if ($bar eq "1\n") {print "ok 1\n";} else {print "not ok 1\n";}

# explicitly set to \n
$^INPUT_RECORD_SEPARATOR = "\n";
$bar = ~< *TESTFILE;
if ($bar eq "12\n") {print "ok 2\n";} else {print "not ok 2\n";}

# Try a non line terminator
$^INPUT_RECORD_SEPARATOR = 3;
$bar = ~< *TESTFILE;
if ($bar eq "123") {print "ok 3\n";} else {print "not ok 3\n";}

# Eat the line terminator
$^INPUT_RECORD_SEPARATOR = "\n";
$bar = ~< *TESTFILE;

# How about a larger terminator
$^INPUT_RECORD_SEPARATOR = "34";
$bar = ~< *TESTFILE;
if ($bar eq "1234") {print "ok 4\n";} else {print "not ok 4\n";}

# Eat the line terminator
$^INPUT_RECORD_SEPARATOR = "\n";
$bar = ~< *TESTFILE;

# Does paragraph mode work?
$^INPUT_RECORD_SEPARATOR = '';
$bar = ~< *TESTFILE;
if ($bar eq "1234\n12345\n\n") {print "ok 5\n";} else {print "not ok 5\n";}

# Try slurping the rest of the file
$^INPUT_RECORD_SEPARATOR = undef;
$bar = ~< *TESTFILE;
if ($bar eq "123456\n1234567\n") {print "ok 6\n";} else {print "not ok 6\n";}

# try the record reading tests. New file so we don't have to worry about
# the size of \n.
close TESTFILE;
unlink "./foo";
open TESTFILE, ">", "./foo";
print TESTFILE "1234567890123456789012345678901234567890";
binmode TESTFILE;
close TESTFILE;
open TESTFILE, "<", "./foo";
binmode TESTFILE;

# Test straight number
my $x = 2;
$^INPUT_RECORD_SEPARATOR = \$x;
$bar = ~< *TESTFILE;
if ($bar eq "12") {print "ok 7\n";} else {print "not ok 7\n";}

# Test stringified number
$^INPUT_RECORD_SEPARATOR = \"2";
$bar = ~< *TESTFILE;
if ($bar eq "34") {print "ok 8\n";} else {print "not ok 8\n";}

# Integer variable
$foo = 2;
$^INPUT_RECORD_SEPARATOR = \$foo;
$bar = ~< *TESTFILE;
if ($bar eq "56") {print "ok 9\n";} else {print "not ok 9\n";}

# String variable
$foo = "2";
$^INPUT_RECORD_SEPARATOR = \$foo;
$bar = ~< *TESTFILE;
if ($bar eq "78") {print "ok 10\n";} else {print "not ok 10\n";}

# Naughty straight number - should get the rest of the file
$^INPUT_RECORD_SEPARATOR = undef;
$bar = ~< *TESTFILE;
if ($bar eq "90123456789012345678901234567890") {print "ok 11\n";} else {print "not ok 11\n";}

close TESTFILE;

# Now for the tricky bit--full record reading
if ($^O eq 'VMS') {
  # Create a temp file. We jump through these hoops 'cause CREATE really
  # doesn't like our methods for some reason.
  open FDLFILE, ">", "./foo.fdl";
  print FDLFILE "RECORD\n FORMAT VARIABLE\n";
  close FDLFILE;
  open CREATEFILE, ">", "./foo.com";
  print CREATEFILE '$ DEFINE/USER SYS$INPUT NL:', "\n";
  print CREATEFILE '$ DEFINE/USER SYS$OUTPUT NL:', "\n";
  print CREATEFILE '$ OPEN YOW []FOO.BAR/WRITE', "\n";
  print CREATEFILE '$ CLOSE YOW', "\n";
  print CREATEFILE "\$EXIT\n";
  close CREATEFILE;
  $throwaway = `\@\[\]foo`, "\n";
  open(TEMPFILE, ">", "./foo.bar") or print "# open failed $^OS_ERROR $^E\n";
  print TEMPFILE "foo\nfoobar\nbaz\n";
  close TEMPFILE;

  open TESTFILE, "<", "./foo.bar";
  $^INPUT_RECORD_SEPARATOR = \10;
  $bar = ~< *TESTFILE;
  if ($bar eq "foo\n") {print "ok 12\n";} else {print "not ok 12\n";}
  $bar = ~< *TESTFILE;
  if ($bar eq "foobar\n") {print "ok 13\n";} else {print "not ok 13\n";}
  # can we do a short read?
  $^INPUT_RECORD_SEPARATOR = \2;
  $bar = ~< *TESTFILE;
  if ($bar eq "ba") {print "ok 14\n";} else {print "not ok 14\n";}
  # do we get the rest of the record?
  $bar = ~< *TESTFILE;
  if ($bar eq "z\n") {print "ok 15\n";} else {print "not ok 15\n";}

  close TESTFILE;
  1 while unlink < qw(foo.bar foo.com foo.fdl);
} else {
  # Nobody else does this at the moment (well, maybe OS/390, but they can
  # put their own tests in) so we just punt
  foreach my $test (12..15) {print "ok $test # skipped on non-VMS system\n"};
}

$^INPUT_RECORD_SEPARATOR = "\n";

# see if open/readline/close work on our and my variables
do {
    if (open our $T, "<", "./foo") {
        my $line = ~< $T;
	print "# $line\n";
	length($line) == 40 or print "not ";
        close $T or print "not ";
    }
    else {
	print "not ";
    }
    print "ok 16\n";
};

do {
    if (open my $T, "<", "./foo") {
        my $line = ~< $T;
	print "# $line\n";
	length($line) == 40 or print "not ";
        close $T or print "not ";
    }
    else {
	print "not ";
    }
    print "ok 17\n";
};

# Get rid of the temp file
END { unlink "./foo"; }
