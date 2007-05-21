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
    my $output = Convert::convert($input, "/usr/bin/perl ../mad/p5kurila.pl");
    is($output, $expected) or $TODO or die;
}

# t_strict_refs();
t_indirect_object_syntax();
t_barewords();
# t_encoding();

sub t_indirect_object_syntax {
    p5convert( split(m/^====\n/m, <<'END'), 1 );
use strict;
#ABC
new Foo;
#DEF
Foo->new;
====
use strict;
#ABC
Foo->new();
#DEF
Foo->new;
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
use Test::More tests => 1;
====
use Test::More tests => 1;
END

}


sub t_barewords {

    p5convert( split(m/^====\n/m, <<'END'), 1 );
bless {}, CLASS;
====
bless {}, 'CLASS';
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
require overload;
====
require overload;
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
foo => 'bar';
====
foo => 'bar';
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
{ foo => 'bar', noot => "mies" };
====
{ foo => 'bar', noot => "mies" };
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
$aap{noot};
====
$aap{noot};
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
exists $aap->{noot};
====
exists $aap->{noot};
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
Foo->new(-Level);
====
Foo->new(-Level);
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
$foo->SUPER::aap();
====
$foo->SUPER::aap();
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
sort Foo::aap 1,2,3;
====
sort Foo::aap 1,2,3;
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
sort aap 1,2,3;
====
sort aap 1,2,3;
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
open(IN, "aap");
====
open(IN, "aap");
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
-d _;
====
-d _;
END

    p5convert( split(m/^====\n/m, <<'END'), 1 );
Foo::Bar->new();
====
Foo::Bar->new();
END
}

sub t_strict_refs {
    p5convert( 'print {Symbol::qualify_to_ref("STDOUT")} "foo"',
               'print {Symbol::qualify_to_ref("STDOUT")} "foo"' );
    p5convert( 'print {"STDOUT"} "foo"',
               'print {Symbol::qualify_to_ref("STDOUT")} "foo"' );
    p5convert( 'my $pkg; *{$pkg . "::bar"} = sub { "foo" }',
               'my $pkg; *{Symbol::qualify_to_ref($pkg . "::bar")} = sub { "foo" }');
    p5convert( 'my $pkg; *{"$pkg\::bar"} = sub { "foo" }',
               'my $pkg; *{Symbol::qualify_to_ref("$pkg\::bar")} = sub { "foo" }');
    p5convert( 'my $pkg; ${$pkg . "::bar"} = "noot"',
               'my $pkg; ${Symbol::qualify_to_ref($pkg . "::bar")} = "noot"');
    p5convert( 'my $pkg; @{$pkg . "::bar"} = ("noot", "mies")',
               'my $pkg; @{Symbol::qualify_to_ref($pkg . "::bar")} = ("noot", "mies")');
    p5convert( 'my $pkg; %{$pkg . "::bar"} = { aap => "noot" }',
               'my $pkg; %{Symbol::qualify_to_ref($pkg . "::bar")} = { aap => "noot" }');
    p5convert( 'my $pkg; &{$pkg . "::bar"} = sub { "foobar" }',
               'my $pkg; &{Symbol::qualify_to_ref($pkg . "::bar")} = sub { "foobar" }');
    p5convert( 'my $pkg; defined &{$pkg . "::bar"}',
               'my $pkg; defined &{Symbol::qualify_to_ref($pkg . "::bar")}');

    p5convert( 'my $pkg; keys %Package::',
               'my $pkg; keys %{Symbol::stash("Package")}');
    p5convert( 'my $pkg; keys $Package::{"var"}',
               'my $pkg; keys ${Symbol::stash("Package")}{"var"}');
}

sub t_encoding {
    p5convert( qq|use encoding 'latin1';\n"\x85"|, qq|use encoding 'latin1';\n"\x85"|, 1 );
    p5convert( qq|"\x85"|, qq|use encoding 'latin1';\n"\x85"|, 1 );
}
