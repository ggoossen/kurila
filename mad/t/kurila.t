#!/usr/bin/perl

use strict;
use warnings;

use IO::Handle;

use Test::More qw|no_plan|;

use Fatal qw|open close|;

use lib "$ENV{madpath}/mad";
use MAD;


sub p5convert {
    my ($input, $expected, $convert) = @_;
    my $output = MAD::convert($input, $convert && "/usr/bin/perl $ENV{madpath}/mad/p5kurila.pl");
    is($output, $expected);
}

sub p55 {
    my $input = shift;
    my $output = MAD::convert($input);
    is($output, $input);
}

p55( <<'END' );
use strict;
#ABC
new Foo;
Foo->new;
END

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

p5convert( split(m/^====\n/m, <<'END'), 1 );
bless {}, CLASS;
====
bless {}, 'CLASS';
END

