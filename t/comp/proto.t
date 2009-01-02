#!./perl
#
# Contributed by Graham Barr <Graham.Barr@tiuk.ti.com>
#
# So far there are tests for the following prototypes.
# none, () ($) ($@) ($%) ($;$) (&) (&\@) (&@) (%) (\%) (\@)
#
# It is impossible to test every prototype that can be specified, but
# we should test as many as we can.
#



BEGIN { require "./test.pl" }

plan tests => 60;

sub testing (&$) {
    my $p = prototype(shift);
    my $c = shift;
    my $what = defined $c ?? '(' . $p . ')' !! 'no prototype';   
    print '#' x 25,"\n";
    print '# Testing ',$what,"\n";
    print '#' x 25,"\n";
    ok ( not ((defined($p) && defined($c) && $p ne $c)
                || (defined($p) != defined($c))) );
}

@_ = qw(a b c d);
my @array;
my %hash;

##
##
##

testing \&no_proto, undef;

sub no_proto {
    print "# \@_ = (",join(",", @_),")\n";
    scalar(nelems @_)
}

ok( 0 == no_proto() );

ok( 1 == no_proto(5) );

ok( 4 == &no_proto( < @_ ) );

ok( 1 == no_proto 6 );

ok( 4 == no_proto(< @_) );

##
##
##


testing \&no_args, '';

sub no_args () {
    print "# \@_ = (",join(",", @_),")\n";
    scalar(nelems @_)
}

ok( 0 == no_args() );

ok( 0 == no_args );

ok( 5 == no_args +5 );

ok( 4 == &no_args( < @_ ) );

ok( 2 == &no_args(1,2) );

eval "no_args(1)";
ok( $^EVAL_ERROR );

##
##
##

testing \&one_args, '$';

sub one_args ($) {
    print "# \@_ = (",join(",", @_),")\n";
    scalar(nelems @_)
}

ok( 1 == one_args(1) );

ok( 1 == one_args 5 );

ok( 4 == &one_args( < @_ ) );

ok( 2 == &one_args(1,2) );

eval "one_args(1,2)";
ok( $^EVAL_ERROR );

eval "one_args()";
ok( $^EVAL_ERROR );

sub one_a_args ($) {
    print "# \@_ = (",join(",", @_),")\n";
    ok( (nelems @_) == 1 && @_[0] == 4 );
}

one_a_args((nelems @_));

##
##
##

testing \&over_one_args, '$@';

sub over_one_args ($@) {
    print "# \@_ = (",join(",", @_),")\n";
    scalar(nelems @_)
}

ok( 1 == over_one_args(1) );
ok( 2 == over_one_args(1,2) );
ok( 1 == over_one_args 5 );
ok( 4 == &over_one_args( < @_ ) );
ok( 2 == &over_one_args(1,2) );
ok( 5 == &over_one_args(1,< @_) );

eval "over_one_args()";
ok( $^EVAL_ERROR );

sub over_one_a_args ($@) {
    print "# \@_ = (",join(",", @_),")\n";
    ok(  (nelems @_) +>= 1 && @_[0] == 4 );
}

over_one_a_args((nelems @_));
over_one_a_args((nelems @_),1);
over_one_a_args((nelems @_),1,2);
over_one_a_args((nelems @_),< @_);

##
##
##

testing \&one_or_two, '$;$';

sub one_or_two ($;$) {
    print "# \@_ = (",join(",", @_),")\n";
    scalar(nelems @_)
}

ok( 1 == one_or_two(1) );
ok( 2 == one_or_two(1,3) );
ok( 1 == one_or_two 5 );
ok( 4 == &one_or_two( < @_ ) );
ok( 3 == &one_or_two(1,2,3) );
ok( 5 == &one_or_two(1,< @_) );

eval "one_or_two()";
ok( $^EVAL_ERROR );

eval "one_or_two(1,2,3)";
ok( $^EVAL_ERROR );

sub one_or_two_a ($;$) {
    print "# \@_ = (",join(",", @_),")\n";
    ok( (nelems @_) +>= 1 && @_[0] == 4 );
}

one_or_two_a((nelems @_));
one_or_two_a((nelems @_),1);
one_or_two_a((nelems @_),nelems @_);

##
##
##

testing \&a_sub, '&';

sub a_sub (&) {
    print "# \@_ = (",join(",", map {dump::view($_)} @_),")\n";
    &{@_[0]}( < @_ );
}

sub tmp_sub_1 { ok(1) }

a_sub { ok(1) };
a_sub \&tmp_sub_1;

@array = @( \&tmp_sub_1 );
eval 'a_sub @array';
ok( $^EVAL_ERROR );

##
##
##

testing \&sub_aref, '&\@';

sub sub_aref (&\@) {
    print "# \@_ = (",join(",", map {dump::view($_)} @_),")\n";
    my@($sub,$array) =  @_;
    ok( (nelems @_) == 2 && (nelems @{$array}) == 4 );
    print < map { &{$sub}($_) } @{$array}
}

##
##
##

testing \&sub_array, '&@';

sub sub_array (&@) {
    print "# \@_ = (",join(",", map {dump::view($_)} @_),")\n";
    ok((nelems @_) == 5);
    my $sub = shift;
    print < map { &{$sub}($_) } @_
}

##
##
##

testing \&a_hash_ref, '\%';

sub a_hash_ref (\%) {
    print "# \@_ = (",join(",", map {dump::view($_)} @_),")\n";
    ok( ref(@_[0]) && @_[0]->{?'a'} );
    @_[0]->{+'b'} = 2;
}

%hash = %( a => 1);
a_hash_ref %hash;
ok( %hash{?'b'} == 2 );

##
##
##

my $p;
ok( not defined prototype('CORE::print') );

ok( not defined prototype('CORE::system') );

ok( not ($p = prototype('CORE::open')) ne '*;$@' );

ok( not defined ($p = try { prototype('CORE::Foo') or 1 }) or $^EVAL_ERROR->message !~ m/^Can't find an opnumber/ );

# correctly note too-short parameter lists that don't end with '$',
#  a possible regression.

sub foo1 ($\@) { 1 };
eval q{ foo1 "s" };
ok( $^EVAL_ERROR->message =~ m/^Not enough/ );

sub foo2 ($\%) { 1 };
eval q{ foo2 "s" };
ok( $^EVAL_ERROR->message =~ m/^Not enough/ );

