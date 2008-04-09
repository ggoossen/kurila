
# Test p55, the "Perl 5 to Perl 5" translator.

# The perl core should have MAD enabled ('sh Configure -Dmad=y ...')

# The part to convert xml to Perl 5 requires XML::Parser, but it does
# not depend on Perl internals, so you can use a stable system wide
# perl

# For the p55 on the perl test suite, it should be started from the
# $perlsource/t subdir

# Instructions:
#     sh Configure -Dmad=y
#     make && make test
#     cd t && /usr/bin/prove ../mad/t/p55.t

use 5.8.8;

use strict;
use warnings;

BEGIN {
    push @INC, "../mad";
}

use Test::More qw|no_plan|;
use Test::Differences;
use IO::Handle;

use Nomad;

sub p55 {
    my ($input, $msg) = @_;

    # perl5 to xml
    open my $infile, "> tmp.in";
    $infile->print($input);
    close $infile;

    unlink "tmp.xml";
    my $returncode = system("PERL_XMLDUMP='tmp.xml' ../perl -I ../lib tmp.in 2> tmp.err");

    if (-z "tmp.xml") {
        ok 0, "MAD dump of '$input' failed: $msg" or $TODO or die;
        return;
    }
    my $output = eval { Nomad::xml_to_p5( input => "tmp.xml", version => "kurila-1.9" ) };
    diag($@) if $@;
    is($output, $input, $msg) or $TODO or die;
}

sub p55_file {
    my $file = shift;
    my $input;
    local $/ = undef;
    #warn $file;
    open(my $fh, "<", "$file") or die "Failed open '../t/$file' $!";
    $input = $fh->getline;
    close $fh or die;

    my $switches = "";
    if( $input =~ m/^[#][!].*perl(.*)/) {
        $switches = $1;
    }

    unlink "tmp.xml";
    my $returncode = system("PERL_XMLDUMP='tmp.xml' ../perl $switches -I ../lib $file 2> tmp.err > tmp.err");
    if (($returncode >> 8) == 2) {
        # exitcode '2' means a exit 0 in a BEGIN block.
      SKIP: { skip "$file has a 'exit 0' in a BEGIN block", 1; }
        return;
    }
    if ($returncode) {
        fail "MAD dump of '$file' failed.";
        return;
    }

    if (-z "tmp.xml") {
        fail "MAD dump failure of '$file'";
        return;
    }
    my $output = eval { Nomad::xml_to_p5( input => "tmp.xml", version => "kurila-1.9" ) };
    if ($@) {
        fail "convert xml to p5 failed file: '$file'";
        #$TODO or die;
        #diag "error: $@";
        return;
    }
    # ok($output eq $input, "p55 '$file'");
    eq_or_diff $output, $input, "p55 '$file'";
}

undef $/;
my @prgs = split m/^########\n/m, <DATA>;

use bytes;

for my $prog (@prgs) {
    my $msg = ($prog =~ s/^#(.*)\n//) && $1;
    local $TODO = ($msg =~ /TODO/) ? 1 : 0;
    p55($prog, $msg);
}

# Files
use File::Find;

our %failing = map { $_, 1 } qw|
../t/op/switch.t

../t/op/attrhand.t

../t/op/symbolcache.t

../t/op/exec.t

|;

my @files;
find( sub { push @files, $File::Find::name if m/[.]t$/ }, '../t/');

$ENV{PERL_CORE} = 1;

for my $file (@files) {
    local $TODO = (exists $failing{$file} ? "Known failure" : undef);
    p55_file($file);
}

__DATA__
use strict;
#ABC
Foo->new;
########
sub pi() { 3.14 }
my $x = pi;
########
-OS_Code => $a
########
# TODO
use encoding 'euc-jp';
tr/¤¡-¤ó¥¡-¥ó/¥¡-¥ó¤¡-¤ó/;
########
sub ok($$) { }
#BEGIN { ok(1, 2, ); }
########
for (my $i=0; $i+<3; $i++) { }
########
for (; $a+<3; $a++) { }
########
#
s//{$#foo}/g;
########
#
s//{m#.#}/g;
########
# Reduced test case from t/io/layers.t
sub PerlIO::F_UTF8 () { 0x00008000 } # from perliol.h
BEGIN { PerlIO::Layer->find("encoding",1);}
########
# from ../t/op/array.t
$[ = 1
########
# from t/comp/parser.t
$x = 1 for ($[) = 0;
########
# from t/op/getppid.t
pipe my ($r, $w)
########
# TODO switch
use feature 'switch';
given(my $x = "bar") { }
########
# TODO attribute t/op/attrhand.t
sub something : TypeCheck(
    QNET::Util::Object,
    QNET::Util::Object,
    QNET::Util::Object
) { #           WrongAttr (perl tokenizer bug)
    # keep this ^ lined up !
    return 42;
}
########
# TODO symbol table t/op/symbolcache.t
sub replaced2 { 'func' }
BEGIN { undef $main::{replaced2} }
########
# TODO exit in begin block. from t/op/threads.t without threads
BEGIN {
    exit 0;
}
use foobar;
########
# operator with modify TARGET_MY
my $nc_attempt;
$nc_attempt = 0+ ($within eq 'other_sub') ;
########
# __END__ section
$foo

__END__
DATA
########
# split with PUSHRE
@prgs = split "\n########\n", ~< DATA;
########
# unless(eval { })
unless (eval { $a }) { $a = $b }
########
# local our $...
local our $TODO
########
# 'my' inside prototyped subcall
sub ok($;$) { }
ok my $x = "foobar";
########
# LABLE without a statement.
 LABLE: ;
 LABLE: $a;
########
# TODO do not execute CHECK block
CHECK { die; }
########
# new named method call syntax
Foo->?$bar();
########
# pod with invalid UTF-8
=head3 Gearman

I know Ask Bj�rn Hansen has implemented a transport for the C<gearman> distributed
job system, though it's not on CPAN at the time of writing this.

=cut
########
@INC = qw(foo bar);
########
if (int(1.23) == 1) { print "1"; } else { print "2"; }
########
# TODO state; op_once
state $x = 4;
########
my $x;
"$x->@"
########
$a =~ regex;
########
$a !~ tr/a-z//;
########
s/foo/$bar/;
s/$foo/$bar/;
########
$a =~ s/$foo/$bar/;
########
my $msg = "ce ºtii tu, bã ?\n";
use utf8;
my $msg = "ce ºtii tu, bã ?\n";
