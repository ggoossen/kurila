#!./perl

$^OUTPUT_AUTOFLUSH  = 1
use warnings

use Config
use Test::More tests=>3

my $a
my $Is_VMS = $^OS_NAME eq 'VMS'
my $Is_MacOS = $^OS_NAME eq 'MacOS'

my $path = join: " ", map: { qq["-I$_"] }, $^INCLUDE_PATH
my $redir = $Is_MacOS ?? "" !! "2>&1"

$a = `$^EXECUTABLE_NAME $path "-MO=Debug" -e 1 $redir`
like: $a, qr/\bLISTOP\b.*\bOP\b.*\bCOP\b.*\bOP\b/s


$a = `$^EXECUTABLE_NAME $path "-MO=Terse" -e 1 $redir`
like: $a, qr/\n    LISTOP\b.*leave.*\n        OP\b.*enter.*\n        COP\b.*nextstate.*\n        OP\b.*null/s

$a = `$^EXECUTABLE_NAME $path "-MO=Terse" -ane "s/foo/bar/" $redir`
$a =~ s/\(0x[^)]+\)//g
$a =~ s/\[[^\]]+\]//g
$a =~ s/-e syntax OK//
$a =~ s/[^a-z ]+//g
$a =~ s/\s+/ /g
$a =~ s/\b(s|foo|bar|ullsv)\b\s?//g
$a =~ s/^\s+//
$a =~ s/\s+$//
$b=<<EOF
leave enter nextstate label leaveloop enterloop null and defined null
padsv readline rvgv gv lineseq leave enter nextstate sassign split pushre
padsv const rvav gv nextstate subst const unstack
EOF
$b=~s/\n/ /g;$b=~s/\s+/ /g
$b =~ s/\s+$//
do
    local our $TODO = 1
    is: $a, $b


