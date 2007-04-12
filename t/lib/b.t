#!./perl

BEGIN {
    chdir 't' if -d 't';
    unshift @INC, '../lib';
}

$|  = 1;
use warnings;
use strict;
use Config;

print "1..10\n";

my $test = 1;

sub ok { print "ok $test\n"; $test++ }

use B::Deparse;
my $deparse = B::Deparse->new() or print "not ";
ok;

print "not " if "{\n    1;\n}" ne $deparse->coderef2text(sub {1});
ok;

print "not " if "{\n    '???';\n    2;\n}" ne
                    $deparse->coderef2text(sub {1;2});
ok;

print "not " if "{\n    \$test /= 2 if ++\$test;\n}" ne
                    $deparse->coderef2text(sub {++$test and $test/=2;});
ok;

my $a = `$^X -I../lib -MO=Deparse -anle 1 2>&1`;
$b = <<'EOF';
-e syntax OK

LINE: while (defined($_ = <ARGV>)) {
    chomp $_;
    @F = split(/\s+/, $_, 0);
    '???'
}
continue {
    '???'
}

EOF
print "not " if $a ne $b;
ok;

#6
$a = `$^X -I../lib -MO=Debug -e 1 2>&1`;
print "not " unless $a =~
/\bLISTOP\b.*\bOP\b.*\bCOP\b.*\bOP\b/s;
ok;

#7
$a = `$^X -I../lib -MO=Terse -e 1 2>&1`;
print "not " unless $a =~
/\bLISTOP\b.*leave.*\bOP\b.*enter.*\bCOP\b.*nextstate.*\bOP\b.*null/s;
ok;

$a = `$^X -I../lib -MO=Terse -ane 's/foo/bar/' 2>&1`;
$a =~ s/\(0x[^)]+\)//g;
$a =~ s/\[[^\]]+\]//g;
$a =~ s/-e syntax OK//;
$a =~ s/[^a-z ]+//g;
$a =~ s/\s+/ /g;
$a =~ s/\b(s|foo|ullsv)\b\s?//g;
$a =~ s/^\s+//;
$a =~ s/\s+$//;
$b=<<EOF;
leave enter nextstate label leaveloop enterloop null and defined null
null gvsv readline gv lineseq nextstate aassign null pushmark split pushre
null gvsv const null pushmark rvav gv nextstate subst const unstack
nextstate
EOF
$b=~s/\n/ /g;$b=~s/\s+/ /g;
$b =~ s/\s+$//;
print "# [$a] vs [$b]\nnot " if $a ne $b;
ok;

chomp($a = `$^X -I../lib -MB::Stash -Mwarnings -e1`);
$a = join ',', sort split /,/, $a;
$b = '-uCarp,-uCarp::Heavy,-uDB,-uExporter,-uExporter::Heavy,-uattributes,'
   . '-umain,-uwarnings';
print "# [$a] vs [$b]\nnot " if $a ne $b;
ok;

$a = `$^X -I../lib -MO=Showlex -e "my %one" 2>&1`;
print "# [$a]\nnot " unless $a =~ /sv_undef.*PVNV.*%one.*sv_undef.*HV/s;
ok;
