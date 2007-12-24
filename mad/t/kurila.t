#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    push @INC, "../mad";
}

use IO::Handle;

use Test::More qw|no_plan|;

use Fatal qw|open close|;

use Convert;

my $from = 1.5;

sub p5convert {
    my ($input, $expected) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    local $TODO = $TODO || ($input =~ m/^[#]\s*TODO/);
    my $output = Convert::convert($input, "/usr/bin/env perl ../mad/p5kurila.pl",
                                  dumpcommand => "$ENV{madpath}/perl");
    is($output, $expected) or $TODO or die;
}

#t_parenthesis();
#t_change_deref();
#t_anon_hash();
t_string_block();
die;
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

sub t_string_block {
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
END
}
