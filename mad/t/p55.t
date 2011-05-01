
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

use strict;
use warnings;

BEGIN {
    push @INC, "../mad";
}

use Test::More qw|no_plan|;
use IO::Handle;

use Nomad;

sub p55 {
    my ($input, $msg) = @_;

    # perl5 to xml
    open my $infile, "> tmp.in";
    $infile->print($input);
    close $infile;

    unlink "tmp.xml";
    `PERL_XMLDUMP='tmp.xml' ../perl -I ../lib tmp.in 2> tmp.err`;

    if (-z "tmp.xml") {
        return ok 0, "MAD dump failed $msg";
    }
    my $output = eval { Nomad::xml_to_p5( input => "tmp.xml" ) };
    diag($@) if $@;
    is($output, $input, $msg);
}

undef $/;
my @prgs = split m/^########\n/m, <DATA>;

use bytes;

for my $prog (@prgs) {
    my $msg = ($prog =~ s/^#(.*)\n//) && $1;
    local $TODO = ($msg =~ /TODO/) ? 1 : 0;
    p55($prog, $msg) or $TODO or die;
}

# Files
use File::Find;
use Test::Differences;

our %failing = map { $_, 1 } qw|
../t/run/switchd-78586.t
../t/run/switchp.t
../t/lib/cygwin.t
../t/comp/final_line_num.t
../t/comp/require.t
../t/re/regexp_unicode_prop.t
../t/op/exec.t
../t/op/symbolcache.t
../t/op/sub_lval.t
../t/op/attrhand.t
../t/op/state.t
../t/op/switch.t
|;

my @files;
find( sub { push @files, $File::Find::name if m/[.]t$/ }, '../t/');

for my $file (@files) {
    my $input;
    local $/ = undef;
    local $TODO = (exists $failing{$file} ? "Known failure" : undef);
    #warn $file;
    open(my $fh, "<", "$file") or die "Failed open '../t/$file' $!";
    $input = $fh->getline;
    close $fh or die;

    my $switches = "";
    if( $input =~ m/^[#][!].*perl(.*)/) {
        $switches = $1;
    }

    unlink "tmp.xml";
    `PERL_XMLDUMP='tmp.xml' ../perl $switches -I ../lib $file 2> tmp.err`;

    if (-z "tmp.xml") {
        fail "MAD dump failure of '$file'";
        next;
    }
    my $output = eval { Nomad::xml_to_p5( input => "tmp.xml" ) };
    if ($@) {
        fail "convert xml to p5 failed file: '$file'";
        diag "error: $@";
        next;
    }
    eq_or_diff $output, $input, "p55 '$file'";
}

__DATA__
use strict;
#ABC
new Foo;
Foo->new;
########
sub pi() { 3.14 }
my $x = pi;
########
-OS_Code => $a
########
use encoding 'euc-jp';
tr/¤¡-¤ó¥¡-¥ó/¥¡-¥ó¤¡-¤ó/;
########
sub ok($$) { }
BEGIN { ok(1, 2, ); }
########
for (my $i=0; $i<3; $i++) { }
########
for (; $a<3; $a++) { }
########
#
s//$#foo/ge;
########
#
s//m#.#/ge;
########
#
eval { require 5.005 }
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
# if modifier
"foo" if $x
########
# 'and' operator
$x and "foo"
########
# if statement
if ($x) { "foo" }
########
# unless modifier
"foo" unless $x
########
# 'or' operator
$x or "foo"
########
# qw-list
qw[a b c]
########
# range
3..5
########
# block
1;
{
   3;
}
########
# block with continue
1;
{
   3;
}
continue {
   1;
}
########
# double semi-colon
;;
########
# for loop
for my $i (1..3) {
    print $_;
}
########
# for loop while 'continue' block
for my $i (1..3) {
    print $_;
}
continue {
    1;
}
########
# for loop with non-lexical loop variable
for $i (1..3) {
    print $_;
}
########
# while
while (1) {
    print $_;
}
########
# while without cond
while () {
    print $_;
}
########
# while modifie
1 while $x;
########
# if else
if ($x) {
    3;
}
else {
    4;
}
########
# ? : operator
$x ? 1 : 2
########
package Foo;
########
package Foo {
    1;
}
########
# // operator
$x // $y
########
# ||= operator
$x ||= $y
########
# sub declaration
sub foo;
########
# glob
<*>
########
# hash element statement (removed ';')
$x{X};
########
# hash expression with ';
$x{x()  };
########
# TODO require version followed by whitespace/comment
require 5.005 # comment
;
########
# constant called with ()
use constant FOO => 1;
 FOO();
########
# smartmatch
$y ~~ $x
########
# aeach/akeys/avalues
each @a;
keys @a;
values @a;
########
# reach/rkeys/rvalues
each $x;
keys $x;
values $x;
########
# tr///r
tr/x/y/r;
########
# empty anon sub
sub {};
########
# anon sub with empty list
sub { () };
########
# sub with empty list
sub foo { () }
########
# s///e with empty eval.
s/x//ge
