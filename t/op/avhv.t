#!./perl

# This test was originally for pseudo-hashes.  It now exists to ensure
# they were properly removed in 5.9.

require Tie::Array;

package Tie::BasicArray;
our @ISA = 'Tie::Array';
sub TIEARRAY  { bless \@(), @_[0] }
sub STORE     { @_[0]->[@_[1]] = @_[2] }
sub FETCH     { @_[0]->[@_[1]] }
sub FETCHSIZE { scalar(@{@_[0]})} 
sub STORESIZE { (@{@_[0]} = @_[1]+2)-1 }

package main;

require './test.pl';
plan(tests => 40);

# Helper function to check the typical error message.
sub not_hash {
    my($err) = shift;
    like( $err->{description}, qr/^Not a HASH reference/ ) ||
      printf STDERR "# at \%s line \%d.\n", (caller)[[1,2]];
}

# Something to place inside if blocks and while loops that won't get
# compiled out.
my $foo = 42;
sub no_op { $foo++ }

our ($sch, @keys, @values, @fake, %fake, $v, @x, %hv);

$sch = \%(
    'abc' => 1,
    'def' => 2,
    'jkl' => 3,
);

# basic normal array
$a = \@();
$a->[0] = $sch;

try {
    $a->{'abc'} = 'ABC';
};
not_hash($@);

try {
    $a->{'def'} = 'DEF';
};
not_hash($@);

try {
    $a->{'jkl'} = 'JKL';
};
not_hash($@);

try {
    @keys = keys %$a;
};
not_hash($@);

try {
    @values = values %$a;
};
not_hash($@);

try {
    while( my($k,$v) = each %$a ) {
        no_op;
    }
};
not_hash($@);


# quick check with tied array
tie @fake, 'Tie::StdArray';
$a = \@fake;
$a->[0] = $sch;

try {
    $a->{'abc'} = 'ABC';
};
not_hash($@);

try {
    if ($a->{'abc'} eq 'ABC') { no_op(23) } else { no_op(42) }
};
not_hash($@);

# quick check with tied array
tie @fake, 'Tie::BasicArray';
$a = \@fake;
$a->[0] = $sch;

try {
    $a->{'abc'} = 'ABC';
};
not_hash($@);

try {
    if ($a->{'abc'} eq 'ABC') { no_op(23) } else { no_op(42) }
};
not_hash($@);

# quick check with tied array & tied hash
require Tie::Hash;
tie %fake, 'Tie::StdHash';
%fake = %$sch;
$a->[0] = \%fake;

try {
    $a->{'abc'} = 'ABC';
};
not_hash($@);

try {
    if ($a->{'abc'} eq 'ABC') { no_op(23) } else { no_op(42) }
};
not_hash($@);


# hash slice
try {
    my $slice = join('', 'x',%$a{['abc','def']},'x');
};
not_hash($@);


# evaluation in scalar context
my $avhv = \@(\%());

try {
    () = %$avhv;
};
not_hash($@);

push @$avhv, "a";
try {
    () = %$avhv;
};
not_hash($@);

$avhv = \@();
try { $a = %$avhv };
not_hash($@);

$avhv = \@(\%(foo=>1, bar=>2));
try {
    %$avhv =~ m,^\d+/\d+,;
};
not_hash($@);

# check if defelem magic works
sub f {
    print "not " unless @_[0] eq 'a';
    @_[0] = 'b';
    print "ok 11\n";
}
$a = \@(\%(key => 1), 'a');
try {
    f($a->{key});
};
not_hash($@);

# check if exists() is behaving properly
$avhv = \@(\%(foo=>1,bar=>2,pants=>3));
try {
    no_op if exists $avhv->{bar};
};
not_hash($@);

try {
    $avhv->{pants} = undef;
};
not_hash($@);

try {
    no_op if exists $avhv->{pants};
};
not_hash($@);

try {
    no_op if exists $avhv->{bar};
};
not_hash($@);

try {
    $avhv->{bar} = 10;
};
not_hash($@);

try {
    no_op unless exists $avhv->{bar} and $avhv->{bar} == 10;
};
not_hash($@);

try {
    $v = delete $avhv->{bar};
};
not_hash($@);

try {
    no_op if exists $avhv->{bar};
};
not_hash($@);

try {
    $avhv->{foo} = 'xxx';
};
not_hash($@);
try {
    $avhv->{bar} = 'yyy';
};
not_hash($@);
try {
    $avhv->{pants} = 'zzz';
};
not_hash($@);
try {
    @x = delete %{$avhv}{['foo','pants']};
};
not_hash($@);
try {
    no_op unless "$avhv->{bar}" eq "yyy";
};
not_hash($@);

# hash assignment
try {
    %$avhv = ();
};
not_hash($@);

try {
    %hv = %$avhv;
};
not_hash($@);

try {
    %$avhv = (foo => 29, pants => 2, bar => 0);
};
not_hash($@);

my $extra;
my @extra;
try {
    ($extra, %$avhv) = ("moo", foo => 42, pants => 53, bar => "HIKE!");
};
not_hash($@);

try {
    %$avhv = ();
    (%$avhv, $extra) = (foo => 42, pants => 53, bar => "HIKE!");
};
not_hash($@);

try {
    @extra = qw(whatever and stuff);
    %$avhv = ();
};
not_hash($@);
try {
    (%$avhv, @extra) = (foo => 42, pants => 53, bar => "HIKE!");
};
not_hash($@);

try {
    (@extra, %$avhv) = (foo => 42, pants => 53, bar => "HIKE!");
};
not_hash($@);

# Check hash slices (BUG ID 20010423.002)
$avhv = \@(\%(foo=>1, bar=>2));
try {
    %$avhv{["foo", "bar"]} = (42, 53);
};
not_hash($@);
