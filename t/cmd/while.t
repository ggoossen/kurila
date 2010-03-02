#!./perl

print: $^STDOUT, "1..22\n"

(open: my $tmp, ">",'Cmd_while.tmp') || die: "Can't create Cmd_while.tmp."
print: $tmp, "tvi925\n"
print: $tmp, "tvi920\n"
print: $tmp, "vt100\n"
print: $tmp, "Amiga\n"
print: $tmp, "paper\n"
close $tmp or die: "Could not close: $^OS_ERROR"

print: $^STDOUT, "ok 1\n"
print: $^STDOUT, "ok 2\n"
print: $^STDOUT, "ok 3\n"
print: $^STDOUT, "ok 4\n"
print: $^STDOUT, "ok 5\n"

# test "next" command

my $bad = ''
my $badcont = 1
(open: my $fh, "<",'Cmd_while.tmp') || die: "Can't open Cmd_while.tmp."
:entry while ( ~< $fh->*)
    next entry if m/vt100/
    $bad = 1 if m/vt100/
continue
    $badcont = '' if m/vt100/

if (!(eof: \$fh->*) || m/vt100/ || $bad) {print: $^STDOUT, "not ok 6\n";} else {print: $^STDOUT, "ok 6\n";}
if (!$badcont) {print: $^STDOUT, "ok 7\n";} else {print: $^STDOUT, "not ok 7\n";}

# test "redo" command

$bad = ''
$badcont = ''
(open: $fh, "<",'Cmd_while.tmp') || die: "Can't open Cmd_while.tmp."
:vtloop while ( ~< $fh->*)
    if (s/vt100/VT100/g)
        s/VT100/Vt100/g
        redo 'vtloop'

    $bad = 1 if m/vt100/
    $bad = 1 if m/VT100/
continue
    $badcont = 1 if m/vt100/

if (!(eof: \$fh->*) || $bad) {print: $^STDOUT, "not ok 8\n";} else {print: $^STDOUT, "ok 8\n";}
if (!$badcont) {print: $^STDOUT, "ok 9\n";} else {print: $^STDOUT, "not ok 9\n";}

(close: $fh) || die: "Can't close Cmd_while.tmp."
unlink: 'Cmd_while.tmp' || `/bin/rm Cmd_While.tmp`

#$x = 0;
#while (1) {
#    if ($x > 1) {last;}
#    next;
#} continue {
#    if ($x++ > 10) {last;}
#    next;
#}
#
#if ($x < 10) {print "ok 10\n";} else {print "not ok 10\n";}

my $i = 9
do
    $i++

print: $^STDOUT, "ok $i\n"

# Check curpm is reset when jumping out of a scope
'abc' =~ m/b/p
:WHILE
    while (1)
    $i++
    print: $^STDOUT, "not " unless $^PREMATCH . $^MATCH . $^POSTMATCH eq "abc"
    print: $^STDOUT, "ok $i\n"
    do                             # Localize changes to $` and friends
        'end' =~ m/end/p
        redo WHILE if $i == 11
        next WHILE if $i == 12
        # 13 do a normal loop
        last WHILE if $i == 14
    

$i++
print: $^STDOUT, "not " unless $^PREMATCH . $^MATCH . $^POSTMATCH eq "abc"
print: $^STDOUT, "ok $i\n"

# check that scope cleanup happens right when there's a continue block
do
    my $var = 16
    while (my $i = ++$var)
        next if $i == 17
        last if $i +> 17
        my $i = 0
    continue
        print: $^STDOUT, "ok ", $var-1, "\nok $i\n"
    


print: $^STDOUT, "ok 18\n"

our $l
do
    local $l = 19
    my $x = 0
    while (!$x++)
        local $l = 0
    continue
        print: $^STDOUT, "ok $l\n"
    


$i = 20
do
    while (1)
        my $x
        print: $^STDOUT, $x if defined $x
        $x = "not "
        (print: $^STDOUT, "ok $i\n"); ++$i
        if ($i == 21)
            next
        
        last
    continue
        (print: $^STDOUT, "ok $i\n"); ++$i
    

