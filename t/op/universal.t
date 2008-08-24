#!./perl
#
# check UNIVERSAL
#

BEGIN {
    $| = 1;
    require "./test.pl";
}

plan tests => 101;

$a = \%();
bless $a, "Bob";
ok $a->isa("Bob");

package Human;
sub eat {}

package Female;
our @ISA= @(qw(Human) );

package Alice;
our @ISA= @(qw(Bob Female) );
sub drink { return "drinking " . @_[1]  }
sub new { bless \%() }

$Alice::VERSION = 2.718;

{
    package Cedric;
    our @ISA;
    use base qw(Human);
}

{
    package Programmer;
    our $VERSION = 1.667;

    sub write_perl { 1 }
}

package main;



$a = Alice->new();

ok $a->isa("Alice");

ok $a->isa("Bob");

ok $a->isa("Female");

ok $a->isa("Human");

ok ! $a->isa("Male");

ok ! $a->isa('Programmer');

ok $a->isa("HASH");

ok $a->can("eat");
ok ! $a->can("sleep");
ok my $ref = $a->can("drink");        # returns a coderef
is $a->?$ref("tea"), "drinking tea"; # ... which works

ok (!Cedric->isa('Programmer'));

ok (Cedric->isa('Human'));

push(@Cedric::ISA,'Programmer');

ok (Cedric->isa('Programmer'));

{
    package Alice;
    'base'->import('Programmer');
}

ok $a->isa('Programmer');
ok $a->isa("Female");

@Cedric::ISA = @( qw(Bob) );

ok (!Cedric->isa('Programmer'));

my $b = 'abc';
my @refs = @( qw(SCALAR SCALAR     LVALUE      GLOB ARRAY HASH CODE) );
my @vals = @(  \$b,   \3.14, \vec($b,1,1), \*b,  \@(),  \%(), sub {} );
for (my $p=0; $p +< nelems @refs; $p++) {
    for (my $q=0; $q +< nelems @vals; $q++) {
        is UNIVERSAL::isa(@vals[$p], @refs[$q]), ($p==$q or $p+$q==1);
    };
};

ok ! UNIVERSAL::can(23, "can");

ok $a->can("VERSION");

ok $a->can("can");
ok ! $a->can("export_tags");	# a method in Exporter

cmp_ok try { $a->VERSION }, '==', 2.718;

dies_like( sub { $a->VERSION(2.719) }, 
           qr/^Alice version 2.719 required--this is only version 2.718/ );

ok (try { $a->VERSION(2.718) });
is $@, '';

my $subs = join ' ', sort < grep { defined &{Symbol::fetch_glob("UNIVERSAL::$_")} } @( keys %UNIVERSAL::);
## The test for import here is *not* because we want to ensure that UNIVERSAL
## can always import; it is an historical accident that UNIVERSAL can import.
is $subs, "DOES VERSION can import isa";

ok $a->isa("UNIVERSAL");

ok ! UNIVERSAL::isa(\@(), "UNIVERSAL");

ok ! UNIVERSAL::can(\%(), "can");

ok UNIVERSAL::isa(Alice => "UNIVERSAL");

cmp_ok UNIVERSAL::can(Alice => "can"), '\==', \&UNIVERSAL::can;

# now use UNIVERSAL.pm and see what changes
eval "use UNIVERSAL";

ok $a->isa("UNIVERSAL");

my $sub2 = join ' ', sort < grep { defined &{Symbol::fetch_glob("UNIVERSAL::$_")} } @( keys %UNIVERSAL::);
# XXX import being here is really a bug
is $sub2, "DOES VERSION can import isa";

eval 'sub UNIVERSAL::sleep {}';
ok $a->can("sleep");

ok ! UNIVERSAL::can($b, "can");

ok ! $a->can("export_tags");	# a method in Exporter

ok ! UNIVERSAL::isa("\x[ffffff]\0", 'HASH');

{
    package Pickup;
    use UNIVERSAL qw( isa can VERSION );

    main::ok isa "Pickup", 'UNIVERSAL';
    main::cmp_ok can( "Pickup", "can" ), '\==', \&UNIVERSAL::can;
    main::ok VERSION "UNIVERSAL" ;
}

# bugid 3284
# a second call to isa('UNIVERSAL') when @ISA is null failed due to caching

@X::ISA= @(() );
my $x = \%(); bless $x, 'X';
ok $x->isa('UNIVERSAL');
ok $x->isa('UNIVERSAL');


# Check that the "historical accident" of UNIVERSAL having an import()
# method doesn't effect anyone else.
try { 'Some::Package'->import("bar") };
is $@, '';


# This segfaulted in a blead.
fresh_perl_is('package Foo; Foo->VERSION;  print "ok"', 'ok');

package Foo;

sub DOES { 1 }

package Bar;

@Bar::ISA = @( 'Foo' );

package Baz;

package main;
ok( Foo->DOES( 'bar' ), 'DOES() should call DOES() on class' );
ok( Bar->DOES( 'Bar' ), '... and should fall back to isa()' );
ok( Bar->DOES( 'Foo' ), '... even when inherited' );
ok( Baz->DOES( 'Baz' ), '... even without inheriting any other DOES()' );
ok( ! Baz->DOES( 'Foo' ), '... returning true or false appropriately' );

package Pig;
package Bodine;
Bodine->isa('Pig');
*isa = \&UNIVERSAL::isa;
try { isa(\%(), 'HASH') };
main::is($@, '', "*isa correctly found");

package main;
main::dies_like( sub { UNIVERSAL::DOES(\@(), "foo") },
             qr/Can't call method "DOES" on unblessed reference/,
             'DOES call error message says DOES, not isa' );
