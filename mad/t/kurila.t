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


sub p5convert {
    my ($input, $expected) = @_;
    local $TODO = $TODO || ($input =~ m/^[#]\s*TODO/);
    my $output = Convert::convert($input, "/usr/bin/env perl ../mad/p5kurila.pl",
                                  dumpcommand => "$ENV{madpath}/perl");
    is($output, $expected) or $TODO or die;
}

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
@$string= sub { 1 };
---
# not if 'use strict'
use strict;
my $string = "s";
@$string= sub { 1 };
===
# variable is a hard ref
my $ref = "s";
$ref = [];
@$ref= sub { 1 };
---
# variable is a hard ref
my $ref = "s";
$ref = [];
@$ref= sub { 1 };
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
require v5.6;
----------
require v5.6;
==========
use version v0.2;
----------
use version v0.2;
==========
"foo$\value"
----------
"foo$\value"
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
