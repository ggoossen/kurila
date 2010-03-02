#!./perl -w

BEGIN
    unshift: $^INCLUDE_PATH, '../../t/lib'


use warnings
use Test::More tests => 3 * 3
use B 'svref_2object'

# use Data::Dumper 'Dumper';

sub foo
    my ( $x, $y, $z )

    # hh => {},
    $z = $x * $y

    # hh => { mypragma => 42 }
    use mypragma;
    $z = $x + $y

    # hh => { mypragma => 0 }
    no mypragma;
    $z = $x - $y


do

    # Pragmas don't appear til they're used.
    my $cop = find_op_cop:  \&foo, qr/multiply/ 
    isa_ok:  $cop, 'B::COP', 'found pp_multiply opnode' 

    my $hints_hash = $cop->hints_hash
    is:  (ref: $hints_hash), 'HASH', 'Got hash reference' 

    ok:  (not:  exists $hints_hash->{mypragma} ), q[! exists mypragma] 


do

    # Pragmas can be fetched.
    my $cop = find_op_cop:  \&foo, qr/add/ 
    isa_ok:  $cop, 'B::COP', 'found pp_add opnode' 

    my $hints_hash = $cop->hints_hash
    is:  (ref: $hints_hash), 'HASH', 'Got hash reference' 

    is:  $hints_hash->{?mypragma}, 42, q[mypragma => 42] 


do

    # Pragmas can be changed.
    my $cop = find_op_cop:  \&foo, qr/subtract/ 
    isa_ok:  $cop, 'B::COP', 'found pp_subtract opnode' 

    my $hints_hash = $cop->hints_hash
    is:  (ref: $hints_hash), 'HASH', 'Got hash reference' 

    is:  $hints_hash->{?mypragma}, 0, q[mypragma => 0] 

exit

our $COP

sub find_op_cop( $sub, $op)
    my $cv = svref_2object: $sub
    local $COP = undef

    if ( not (_find_op_cop:  $cv->ROOT, $op ) )
        $COP = undef
    

    return $COP


sub _find_op_cop( $op, $name)

    # Fail on B::NULL or whatever.
    return 0 if not $op or $op->isa: "B::NULL"

    # Succeed when we find our match.
    return 1 if $op->name =~ $name

    # Stash the latest seen COP opnode. This has our hints hash.
    if ( ($op->isa: 'B::COP') )

        # print Dumper(
        #     {   cop   => $op,
        #         hints => $op->hints_hash->HASH
        #     }
        # );
        $COP = $op
    

    # Recurse depth first passing success up if it happens.
    if ( ($op->can: 'first') )
        return 1 if _find_op_cop:  $op->first, $name 
    
    return 1 if _find_op_cop:  $op->sibling, $name 

    # Oh well. Hopefully our caller knows where to try next.
    return 0


