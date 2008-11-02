#!./perl

use Test;
BEGIN { plan tests => 8; }

BEGIN {
    require autouse;
    try {
        "autouse"->import('List::Util' => 'List::Util::first(&@)');
    };
    ok( !$@ );

    try {
        "autouse"->import('List::Util' => 'Foo::min');
    };
    ok( $@->{description}, qr/^autouse into different package attempted/ );

    "autouse"->import('List::Util' => qw(max first(&@)));
}

my @a = @(1,2,3,4,5.5);
ok( max(<@a), 5.5);


# first() has a prototype of &@.  Make sure that's preserved.
ok( (first { $_ +> 3 } <@a), 4);


# Test that autouse's lazy module loading works.
use autouse 'Errno' => qw(EPERM);

my $mod_file = 'Errno.pm';   # just fine and portable for %INC
ok( !exists %INC{$mod_file} );
ok( EPERM ); # test if non-zero
ok( exists %INC{$mod_file} );

# Check that UNIVERSAL.pm doesn't interfere with modules that don't use
# Exporter and have no import() of their own.
require UNIVERSAL;
autouse->import("Class::ISA" => 'self_and_super_versions');
my %versions = %( < self_and_super_versions("Class::ISA") );
ok( %versions{"Class::ISA"}, $Class::ISA::VERSION );
