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

my $a;
my $Is_VMS = $^O eq 'VMS';
if ($Is_VMS) { 
    $^X = "MCR $^X";
    $a = `$^X "-I../lib" "-MO=Deparse" -anle "1"`;
}
else {
    $a = `$^X -I../lib -MO=Deparse -anle 1 2>&1`;
}
$a =~ s/-e syntax OK\n//g;
$b = <<'EOF';

LINE: while (defined($_ = <ARGV>)) {
    chomp $_;
    @F = split(/\s+/, $_, 0);
    '???'
}
continue {
    '???'
}

EOF
print "# [$a]\n\# vs\n# [$b]\nnot " if $a ne $b;
ok;

#6
if ($Is_VMS) { 
    $a = `$^X "-I../lib" "-MO=Debug" -e "1"`;
}
else {
    $a = `$^X -I../lib -MO=Debug -e 1 2>&1`;
}
print "not " unless $a =~
/\bLISTOP\b.*\bOP\b.*\bCOP\b.*\bOP\b/s;
ok;

#7
if ($Is_VMS) { 
    $a = `$^X "-I../lib" "-MO=Terse" -e "1"`;
}
else {
    $a = `$^X -I../lib -MO=Terse -e 1 2>&1`;
}
print "not " unless $a =~
/\bLISTOP\b.*leave.*\bOP\b.*enter.*\bCOP\b.*nextstate.*\bOP\b.*null/s;
ok;

if ($Is_VMS) { 
    $a = `$^X "-I../lib" "-MO=Terse" -ane "s/foo/bar/"`;
}
else {
    $a = `$^X -I../lib -MO=Terse -ane "s/foo/bar/" 2>&1`;
}
$a =~ s/\(0x[^)]+\)//g;
$a =~ s/\[[^\]]+\]//g;
$a =~ s/-e syntax OK//;
$a =~ s/[^a-z ]+//g;
$a =~ s/\s+/ /g;
$a =~ s/\b(s|foo|bar|ullsv)\b\s?//g;
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

if ($Is_VMS) {
    chomp($a = `$^X "-I../lib" "-MB::Stash" "-Mwarnings" -e "1"`);
}
else {
    chomp($a = `$^X -I../lib -MB::Stash -Mwarnings -e1`);
}
$a = join ',', sort split /,/, $a;
$a =~ s/-uWin32,// if $^O eq 'MSWin32';
$a =~ s/-u(Cwd|File|File::Copy|OS2),//g if $^O eq 'os2';
if ($Config{static_ext} eq ' ') {
  $b = '-uCarp,-uCarp::Heavy,-uDB,-uExporter,-uExporter::Heavy,-uattributes,'
     . '-umain,-uwarnings';
  print "# [$a] vs [$b]\nnot " if $a ne $b;
  ok;
} else {
  print "ok $test # skipped: one or more static extensions\n"; $test++;
}

if ($Is_VMS) {
    $a = `$^X "-I../lib" "-MO=Showlex" -e "my %one"`;
}
else {
    $a = `$^X -I../lib -MO=Showlex -e "my %one" 2>&1`;
}
print "# [$a]\nnot " unless $a =~ /sv_undef.*PVNV.*%one.*sv_undef.*HV/s;
ok;
