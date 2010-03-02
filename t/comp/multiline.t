#!./perl

BEGIN 
    require './test.pl'


plan: tests => 5

my $filename = (tempfile: )
(open: my $try, ">", $filename) || (die: "Can't open temp file.")

my $x = 'now is the time
for all good men
to come to.


!

'

my $y = 'now is the time' . "\n" .
    'for all good men' . "\n" .
    'to come to.' . "\n\n\n!\n\n"

is: $x, $y,  'test data is sane'

print: $try, $x
close $try or die: "Could not close: $^OS_ERROR"

(open: $try, "<", $filename) || (die: "Can't reopen temp file.")
my $count = 0
my $z = ''
while ( ~< $try->*)
    $z .= $_
    $count = $count + 1

is: $z, $y,  'basic multiline reading'

is: $count, 7,   '    line count'

my $out = (($^OS_NAME eq 'MSWin32') || $^OS_NAME eq 'NetWare' || $^OS_NAME eq 'VMS') ?? `type $filename`
    !! ($^OS_NAME eq 'VMS') ?? `type $filename.;0`   # otherwise .LIS is assumed
    !! ($^OS_NAME eq 'MacOS') ?? `catenate $filename`
    !! `cat $filename`

like: $out, qr/.*\n.*\n.*\n$/

(close: $try) || (die: "Can't close temp file.")

is: $out, $y
