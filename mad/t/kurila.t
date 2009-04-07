#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    push @INC, "../mad";
}

BEGIN {
    $ENV{madpath} or die "No madpath specified";
}

use IO::Handle;

use Test::More qw|no_plan|;

use Fatal qw|open close|;

use Convert;

my $from = 'kurila-1.18';
my $to = 'kurila-1.18';

sub p5convert {
    my ($input, $expected) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    local $TODO = $TODO || ($input =~ m/^[#]\s*TODO/);
    my $output = Convert::convert($input,
                                  "/usr/bin/env perl ../mad/p5kurila.pl --from $from",
                                  from => $from, to => $to,
                                  switches => "-I../lib",
                                  dumpcommand => "$ENV{madpath}/perl",
                                 );
    is($output, $expected) or $TODO or die "failed test";
}

t_local();
die "END";
t_stdin();
t_prototype();
t_must_haveargs();
t_block_arg();
t_print();
t_rename_inc_vars();
t_rename_magic_vars_2();
t_rename_magic_vars();
t_remove_vars();
t_env_using_package();
t_pattern_assignment();
t_hashkey_regulator();
t_rename_ternary_op();
t_call_parens();
t_remove_strict();
t_lval_vec();
t_block();
t_ampcall();
t_array_simplify();
t_map_array();
t_array_hash();
t_eval_to_try();
t_anon_aryhsh();
t_strict_vars();
t_no_bracket_names();
t_no_sigil_change();
#t_carp();
#t_parenthesis();
#t_change_deref();
#t_anon_hash();
t_error_str();
t_open_args3();
t_qstring();
t_subst_eval();
t_string_block();
t_force_m();
t_pointy_op();
t_lvalue_subs();
t_use_pkg_version();
t_vstring();

t_intuit_more();
t_change_deref_method();
t_remove_useversion();
t_rename_bit_operators();
t_typed_declaration();

t_strict_refs();
t_indirect_object_syntax();
t_barewords();
t_glob_pattr();
t_vstring();
# t_encoding();

sub t_indirect_object_syntax {
    p5convert( split(m/^\-{10}\n/m, $_, 2)) for split(m/^={10}\n/m, <<'END');
use strict;
#ABC
new Foo;
#DEF
Foo->new;
----------
use strict;
#ABC
Foo->new();
#DEF
Foo->new;
==========
use Test::More tests => 13;
----------
use Test::More tests => 13;
==========
new Foo @args;
----------
Foo->new( @args);
END

}


sub t_barewords {

    p5convert( split(m/^\-{10}\n/m, $_, 2)) for split(m/^={10}\n/m, <<'END');
bless {}, CLASS;
----------
bless {}, 'CLASS';
==========
require overload;
----------
require overload;
==========
foo => 'bar';
----------
foo => 'bar';
==========
{ foo => 'bar', noot => "mies" };
----------
{ foo => 'bar', noot => "mies" };
==========
$aap{noot};
----------
$aap{noot};
==========
exists $aap->{noot};
----------
exists $aap->{noot};
==========
Foo->new(-Level);
----------
Foo->new(-Level);
==========
$foo->SUPER::aap();
----------
$foo->SUPER::aap();
==========
sort Foo::aap 1,2,3;
----------
sort Foo::aap 1,2,3;
==========
sort aap 1,2,3;
----------
sort aap 1,2,3;
==========
open(IN, "aap");
----------
open(IN, "aap");
==========
-d _;
----------
-d _;
==========
Foo::Bar->new();
----------
Foo::Bar->new();
==========
truncate(FH, 0);
----------
truncate(*FH, 0);
==========
sub foo(*$) { }
foo(FH, STR);
----------
sub foo(*$) { }
foo(*FH, 'STR');
==========
$aap{noot::mies}
----------
$aap{'noot::mies'}
==========
use strict;
foo
----------
use strict;
foo
==========
Foo::->bar();
----------
Foo->bar();
END

}

sub t_strict_refs {
    p5convert( 'print {Symbol::fetch_glob("STDOUT")} "foo"',
               'print {Symbol::fetch_glob("STDOUT")} "foo"' );
    p5convert( 'print {"STDOUT"} "foo"',
               'print {Symbol::fetch_glob("STDOUT")} "foo"' );
    p5convert( 'my $pkg; *{$pkg . "::bar"} = sub { "foo" }',
               'my $pkg; *{Symbol::fetch_glob($pkg . "::bar")} = sub { "foo" }');
    p5convert( 'my $pkg; *{"$pkg\::bar"} = sub { "foo" }',
               'my $pkg; *{Symbol::fetch_glob("$pkg\::bar")} = sub { "foo" }');
    p5convert( 'my $pkg; ${$pkg . "::bar"} = "noot"',
               'my $pkg; ${*{Symbol::fetch_glob($pkg . "::bar")}} = "noot"');
    p5convert( 'my $pkg; @{$pkg . "::bar"} = ("noot", "mies")',
               'my $pkg; @{*{Symbol::fetch_glob($pkg . "::bar")}} = ("noot", "mies")');
    p5convert( 'my $pkg; %{$pkg . "::bar"} = { aap => "noot" }',
               'my $pkg; %{*{Symbol::fetch_glob($pkg . "::bar")}} = { aap => "noot" }');
    p5convert( 'my $pkg; &{$pkg . "::bar"} = sub { "foobar" }',
               'my $pkg; &{*{Symbol::fetch_glob($pkg . "::bar")}} = sub { "foobar" }');
    p5convert( 'my $pkg; defined &{$pkg . "::bar"}',
               'my $pkg; defined &{*{Symbol::fetch_glob($pkg . "::bar")}}');
    p5convert( '*$AUTOLOAD',
               '*{Symbol::fetch_glob($AUTOLOAD)}');
    p5convert( 'my $name = "foo"; *$name',
               'my $name = "foo"; *{Symbol::fetch_glob($name)}');
    p5convert( '*$globref',
               '*$globref');

    p5convert( 'my $pkg; keys %Package::',
               'my $pkg; keys %{Symbol::stash("Package")}');
    {
        local $TODO = 1;
        p5convert( 'my $pkg; $Package::{"var"}',
                   'my $pkg; ${Symbol::stash("Package")}{"var"}');
    }

    # Fix conversion of addition of additional ref
    p5convert( split(m/^\-{3}\n/m, $_, 2)) for split(m/^={3}\n/m, <<'END');
# finding strings
my $string = "s";
@$string = sub { 1 };
---
# finding strings
my $string = "s";
@{*{Symbol::fetch_glob($string)}} = sub { 1 };
===
my $string = "s";
@{$string} = sub { 1 };
---
my $string = "s";
@{*{Symbol::fetch_glob($string)}} = sub { 1 };
===
my $string;
$string =~ s/a/b/;
@{$string} = sub { 1 };
---
my $string;
$string =~ s/a/b/;
@{*{Symbol::fetch_glob($string)}} = sub { 1 };
===
my $x = "string";
sub foo {
  my $h;
  @{$h} = ();
}
---
my $x = "string";
sub foo {
  my $h;
  @{$h} = ();
}
===
# not if 'use strict'
use strict;
my $string = "s";
@$string = sub { 1 };
---
# not if 'use strict'
use strict;
my $string = "s";
@$string = sub { 1 };
===
# variable is a hard ref
my $ref = "s";
$ref = [];
@$ref = sub { 1 };
---
# variable is a hard ref
my $ref = "s";
$ref = [];
@$ref = sub { 1 };
===
my $subname = "bla";
$subname->();
---
my $subname = "bla";
*{Symbol::fetch_glob($subname)}->();
END

}

sub t_encoding {
    p5convert( qq|use encoding 'latin1';\n"\x85"|, qq|use encoding 'latin1';\n"\x85"|, 1 );
    p5convert( qq|"\x85"|, qq|use encoding 'latin1';\n"\x85"|, 1 );
}

sub t_glob_pattr {
    p5convert( split(m/^\-{10}.*\n/m, $_, 2)) for split(m/^={10}\n/m, <<'END');
<*.pm>;
glob("*.pm");
----------
glob("*.pm");
glob("*.pm");
==========
#ABC
<*.pm>;
----------
#ABC
glob("*.pm");
==========
# TODO
<$_/*.pm>;
----------
# TODO
glob("$_*.pm");
END
}

sub t_vstring {
    p5convert( split(m/^\-{10}\n/m, $_, 2)) for split(m/^={10}\n/m, <<'END');
v1.2.3.10;
"v1.2.3.10";
----------
"\x{1}\x{2}\x{3}\x{a}";
"v1.2.3.10";
==========
use vars;
{ version => 3 };
----------
use vars;
{ version => 3 };
==========
is($vs,"\x{1}\x{14}\x{12c}\x{fa0}","v-string ne \\x{}");
----------
is($vs,"\x{1}\x{14}\x{12c}\x{fa0}","v-string ne \\x{}");
==========
1 if /vt100/;
----------
1 if /vt100/;
==========
use version v0.2;
----------
use version v0.2;
==========
"foo$\value"
----------
"foo$\value"
==========
100.200.300
----------
"\x{64}\x{c8}\x{12c}"
END
}

sub t_typed_declaration {
    p5convert( split(m/^\-{10}\n/m, $_, 2)) for split(m/^={10}\n/m, <<'END');
package Foo;
my Foo $bar;
----------
package Foo;
my $bar;
==========
package Test;
my Test $x2 :Dokay(1,5);
----------
package Test;
my $x2 :Dokay(1,5);
END
}

sub t_remove_useversion {
    p5convert( split(m/^\-{10}.*\n/m, $_, 2)) for split(m/^={10}\n/m, <<'END');
#bla
use v5.6.0;
#arg
----------
#bla
#arg
==========
use version;
----------
use version;
==========
#foo
require 5.6;
#bar
require version;
----------
#foo
#bar
require version;
==========
require 5.6;
use version;
----------
use version;
==========
require 5;
----------
==========
BEGIN { require 5; }
----------
BEGIN {  }
==========
require 5.6.0;
----------
END
}

sub t_rename_bit_operators {
    p5convert( split(m/^\-{10}.*\n/m, $_, 2)) for split(m/^={10}\n/m, <<'END');
$a | $b;
----------
$a ^|^ $b;
==========
$a |= $b;
----------
$a ^|^= $b;
==========
$a || $b;
----------
$a || $b;
==========
~$a;
----------
^~^$a;
==========
$a & $b;
----------
$a ^&^ $b;
==========
$a ^ $b;
----------
$a ^^^ $b;
END
}

sub t_change_deref_method {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
Foo->$bar();
----
Foo->?$bar();
END
}

sub t_change_deref {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
Foo->$bar();
----
Foo->&$bar ;
====
my $x;
Foo->$x()
----
my $x;
Foo->&$x 
====
Foo->bar()
----
Foo->bar 
====
#ABC
@$foo;
#DEF
----
#ABC
$foo->@;
#DEF
====
@{[1,2,3]}
----
[1,2,3]->@
====
my ($x) = @_
----
my ($x) = @_
====
@{$foo||[]}
----
($foo||[])->@
====
@{$foo[1]}
----
$foo[1]->@
====
@{$foo{bar}}
----
$foo{bar}->@
====
$$foo
----
$foo->$
====
%$foo
----
$foo->%
====
*$foo
----
$foo->*
====
&$foo
----
$foo->&
====
sub foo { [2, 4] }
@{foo(1,2)}
----
sub foo { [2, 4] }
(foo 1,2)->@
====
$$foo[1]
----
$foo->@[1]
END
}

sub t_intuit_more {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
m/$foo[:]/
----
m/$foo(?:)[:]/
====
s/abc/[/;
----
s/abc/[/;
====
my $ldel1;
m/\G$ldel1(?:)[^\\$ldel1]*(\\.[^\\$ldel1]*)*$ldel1/gcs
----
my $ldel1;
m/\G$ldel1(?:)[^\\$ldel1]*(\\.[^\\$ldel1]*)*$ldel1/gcs
END
}

sub t_parenthesis {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
sub foo { }
foo(1, 2);
----
sub foo { }
foo 1, 2;
====
sub foo { }
#ABC
foo(1, 2)  +5
#DEF
----
sub foo { }
#ABC
(foo 1, 2)  +5
#DEF
====
sub foo { }
5+foo(1,2)
----
sub foo { }
5+(foo 1,2)
====
print ( (1,2,3));
----
print  (1,2,3);
====
#ABC
print(1) + 2;
----
#ABC
(print 1) + 2;
====
$a = lc($a);
----
$a = lc $a;
====
$a .= lc($a);
----
$a .= lc $a;
====
lc $a and uc $a
----
lc $a and uc $a
====
for (1..2) { }
----
for (1..2) { }
====
(@a)[1]
----
(@a)[1]
END
}

sub t_use_pkg_version {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
BEGIN {
    $Foo::VERSION = 0.9;
    $INC{'Foo.pm'} = 1;
}
use Foo 0.9;
----
BEGIN {
    $Foo::VERSION = 0.9;
    $INC{'Foo.pm'} = 1;
}
use Foo v0.9;
====
END
}

sub t_lvalue_subs {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
substr($a, 2) = "bar";
----
substr($a, 2, undef, "bar");
====
substr($a, 2, 3) = "bar";
----
substr($a, 2, 3, "bar");
====
$a = substr($a, 2);
----
$a = substr($a, 2);
====
$a = "foobar";
substr($a, 2) = "bar";
----
$a = "foobar";
substr($a, 2, undef, "bar");
====
END
}

sub t_force_m {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
$a =~ //;
----
$a =~ m//;
====
$a =~ m//;
$a =~ m**;
----
$a =~ m//;
$a =~ m**;
====
split //, "foo";
----
split m//, "foo";
END
}

sub t_pointy_op {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
my $fh;
my $x = <$fh>;
----
my $fh;
my $x = ~< $fh;
====
my @x = <FH>;
----
my @x = ~< *FH;
====
<>;
----
 ~< *ARGV;
====
$a=<F>;
----
$a= ~< *F;
====
$a .= <F>;
----
$a .= ~< *F;
====
3 < 4;
----
3 +< 4;
====
3 <= 4;
3 > 4;
3 >= 4;
----
3 +<= 4;
3 +> 4;
3 +>= 4;
====
3 <=> 4;
----
3 <+> 4;
====
use integer;
3<=>4;
3<4;
3>4;
----
use integer;
3<+>4;
3+<4;
3+>4;
====
END
}

sub t_anon_hash {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
{ foo => 'bar' };
----
< foo => 'bar' >;
====
{};
----
<>;
====
END

}

sub t_subst_eval {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
s/x/1/e;
----
s/x/{1}/;
====
s/x//eg;
----
s/x/{}/g;
====
s/(x)/uc($1)/eg;
----
s/(x)/{uc($1)}/g;
====
sub foo {}
s/(x)/foo($1)/eg;
----
sub foo {}
s/(x)/{foo($1)}/g;
====
END
}

sub t_open_args3 {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
open($fh,$filename);
----
open($fh, "<",$filename);
====
open $fh, ">$filename";
----
open $fh, ">", "$filename";
====
open $fh, ">> $filename";
----
open $fh, ">>", "$filename";
====
open $fh, ">filename";
----
open $fh, ">", "filename";
====
open FH, 'filename';
----
open FH, "<", 'filename';
====
open FH, 'echo "bar" |';
----
open FH, "-|", 'echo "bar"';
====
open FH, "$filename";
----
open FH, "<", "$filename";
====
open FH, ">&STDERR";
----
open FH, ">&", "STDERR";
====
my $TEST;
open IN, $TEST or warn "$0: cannot read $TEST: $!" ;
----
my $TEST;
open IN, "<", $TEST or warn "$0: cannot read $TEST: $!" ;
====
open(POD, "<$$.pod") or die "$$.pod: $!";
----
open(POD, "<", "$$.pod") or die "$$.pod: $!";
====
open $fh, "-";
open $fh, ">-";
----
open $fh, "-";
open $fh, ">-";
====
END
}

sub t_error_str {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
$@ =~ m/foo/;
----
$@->{description} =~ m/foo/;
====
is($@, '');
like($@, qr/foo/);
----
is($@, '');
like($@->{description}, qr/foo/);
====
$SIG{__DIE__} = 1;
----
$^DIE_HOOK = 1;
====
like($@->{description}, qr/foo/);
----
like($@->{description}, qr/foo/);
====
$SIG{'__WARN__'} = 1;
----
$^WARN_HOOK = 1;
END
}

sub t_qstring {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
'foo\'bar'
----
q|foo'bar|
====
'foo\\bar'
----
'foo\bar'
END
}

sub t_string_block {
    my $x = "abc";
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
"foo { ";
'foo { ';
----
"foo \{ ";
'foo { ';
====
<<"FOO";
{
FOO
----
<<"FOO";
\{
FOO
====
"\$ {"
----
"\$ \{"
====
<<"FOO";
$x {
FOO
----
<<"FOO";
$x \{
FOO
====
qq{ {} };
----
qq{ \{\} };
====
"\x{FF}";
"\\x{FF}";
"foo\{FF}";
----
"\x{FF}";
"\\x\{FF\}";
"foo\{FF\}";
====
s//ab{c/g;
s''de{f'g;
s/${a}{4}//g;
----
s//ab\{c/g;
s''de{f'g;
s/${a}{4}//g;
END
}

sub t_carp {
    my $x = "abc";
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
use Carp;
confess "foo";
----
use Carp;
die "foo";
====
END
}

sub t_no_sigil_change {
    my $x = "abc";
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
my @foo;
$#foo;
----
my @foo;
(@foo-1);
====
$#$foo
----
(@$foo-1)
====
my @foo;
$foo[1];
$foo[$a];
sub x { $_[1]++; }
----
my @foo;
@foo[1];
@foo[$a];
sub x { @_[1]++; }
====
my %foo;
$foo{1};
$foo{$a};
exists $foo{$a};
----
my %foo;
%foo{1};
%foo{$a};
exists %foo{$a};
====
@foo{@bar};
my %mfoo;
@mfoo{@bar};
----
%foo{[@bar]};
my %mfoo;
%mfoo{[@bar]};
====
@foo[1,2];
(1,2,3)[0..2];
----
@foo[[1,2]];
(1,2,3)[[0..2]];
====
"%"
----
"\%"
====
# TODO
split m/$foo::baz{bar}/, $a;
----
split m/%foo::baz{bar}/, $a;
====
END
}

sub t_no_bracket_names {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
${bar};
${^WARN_HOOK};
"${bar}";
"@{baz}";
<<"EOH"
${bar}
EOH
----
$bar;
$^WARN_HOOK;
"{$bar}";
"{@baz}";
<<"EOH"
{$bar}
EOH
====
END
}

sub t_anon_aryhsh {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
[ 1, 2 ];
{ foo => 'bar' };
----
\@( 1, 2 );
\%( foo => 'bar' );
====
(stat "foo")[2];
----
(stat "foo")[2];
====
END
}

sub t_eval_to_try {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
eval { 1 };
eval "1";
----
try { 1 };
eval "1";
====
END
}

sub t_no_auto_deref {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
$a->[0][0];
----
$a->[0]->[0];
====
our @a;
@a[0][1];
my $x;
@$x[0];
----
our @a;
@a[0]->[1];
my $x;
@$x[0];
====
$a->{foo}{bar};
----
$a->{foo}->{bar};
====
s/$a/%ENV{$a}/g;
delete $a->{foo}{bar};
----
s/$a/%ENV{$a}/g;
delete $a->{foo}->{bar};
====
# TODO no_auto_deref of sub.
$a->[0]();
----
# TODO no_auto_deref of sub.
$a->[0]->();
====
END
}

sub t_strict_vars {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
@foo;
use strict;
our @bar;
@bar;
----
our @foo;
our @bar;
@bar;
====
END
}

sub t_array_hash {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
sub foo { }
my @a = (1, 2);
my @b = foo();
----
sub foo { }
my @a = @(1, 2);
my @b = @( < foo() );
====
my @a;
for (@a) { }
for (@_) { }
my $n = shift;
print STDOUT @_;
----
my @a;
for (< @a) { }
for (< @_) { }
my $n = shift;
print STDOUT < @_;
====
my ($a, $b) = (1, 2);
my @a = (1, 2);
my %a = (1, 2);
----
my ($a, $b) = (1, 2);
my @a = @(1, 2);
my %a = %(1, 2);
====
my %h;
my $x = %h{'key'};
my @x = %h{['key']};
exists %h{'key'};
each %h;
values %h;
undef %h;
tied %h;
tie %h, "Foo", \%();
foo(@x[0]);
push @x, 2;
1 if %h;
@x[0] = @x[1];
delete @x[[0, 1]];
----
my %h;
my $x = %h{'key'};
my @x = @( %h{['key']} );
exists %h{'key'};
each %h;
values %h;
undef %h;
tied %h;
tie %h, "Foo", \%();
foo(@x[0]);
push @x, 2;
1 if %h;
@x[0] = @x[1];
delete @x[[0, 1]];
====
0 + @_;
@_ + 1;
0 + @(1,2);
0 + \@(1,2);
----
0 + nelems(@_);
nelems(@_) + 1;
0 + nelems(@(1,2));
0 + \@(1,2);
====
my $x = \@_;
----
my $x = \@_;
====
my ($x, @a) = @_;
----
my ($x, < @a) = < @_;
====
my (%h, %g);
%h = %g;
----
my (%h, %g);
%h = %( < %g );
====
our @a;
"@a @a";
----
our @a;
"{join ' ', <@a} {join ' ', <@a}";
====
sub foo(\@\%$) { }
my (@a, $s, %h);
foo(@a, %h, $s);
----
sub foo(\@\%$) { }
my (@a, $s, %h);
foo(@a, %h, $s);
====
{
    my %foo;
}
----
{
    my %foo;
}
====
chomp(@ARGV);
----
chomp(@ARGV);
====
my @numbers;
@numbers = sort { $a <+> $b } @numbers;
----
my @numbers;
@numbers = @( sort { $a <+> $b } < @numbers );
====
sub foo { my @a; return @a; }
sub bar { my $b; return $b; }
my @b = foo();
my ($x, $y) = foo();
print bar() + 10;
my ($u, $v) = (foo(), bar()); # "bar" is incorrectly assumed to be an array
----
sub foo { my @a; return @a; }
sub bar { my $b; return $b; }
my @b = @( < foo() );
my ($x, $y) = < foo();
print bar() + 10;
my ($u, $v) = ( <foo(), < bar()); # "bar" is incorrectly assumed to be an array
====
sub foo { return qw|a b c|; }
sub aap { my @a; @a; }
sub noot { return (1, 2); }
sub mies { return split m/x/, "foo"; }
sub wim { return 1, 2; }
sub zus { map { $_ } @_ }
sub jet { 1, 2 }
sub teun { return (1) }
sub vuur { return 1 }
sub gijs { grep { $_ } @_ }
my %h = (1, 2);
sub lam { keys %h }
----
sub foo { return @(qw|a b c|); }
sub aap { my @a; @a; }
sub noot { return ( @(1, 2 )); }
sub mies { return @( split m/x/, "foo" ); }
sub wim { return @( 1, 2 ); }
sub zus { @( map { $_ } < @_ ) }
sub jet { @( 1, 2 ) }
sub teun { return (1) }
sub vuur { return 1 }
sub gijs { @( grep { $_ } < @_ ) }
my %h = %(1, 2);
sub lam { @( keys %h ) }
====
sub foo { };
foo( aap => foo() );
foo( 'aap', foo() );
----
sub foo { };
foo( aap => foo() );
foo( 'aap', < foo() );
====
END
}

sub t_map_array {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
my @x = @( map { $_ + 1 } (1, 2, 3) );
----
my @x = @( < map { $_ + 1 } @( (1, 2, 3)) );
====
my @x = @( grep { $_ % 2 } (1, 2, 3) );
----
my @x = @( < grep { $_ % 2 } @( (1, 2, 3)) );
====
my @x = @( grep -r, qw|file1 file2|);
----
my @x = @( < grep -r, @( < qw|file1 file2|));
====
( grep -r, qw|file1 file2|) ? 1 : 0;
----
( grep -r, @( < qw|file1 file2|)) ? 1 : 0;
====
map { $_ + 1 } < foo();
----
map { $_ + 1 } @( < foo());
====
map { $_ } unpack "C*", "abc";
----
map { $_ } @( unpack "C*", "abc");
====
map { $_ + 1 } 1, 2, 3;
----
map { $_ + 1 } @( 1, 2, 3);
====
my @x = @( sort { $a <+> $b } (3, 1, 2) );
----
my @x = @( < sort { $a <+> $b } @( (3, 1, 2)) );
====
my @x = @( sort { $a[0] cmp $b[0] } 3, 1, 2 );
----
my @x = @( < sort { $a[0] cmp $b[0] } @( 3, 1, 2) );
====
my @x = @( sort (3, 1, 2) );
----
my @x = @( < sort ( @(3, 1, 2)) );
====
join '*', 1, 2;
----
join '*', @( 1, 2);
====
my ($a, $b) = split m/-/, 'a-b-c';
----
my ($a, $b) = < split m/-/, 'a-b-c';
====
my @x = @( reverse (3, 1, 2) );
----
my @x = @( < reverse ( @(3, 1, 2)) );
====
my @x = @( keys $a );
----
my @x = @( < keys $a );
====
my @x = @( values $a );
----
my @x = @( < values $a );
====
my @x = @(1..10);
----
my @x = @( <1..10);
====
my @x = @(qw|aap noot mies|);
----
my @x = @( <qw|aap noot mies|);
====
my @x;
for (< @x) { $_++; }
----
my @x;
for ( @x) { $_++; }
====
for (foo()) { $_++; }
----
for (@(foo())) { $_++; }
====
for ('aap', 'noot', 'mies') { $_++; }
----
for (@('aap', 'noot', 'mies')) { $_++; }
====
my %h;
foreach (keys %h) { $_++; }
----
my %h;
foreach (@( <keys %h)) { $_++; }
====
my %h;
$_++ foreach keys %h;
----
my %h;
$_++ foreach @( < keys %h);
====
for (1..10) { print $_; }
----
for (1..10) { print $_; }
====
my @a;
for my $i ( < @a ) { print $_; }
----
my @a;
for my $i (  @a ) { print $_; }
====
my (<$b) = $a->[[3,4,7]];
----
my (<$b) = < $a->[[@(3,4,7)]];
====
my (<$b) = $a->{[3,4,7]};
----
my (<$b) = < $a->{[@(3,4,7)]};
====
END
}

sub t_array_simplify {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
my $x = @( < $a );
----
my $x = $a;
END
}

sub t_ampcall {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
sub foo { }
&foo;
&foo();
foo;
----
sub foo { }
&foo( < @_ );
&foo();
foo;
END
}

sub t_block {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
{ 1; }
----
do { 1; };
====
map { $_ } 1..10;
while (1) { 1 };
sub { 1 };
{ 1 }
SKIP: { 1 }
----
map { $_ } 1..10;
while (1) { 1 };
sub { 1 };
do { 1 };
SKIP: do { 1 };
====
"{1}";
"" . join('*', map { $_ } 1..5);
"" . join('*', @{$_});
s/x/{ ord($1) }/;
"x {$a} - {$@->message} y";
----
"$(1)";
"" . join('*', map { $_ } 1..5);
"" . join('*', @{$_});
s/x/$( ord($1) )/;
"x $($a) - $($@->message) y";
====
my $x .= do { 3 };
----
my $x .= do { 3 };
END
}

sub t_lval_vec {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
vec($a, 1, 1) = 1;
----
vec($a, 1, 1, 1);
END
}

sub t_remove_strict {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
BEGIN { %INC{"strict.pm"} = 1 }
#before
use strict;
#after
----
BEGIN { %INC{"strict.pm"} = 1 }
#before
#after
====
BEGIN { %INC{"strict.pm"} = 1 }
#before
no strict 'refs';
#after
----
BEGIN { %INC{"strict.pm"} = 1 }
#before
#after
END
}

sub t_call_parens {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
sub foo { }
foo 1, 2;
foo(1, 2);
----
sub foo { }
foo( 1, 2);
foo(1, 2);
====
sub BAR() { 3 }
BAR;
----
sub BAR() { 3 }
BAR();
END
}

sub t_rename_ternary_op {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
$a ? 1 : 2;
----
$a ?? 1 !! 2;
END
}

sub t_hashkey_regulator {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
$a{ee} = 3;
$b = $a{ee};
$a{ff}->{gg} = 2;
----
$a{+ee} = 3;
$b = $a{?ee};
$a{ff}->{+gg} = 2;
====
sub foo { }
foo($a{ee});
----
sub foo { }
foo($a{?ee});
====
$a{ee} ||= 1;
$a{ff}++;
$a{gg}->foo();
----
$a{+ee} ||= 1;
$a{+ff}++;
$a{gg}->foo();
END
}

sub t_pattern_assignment {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
my ($x, $y) = (1, 2);
($x, $y) = (1, 2);
my ($u, $v) = < $x;
----
my @($x, $y) = @(1, 2);
@($x, $y) = @(1, 2);
my @($u, $v) =  $x;
====
< $a{[qw|aap noot|]} = < qw|Mies Wim|;
----
 $a{[qw|aap noot|]} =  qw|Mies Wim|;
====
my ($x, < @y) = (1, 2);
my ($u, < %h) = (1, 2);
----
my @($x, @< @y) = @(1, 2);
my @($u, %< %h) = @(1, 2);
====
my (@l) = $a->list();
----
my (@l) = $a->list();
====
my ($l) = "foo";
----
my ($l) = "foo";
====
my ($l) = m/(foo)/;
----
my @($l) = @(m/(foo)/);
END
}

sub t_env_using_package {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
%ENV{foo};
----
env::var('foo');
====
%ENV{foo} = 3;
----
env::set_var('foo') = 3;
====
local %ENV{foo} = 3;
----
 env::temp_set_var('foo') = 3;
====
"foo%ENV{bar}baz";
----
"foo$(env::var('bar'))baz";
END
}

sub t_remove_vars {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
package X;
#bar
use vars < qw($foo);
$foo;
----
package X;
#bar
our ($foo);
$foo;
====
use vars < qw($foo $bar);
----
our ($foo, $bar);
END
}

sub t_rename_magic_vars_2 {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
%^H;
----
$^HINTS;
====
%^H{'foo'} = 3;
----
$^HINTS{'foo'} = 3;
END
}

sub t_rename_magic_vars {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
$|
----
$^OUTPUT_AUTOFLUSH
====
$@->{?description};
----
$^EVALERROR->{?description};
END
}

sub t_rename_inc_vars {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
push @INC, '.';
----
push $^INCLUDE_PATH, '.';
====
%INC{"foo.pm"} = 1;
----
$^INCLUDED{"foo.pm"} = 1;
END
}

sub t_print {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
print "something";
printf "something";
print("something");
----
print \*STDOUT, "something";
printf \*STDOUT, "something";
print(\*STDOUT, "something");
====
print $a "something";
print {$a} "something";
print STDERR "something";
----
print $a, "something";
print $a ,"something";
print $^STDERR, "something";
END
}

sub t_block_arg {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
map { $_ } $a;
----
map { $_ }, $a;
====
sub foo(&$) { }
foo { $_ } $a;
----
sub foo(&$) { }
foo { $_ }, $a;
====
grep { $_ } $a;
----
grep { $_ }, $a;
====
$a = sort { $_ } $a;
----
$a = sort { $_ }, $a;
====
mysort( sub { $_ }, $a);
----
mysort( sub { $_ }, $a);
====
map { my $x = $_; $x } $a;
----
map { my $x = $_; $x }, $a;
====
sub foo(&$) { }
foo { my $x = $_; $x } $a;
----
sub foo(&$) { }
foo { my $x = $_; $x }, $a;
====
grep m/x/, $a;
----
grep { m/x/ }, $a;
====
END
}

sub t_must_haveargs {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
&{$a};
&{$a}();
----
&{$a}( < @_ );
&{$a}();
====
\&{$a};
----
\&{$a};
====
sub foo { }
&foo;
----
sub foo { }
&foo;
END
}

sub t_prototype {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
sub foo {
    my @($x, $y) = @_;
    return 3;
}
sub bar {
    3;
    my @($z) = @_;
    return 3;
}
----
sub foo($x, $y) {
    return 3;
}
sub bar($z) {
    3;

    return 3;
}
END
}

sub t_stdin {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
my $x = ~< *STDIN;
my $y = ~< \*STDIN;
----
my $x = ~< $^STDIN;
my $y = ~< $^STDIN;
END
}

sub t_local {
    p5convert( split(m/^\-{4}.*\n/m, $_, 2)) for split(m/^={4}\n/m, <<'END');
local $a;
local $a = 3;
1;
----
local $a = undef;
local $a = 3;
1;
====
local $^INPUT_RECORD_SEPARATOR;
local $^INPUT_RECORD_SEPARATOR = 3;
2;
----
local $^INPUT_RECORD_SEPARATOR = undef;
local $^INPUT_RECORD_SEPARATOR = 3;
2;
END
}
