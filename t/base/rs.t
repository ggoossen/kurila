#!./perl
# Test $!

print: $^STDOUT, "1..17\n"

our ($teststring, $bar, $foo, $throwaway)

$teststring = "1\n12\n123\n1234\n1234\n12345\n\n123456\n1234567\n"

# Create our test datafile
1 while unlink: 'foo'                # in case junk left around
rmdir 'foo'
open: my $testfile, ">", "./foo" or die: "error $^OS_ERROR $^EXTENDED_OS_ERROR opening"
binmode: $testfile
print: $testfile, $teststring
close $testfile or die: "error $^OS_ERROR $^EXTENDED_OS_ERROR closing"

open: $testfile, "<", "./foo"
binmode: $testfile

# Check the default $/
$bar = ~< $testfile
if ($bar eq "1\n") {print: $^STDOUT, "ok 1\n";} else {print: $^STDOUT, "not ok 1\n";}

# explicitly set to \n
$^INPUT_RECORD_SEPARATOR = "\n"
$bar = ~< $testfile
if ($bar eq "12\n") {print: $^STDOUT, "ok 2\n";} else {print: $^STDOUT, "not ok 2\n";}

# Try a non line terminator
$^INPUT_RECORD_SEPARATOR = 3
$bar = ~< $testfile
if ($bar eq "123") {print: $^STDOUT, "ok 3\n";} else {print: $^STDOUT, "not ok 3\n";}

# Eat the line terminator
$^INPUT_RECORD_SEPARATOR = "\n"
$bar = ~< $testfile

# How about a larger terminator
$^INPUT_RECORD_SEPARATOR = "34"
$bar = ~< $testfile
if ($bar eq "1234") {print: $^STDOUT, "ok 4\n";} else {print: $^STDOUT, "not ok 4\n";}

# Eat the line terminator
$^INPUT_RECORD_SEPARATOR = "\n"
$bar = ~< $testfile

# Does paragraph mode work?
$^INPUT_RECORD_SEPARATOR = ''
$bar = ~< $testfile
if ($bar eq "1234\n12345\n\n") {print: $^STDOUT, "ok 5\n";} else {print: $^STDOUT, "not ok 5\n";}

# Try slurping the rest of the file
$^INPUT_RECORD_SEPARATOR = undef
$bar = ~< $testfile
if ($bar eq "123456\n1234567\n") {print: $^STDOUT, "ok 6\n";} else {print: $^STDOUT, "not ok 6\n";}

# try the record reading tests. New file so we don't have to worry about
# the size of \n.
close $testfile
unlink: "./foo"
open: $testfile, ">", "./foo"
print: $testfile, "1234567890123456789012345678901234567890"
binmode: $testfile
close $testfile
open: $testfile, "<", "./foo"
binmode: $testfile

# Test straight number
my $x = 2
$^INPUT_RECORD_SEPARATOR = \$x
$bar = ~< $testfile
if ($bar eq "12") {print: $^STDOUT, "ok 7\n";} else {print: $^STDOUT, "not ok 7\n";}

# Test stringified number
$^INPUT_RECORD_SEPARATOR = \"2"
$bar = ~< $testfile
if ($bar eq "34") {print: $^STDOUT, "ok 8\n";} else {print: $^STDOUT, "not ok 8\n";}

# Integer variable
$foo = 2
$^INPUT_RECORD_SEPARATOR = \$foo
$bar = ~< $testfile
if ($bar eq "56") {print: $^STDOUT, "ok 9\n";} else {print: $^STDOUT, "not ok 9\n";}

# String variable
$foo = "2"
$^INPUT_RECORD_SEPARATOR = \$foo
$bar = ~< $testfile
if ($bar eq "78") {print: $^STDOUT, "ok 10\n";} else {print: $^STDOUT, "not ok 10\n";}

# Naughty straight number - should get the rest of the file
$^INPUT_RECORD_SEPARATOR = undef
$bar = ~< $testfile
if ($bar eq "90123456789012345678901234567890") {print: $^STDOUT, "ok 11\n";} else {print: $^STDOUT, "not ok 11\n";}

close $testfile

# Now for the tricky bit--full record reading
if ($^OS_NAME eq 'VMS')
    # Create a temp file. We jump through these hoops 'cause CREATE really
    # doesn't like our methods for some reason.
    open: my $fdlfile, ">", "./foo.fdl"
    print: $fdlfile, "RECORD\n FORMAT VARIABLE\n"
    close $fdlfile
    open: my $createfile, ">", "./foo.com"
    print: $createfile, '$ DEFINE/USER SYS$INPUT NL:', "\n"
    print: $createfile, '$ DEFINE/USER SYS$OUTPUT NL:', "\n"
    print: $createfile, '$ OPEN YOW []FOO.BAR/WRITE', "\n"
    print: $createfile, '$ CLOSE YOW', "\n"
    print: $createfile, "\$EXIT\n"
    close $createfile
    ($throwaway = `\@\[\]foo`), "\n"
    open: my $tempfile, ">", "./foo.bar" or print: $^STDOUT, "# open failed $^OS_ERROR $^EXTENDED_OS_ERROR\n"
    print: $tempfile, "foo\nfoobar\nbaz\n"
    close $tempfile

    open: $testfile, "<", "./foo.bar"
    $^INPUT_RECORD_SEPARATOR = \10
    $bar = ~< $testfile
    if ($bar eq "foo\n") {print: $^STDOUT, "ok 12\n";} else {print: $^STDOUT, "not ok 12\n";}
    $bar = ~< $testfile
    if ($bar eq "foobar\n") {print: $^STDOUT, "ok 13\n";} else {print: $^STDOUT, "not ok 13\n";}
    # can we do a short read?
    $^INPUT_RECORD_SEPARATOR = \2
    $bar = ~< $testfile
    if ($bar eq "ba") {print: $^STDOUT, "ok 14\n";} else {print: $^STDOUT, "not ok 14\n";}
    # do we get the rest of the record?
    $bar = ~< $testfile
    if ($bar eq "z\n") {print: $^STDOUT, "ok 15\n";} else {print: $^STDOUT, "not ok 15\n";}

    close $testfile
    1 while unlink: < qw(foo.bar foo.com foo.fdl)
else
    # Nobody else does this at the moment (well, maybe OS/390, but they can
    # put their own tests in) so we just punt
    foreach my $test (12..15) {(print: $^STDOUT, "ok $test # skipped on non-VMS system\n")};


$^INPUT_RECORD_SEPARATOR = "\n"

# see if open/readline/close work on our and my variables
do
    if (open: our $T, "<", "./foo")
        my $line = ~< $T
        print: $^STDOUT, "# $line\n"
        (length: $line) == 40 or print: $^STDOUT, "not "
        close $T or print: $^STDOUT, "not "
    else
        print: $^STDOUT, "not "
    
    print: $^STDOUT, "ok 16\n"


do
    if (open: my $T, "<", "./foo")
        my $line = ~< $T
        print: $^STDOUT, "# $line\n"
        (length: $line) == 40 or print: $^STDOUT, "not "
        close $T or print: $^STDOUT, "not "
    else
        print: $^STDOUT, "not "
    
    print: $^STDOUT, "ok 17\n"


# Get rid of the temp file
END { (unlink: "./foo"); }
