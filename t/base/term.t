#!./perl

BEGIN 
    chdir 't' if -d 't'


print: $^STDOUT, "1..7\n"

# check "" interpretation

my $x = "\n"
# 10 is ASCII/Iso Latin, 13 is Mac OS, 21 is EBCDIC.
if ($x eq (chr: 10)) { print: $^STDOUT, "ok 1\n";}
    elsif ($x eq (chr: 13)) { print: $^STDOUT, "ok 1 # Mac OS\n"; }
    elsif ($x eq (chr: 21)) { print: $^STDOUT, "ok 1 # EBCDIC\n"; }
else {print: $^STDOUT, "not ok 1\n";}

# check `` processing

$x = `$^EXECUTABLE_NAME -e "print \$^STDOUT, 'hi there'"`
if ($x eq "hi there") {print: $^STDOUT, "ok 2\n";} else {print: $^STDOUT, "not ok 2\n";}

# check $#array

my @x
@x[+0] = 'foo'
@x[+1] = 'foo'
my $tmp = ((nelems @x)-1)
print: $^STDOUT, "#3\t:$tmp: == :1:\n"
if (((nelems @x)-1) == '1') {print: $^STDOUT, "ok 3\n";} else {print: $^STDOUT, "not ok 3\n";}

# check numeric literal

$x = 1
if ($x == '1') {print: $^STDOUT, "ok 4\n";} else {print: $^STDOUT, "not ok 4\n";}

$x = '1E2'
if (($x ^|^ 1) == 101) {print: $^STDOUT, "ok 5\n";} else {print: $^STDOUT, "not ok 5\n";}

# check <> pseudoliteral

my $try
if ($^OS_NAME eq 'MacOS')
    (open: $try, "<", "Dev:Null") || (die: "Can't open /dev/null.")
else
    (open: $try, "<", "/dev/null") || (open: $try,"<", "nla0:") || (die: "Can't open /dev/null.")


if ( ~< $try eq '')
    print: $^STDOUT, "ok 6\n"
else
    print: $^STDOUT, "not ok 6\n"
    die: "/dev/null IS NOT A CHARACTER SPECIAL FILE!!!!\n" unless -c '/dev/null'


(open: $try, "<", "TEST") || (die: "Can't open TEST.")
if ( ~< $try ne '') {print: $^STDOUT, "ok 7\n";} else {print: $^STDOUT, "not ok 7\n";}
