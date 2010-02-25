#!perl

use Config

use Test::More
use Safe
plan: tests => 4

my $c = Safe->new: 
$c->permit:  <qw(require caller)

my $r = $c->reval: q!
    sub UNIVERSAL::isa { "pwned" }
    (bless: \$@,"Foo")->isa: "Foo";
!

is:  $r, "pwned", "isa overriden in compartment" 
is:  ((bless: \$@,"Foo")->isa: "Foo"), 1, "... but not outside" 

sub Foo::foo {}

$r = $c->reval: q!
    sub UNIVERSAL::can { "pwned" }
    (bless: \$@,"Foo")->can: "foo";
!

is:  $r, "pwned", "can overriden in compartment" 
is:  ((bless: \$@,"Foo")->can: "foo"), \&Foo::foo, "... but not outside" 

