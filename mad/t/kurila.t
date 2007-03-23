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
    my ($input, $expected, $convert) = @_;
    my $output = Convert::convert($input, $convert && "/usr/bin/perl ../mad/p5kurila.pl");
    is($output, $expected);
}

t_indirect_object_syntax();
t_barewords();

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
}
=======
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
}
