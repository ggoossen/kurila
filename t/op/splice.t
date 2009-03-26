#!./perl

print $^STDOUT, "1..18\n";

our @a =1..10;

sub j { join(":", @_) }

print $^STDOUT, "not " unless j(splice(@a,nelems @a,0,11,12)) eq "" && j(< @a) eq j( <1..12);
print $^STDOUT, "ok 1\n";

print $^STDOUT, "not " unless j(splice(@a,-1)) eq "12" && j(< @a) eq j( <1..11);
print $^STDOUT, "ok 2\n";

print $^STDOUT, "not " unless j(splice(@a,0,1)) eq "1" && j(< @a) eq j( <2..11);
print $^STDOUT, "ok 3\n";

print $^STDOUT, "not " unless j(splice(@a,0,0,0,1)) eq "" && j(< @a) eq j( <0..11);
print $^STDOUT, "ok 4\n";

print $^STDOUT, "not " unless j(splice(@a,5,1,5)) eq "5" && j(< @a) eq j( <0..11);
print $^STDOUT, "ok 5\n";

print $^STDOUT, "not " unless j(splice(@a, nelems @a, 0, 12, 13)) eq "" && j(< @a) eq j( <0..13);
print $^STDOUT, "ok 6\n";

print $^STDOUT, "not " unless j(splice(@a, -nelems @a, nelems @a, 1, 2, 3)) eq j( <0..13) && j(< @a) eq j( <1..3);
print $^STDOUT, "ok 7\n";

print $^STDOUT, "not " unless j(splice(@a, 1, -1, 7, 7)) eq "2" && j(< @a) eq j(1,7,7,3);
print $^STDOUT, "ok 8\n";

print $^STDOUT, "not " unless j(splice(@a,-3,-2,2)) eq j(7) && j(< @a) eq j(1,2,7,3);
print $^STDOUT, "ok 9\n";

# Bug 20000223.001 - no test for splice(@array).  Destructive test!
print $^STDOUT, "not " unless j(splice(@a)) eq j(1,2,7,3) && j(< @a) eq '';
print $^STDOUT, "ok 10\n";

# Tests 11 and 12:
# [ID 20010711.005] in Tie::Array, SPLICE ignores context, breaking SHIFT

my $foo;

@a = @('red', 'green', 'blue');
$foo = splice @a, 1, 2;
print $^STDOUT, "not " unless $foo eq 'blue';
print $^STDOUT, "ok 11\n";

@a = @('red', 'green', 'blue');
$foo = shift @a;
print $^STDOUT, "not " unless $foo eq 'red';
print $^STDOUT, "ok 12\n";

# Bug [perl #30568] - insertions of deleted elements
@a = @(1, 2, 3);
splice( @a, 0, 3, @a[1], @a[0] );
print $^STDOUT, "not " unless j(< @a) eq j(2,1);
print $^STDOUT, "ok 13\n";

@a = @(1, 2, 3);
splice( @a, 0, 3 ,@a[0], @a[1] );
print $^STDOUT, "not " unless j(< @a) eq j(1,2);
print $^STDOUT, "ok 14\n";

@a = @(1, 2, 3);
splice( @a, 0, 3 ,@a[2], @a[1], @a[0] );
print $^STDOUT, "not " unless j(< @a) eq j(3,2,1);
print $^STDOUT, "ok 15\n";

@a = @(1, 2, 3);
splice( @a, 0, 3, @a[0], @a[1], @a[2], @a[0], @a[1], @a[2] );
print $^STDOUT, "not " unless j(< @a) eq j(1,2,3,1,2,3);
print $^STDOUT, "ok 16\n";

@a = @(1, 2, 3);
splice( @a, 1, 2, @a[2], @a[1] );
print $^STDOUT, "not " unless j(< @a) eq j(1,3,2);
print $^STDOUT, "ok 17\n";

@a = @(1, 2, 3);
splice( @a, 1, 2, @a[1], @a[1] );
print $^STDOUT, "not " unless j(< @a) eq j(1,2,2);
print $^STDOUT, "ok 18\n";
