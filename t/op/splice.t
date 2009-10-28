#!./perl

BEGIN
    require "./test.pl"

plan: tests => 20

our @a =1..10

sub j { (join: ":", @_) }

ok:  (j: (splice: @a,nelems @a,0,11,12)) eq "" && (j: < @a) eq (j:  <1..12) 

ok:  (j: (splice: @a,-1)) eq "12" && (j: < @a) eq (j:  <1..11) 

ok:  (j: (splice: @a,0,1)) eq "1" && (j: < @a) eq (j:  <2..11) 

ok:  (j: (splice: @a,0,0,0,1)) eq "" && (j: < @a) eq (j:  <0..11) 

ok:  (j: (splice: @a,5,1,5)) eq "5" && (j: < @a) eq (j:  <0..11) 

ok:  (j: (splice: @a, nelems @a, 0, 12, 13)) eq "" && (j: < @a) eq (j:  <0..13) 

ok:  (j: (splice: @a, -nelems @a, nelems @a, 1, 2, 3)) eq (j:  <0..13) && (j: < @a) eq (j:  <1..3) 

ok:  (j: (splice: @a, 1, -1, 7, 7)) eq "2" && (j: < @a) eq (j: 1,7,7,3) 

ok:  (j: (splice: @a,-3,-2,2)) eq (j: 7) && (j: < @a) eq (j: 1,2,7,3) 

# Bug 20000223.001 - no test for splice(@array).  Destructive test!
ok:  (j: (splice: @a)) eq (j: 1,2,7,3) && (j: < @a) eq '' 

# Tests 11 and 12:
# [ID 20010711.005] in Tie::Array, SPLICE ignores context, breaking SHIFT

my $foo

@a = @: 'red', 'green', 'blue'
$foo = splice: @a, 1, 2
ok:  $foo eq 'blue' 

@a = @: 'red', 'green', 'blue'
$foo = shift @a
ok:  $foo eq 'red' 

# Bug [perl #30568] - insertions of deleted elements
@a = @: 1, 2, 3
splice:  @a, 0, 3, @a[1], @a[0] 
ok:  (j: < @a) eq (j: 2,1) 

@a = @: 1, 2, 3
splice:  @a, 0, 3 ,@a[0], @a[1] 
ok:  (j: < @a) eq (j: 1,2) 

@a = @: 1, 2, 3
splice:  @a, 0, 3 ,@a[2], @a[1], @a[0] 
ok:  (j: < @a) eq (j: 3,2,1) 

@a = @: 1, 2, 3
splice:  @a, 0, 3, @a[0], @a[1], @a[2], @a[0], @a[1], @a[2] 
ok:  (j: < @a) eq (j: 1,2,3,1,2,3) 

@a = @: 1, 2, 3
splice:  @a, 1, 2, @a[2], @a[1] 
ok:  (j: < @a) eq (j: 1,3,2) 

@a = @: 1, 2, 3
splice:  @a, 1, 2, @a[1], @a[1] 
ok:  (j: < @a) eq (j: 1,2,2) 

my $x = "aap"
dies_like:  { (splice: $x, 1, 2) }
            qr/Type of arg 1 to splice must be array/ 

dies_like:  { (splice: undef, 1, 2) }
            qr/Type of arg 1 to splice must be array/ 
