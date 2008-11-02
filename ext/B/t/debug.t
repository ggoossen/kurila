#!./perl

$|  = 1;
use warnings;

use Config;
use Test::More tests=>3;

my $a;
my $Is_VMS = $^O eq 'VMS';
my $Is_MacOS = $^O eq 'MacOS';

my $path = join " ", map { qq["-I$_"] } @INC;
my $redir = $Is_MacOS ? "" : "2>&1";

$a = `$^X $path "-MO=Debug" -e 1 $redir`;
like($a, qr/\bLISTOP\b.*\bOP\b.*\bCOP\b.*\bOP\b/s);


$a = `$^X $path "-MO=Terse" -e 1 $redir`;
like($a, qr/\bLISTOP\b.*leave.*\n    OP\b.*enter.*\n    COP\b.*nextstate.*\n    OP\b.*null/s);

$a = `$^X $path "-MO=Terse" -ane "s/foo/bar/" $redir`;
$a =~ s/\(0x[^)]+\)//g;
$a =~ s/\[[^\]]+\]//g;
$a =~ s/-e syntax OK//;
$a =~ s/[^a-z ]+//g;
$a =~ s/\s+/ /g;
$a =~ s/\b(s|foo|bar|ullsv)\b\s?//g;
$a =~ s/^\s+//;
$a =~ s/\s+$//;
my $is_thread = %Config{use5005threads} && %Config{use5005threads} eq 'define';
if ($is_thread) {
    $b=<<EOF;
leave enter nextstate label leaveloop enterloop null and defined null
threadsv readline rvgv gv lineseq nextstate sassign null pushmark split pushre
threadsv const null pushmark rvav gv nextstate subst const unstack
EOF
} else {
    $b=<<EOF;
leave enter nextstate label leaveloop enterloop null and defined null
padsv readline rvgv gv lineseq leave enter nextstate sassign split pushre
padsv const rvav gv nextstate subst const unstack
EOF
}
$b=~s/\n/ /g;$b=~s/\s+/ /g;
$b =~ s/\s+$//;
is($a, $b);

