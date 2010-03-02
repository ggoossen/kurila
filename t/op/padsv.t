#! ./perl

BEGIN { require "./test.pl" }

plan: tests => 4

do
    # OPf_ASSIGN
    my $x
    $x = 3
    is:  $x, 3, "basic sv stuff"


do
    # OPf_ASSIGN_PART
    my $x
    (@: $x) = qw|aap|
    is:  $x, "aap" 


do
    # OPf_OPTIONAL
    my $x = "aap"
    (@:  ? $x ) = $@
    is:  $x, undef 


do
    # check initialization to new value
    my @refs
    for (1..2)
        my (@: $x) = qw|aap|
        push: @refs, \$x
    
    isnt:  @refs[0], @refs[1] 

