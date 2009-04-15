#!./perl

require './test.pl';

plan(95);

our ($bar, $foo, $baz, $FOO, $BAR, $BAZ, @ary, @ref,
     @a, @b, @c, @d, $ref, $object, @foo, @bar, @baz,
     $refref, $x, %whatever, @spring, %spring2,
     $subref, $subrefref, $anonhash, $anonhash2, $object2, $THIS,
     @ARGS, $string);

# Test real references.

$FOO = \$BAR;
$BAR = \$BAZ;
$BAZ = "hit";
is ($$$FOO, 'hit');

# test that vstring are blessed 'version' objects
my $vstref = v1;
is (ref($vstref), "version", "ref(vstr) eq 'version'");

# Test references to real arrays.

my $test = curr_test();
@ary = @($test,$test+1,$test+2,$test+3);
@ref[+0] = \@a;
@ref[+1] = \@b;
@ref[+2] = \@c;
@ref[+3] = \@d;
for my $i (@(3,1,2,0)) {
    push(@{@ref[$i]}, "ok @ary[$i]\n");
}
print $^STDOUT, < @a;
print $^STDOUT, @{@ref[1]}[0];
print $^STDOUT, < @{@ref[2]}[[@(0)]];
do {
    print $^STDOUT, < @{*{Symbol::fetch_glob('d')}};
};
curr_test($test+4);

# Test references to references.

$refref = \\$x;
$x = "Good";
is ($$$refref, 'Good');

# Test nested anonymous lists.

$ref = \@(\@(),2,\@(3,4,5,));
is (scalar nelems @$ref, 3);
is (@$ref[1], 2);
is (@{@$ref[2]}[2], 5);
is (scalar nelems @{@$ref[0]}, 0);

is ($ref->[1], 2);
is ($ref->[2]->[0], 3);

# Test references to hashes of references.

$refref = \%whatever;
$refref->{+"key"} = $ref;
is ($refref->{"key"}->[2]->[0], 3);

# Test to see if anonymous subarrays spring into existence.

@spring[+5]->[+0] = 123;
@spring[5]->[+1] = 456;
push(@{@spring[5]}, 789);
is (join(':', @{@spring[5]}), "123:456:789");

# Test to see if anonymous subhashes spring into existence.

@{%spring2{+"foo"}} = @(1,2,3);
%spring2{"foo"}->[+3] = 4;
is (join(':', @{%spring2{?"foo"}}), "1:2:3:4");

# Test references to subroutines.

do {
    my $called;
    sub mysub { $called++; }
    $subref = \&mysub;
    &$subref( < @_ );
    is ($called, 1);
};

$subrefref = \\&mysub2;
is ( $$subrefref->("GOOD"), "good");
sub mysub2 { lc shift }

# Test the ref operator.

is (ref $subref, 'CODE');
is (ref $ref, 'ARRAY');
is (ref $refref, 'HASH');

# Test anonymous hash syntax.

$anonhash = \%();
is (ref $anonhash, 'HASH');
$anonhash2 = \%(FOO => 'BAR', ABC => 'XYZ',);
is (join('', sort values %$anonhash2), 'BARXYZ');

# Test ->[$@%&*] derefence syntax
do {
    my $z = \66;
    is($z->$, 66);
    my $y = \@(1,2,3,4);
    is(join(':', $y->@), "1:2:3:4");
    my $x = \%( aap => 'noot', mies => "teun" );
    is((join "*", keys $x->%), join "*", keys %$x);
    my $w = \*foo428;
    is(Symbol::glob_name($w->*), "main::foo428");
    my $v = sub { return @_[0]; };
    is($v->(55), 55);
};

# Test bless operator.

package MYHASH;

$object = bless $main::anonhash2;
main::is (ref $object, 'MYHASH');
main::is ($object->{?ABC}, 'XYZ');

$object2 = bless \%();
main::is (ref $object2,	'MYHASH');

# Test ordinary call on object method.

&mymethod($object,"argument");

sub mymethod {
    local($THIS) = shift;
    local @ARGS = @_;
    die 'Got a "' . ref($THIS). '" instead of a MYHASH'
	unless ref $THIS eq 'MYHASH';
    main::is (@ARGS[0], "argument");
    main::is ($THIS->{?FOO}, 'BAR');
}

# Test automatic destructor call.

$string = "bad";
$object = "foo";
$string = "good";
$main::anonhash2 = "foo";
$string = "";

sub DESTROY {
    return unless $string;
    main::is ($string, 'good');

    # Test that the object has not already been "cursed".
    main::isnt (ref shift, 'HASH');
}

# Now test inheritance of methods.

package OBJ;

our @ISA = @('BASEOBJ');

$main::object = bless \%(FOO => 'foo', BAR => 'bar');

package main;

# Test arrow-style method invocation.

is ($object->doit("BAR"), 'bar');

sub BASEOBJ::doit {
    local $ref = shift;
    die "Not an OBJ" unless ref $ref eq 'OBJ';
    $ref->{?shift()};
}

package main;

# test for proper destruction of lexical objects
$test = curr_test();
sub larry::DESTROY { print $^STDOUT, "# larry\nok $test\n"; }
sub curly::DESTROY { print $^STDOUT, "# curly\nok ", $test + 1, "\n"; }
sub moe::DESTROY   { print $^STDOUT, "# moe\nok ", $test + 2, "\n"; }

do {
    my ($joe, @curly, %larry);
    my $moe = bless \$joe, 'moe';
    my $curly = bless \@curly, 'curly';
    my $larry = bless \%larry, 'larry';
    print $^STDOUT, "# leaving block\n";
};

print $^STDOUT, "# left block\n";
curr_test($test + 3);


our $var = "glob 4";
$_   = \$var;
is ($$_, 'glob 4');

# test if @_[0] is properly protected in DESTROY()

do {
    my $test = curr_test();
    my $i = 0;
    local $^DIE_HOOK = sub {
	my $m = shift;
	if ($i++ +> 4) {
	    print $^STDOUT, "# infinite recursion, bailing\nnot ok $test\n";
	    exit 1;
        }
	like ($m->{?description}, qr/^Modification of a read-only/);
    };
    package C;
    sub new { bless \%(), shift }
    sub DESTROY { @_[0] = 'foo' }
    do {
	print $^STDOUT, "# should generate an error...\n";
	my $c = C->new;
    };
    print $^STDOUT, "# good, didn't recurse\n";
};

# test if refgen behaves with autoviv magic
do {
    my @a;
    @a[+1] = "good";
    my $got;
    for (@a) {
	$got .= ${\$_};
	$got .= ';';
    }
    is ($got, ";good;");
};

# This test is the reason for postponed destruction in sv_unref
$a = \@(1,2,3);
$a = $a->[1];
is ($a, 2);

# This test used to coredump. The BEGIN block is important as it causes the
# op that created the constant reference to be freed. Hence the only
# reference to the constant string "pass" is in $a. The hack that made
# sure $a = $a->[1] would work didn't work with references to constants.


foreach my $lexical (@('', 'my $a; ')) {
  my $expect = "pass\n";
  my $result = runperl (switches => \@('-wl'), stderr => 1,
    prog => $lexical . 'BEGIN {$a = \q{pass}}; $a = $$a; print $^STDOUT, $a');

  is ($^CHILD_ERROR, 0);
  is ($result, $expect);
}

$test = curr_test();
sub x::DESTROY {print $^STDOUT, "ok ", $test + shift->[0], "\n"}
do { my $a1 = bless \@(3),"x";
  my $a2 = bless \@(2),"x";
  do { my $a3 = bless \@(1),"x";
    my $a4 = bless \@(0),"x";
    567;
  };
};
curr_test($test+4);

is (runperl (switches=> \@('-l'),
	     prog=> 'print $^STDOUT, 1; print $^STDOUT, qq-*$^INPUT_RECORD_SEPARATOR*-;print $^STDOUT, 1;'),
    "1\n*\n*\n1\n");

# bug #22719

runperl(prog => 'sub f { my $x = shift; *z = $x; } f(\%()); f();');
is ($^CHILD_ERROR, 0, 'coredump on typeglob = (SvRV && !SvROK)');

# bug #27268: freeing self-referential typeglobs could trigger
# "Attempt to free unreferenced scalar" warnings

is (runperl(
    prog => 'use Symbol;my $x=bless \gensym,"t"; print $^STDOUT, $_;*$$x=$x',
    stderr => 1
), '', 'freeing self-referential typeglob');

TODO: do {
    my $name1 = "\0Chalk";
    my $name2 = "\0Cheese";

    isnt ($name1, $name2, "They differ");

    is (${*{Symbol::fetch_glob($name1)}}, undef, 'Nothing before we start (scalars)');
    is (${*{Symbol::fetch_glob($name2)}}, undef, 'Nothing before we start');
    ${*{Symbol::fetch_glob($name1)}} = "Yummy";
    is (${*{Symbol::fetch_glob($name1)}}, "Yummy", 'Accessing via the correct name works');
    is (${*{Symbol::fetch_glob($name2)}}, undef,
	'Accessing via a different NUL-containing name gives nothing');
    # defined uses a different code path
    ok (defined ${*{Symbol::fetch_glob($name1)}}, 'defined via the correct name works');
    ok (!defined ${*{Symbol::fetch_glob($name2)}},
	'defined via a different NUL-containing name gives nothing');

    is (*{Symbol::fetch_glob($name1)}->[+0], undef, 'Nothing before we start (arrays)');
    is (*{Symbol::fetch_glob($name2)}->[+0], undef, 'Nothing before we start');
    *{Symbol::fetch_glob($name1)}->[0] = "Yummy";
    is (*{Symbol::fetch_glob($name1)}->[0], "Yummy", 'Accessing via the correct name works');
    is (*{Symbol::fetch_glob($name2)}->[0], undef,
	'Accessing via a different NUL-containing name gives nothing');
    ok (defined *{Symbol::fetch_glob($name1)}->[0], 'defined via the correct name works');
    ok (!defined*{Symbol::fetch_glob($name2)}->[0],
	'defined via a different NUL-containing name gives nothing');

    my @(_, $one) =  @{*{Symbol::fetch_glob($name1)}}[[@(2,3)]];
    my @(_, $two) =  @{*{Symbol::fetch_glob($name2)}}[[@(2,3)]];
    is ($one, undef, 'Nothing before we start (array slices)');
    is ($two, undef, 'Nothing before we start');
     @{*{Symbol::fetch_glob($name1)}}[[@(2,3)]] = @("Very", "Yummy");
    @(_, $one) =  @{*{Symbol::fetch_glob($name1)}}[[@(2,3)]];
    @(_, $two) =  @{*{Symbol::fetch_glob($name2)}}[[@(2,3)]];
    is ($one, "Yummy", 'Accessing via the correct name works');
    is ($two, undef,
	'Accessing via a different NUL-containing name gives nothing');
    ok (defined $one, 'defined via the correct name works');
    ok (!defined $two,
	'defined via a different NUL-containing name gives nothing');

    is (*{Symbol::fetch_glob($name1)}->{?PWOF}, undef, 'Nothing before we start (hashes)');
    is (*{Symbol::fetch_glob($name2)}->{?PWOF}, undef, 'Nothing before we start');
    *{Symbol::fetch_glob($name1)}->{+PWOF} = "Yummy";
    is (*{Symbol::fetch_glob($name1)}->{?PWOF}, "Yummy", 'Accessing via the correct name works');
    is (*{Symbol::fetch_glob($name2)}->{?PWOF}, undef,
	'Accessing via a different NUL-containing name gives nothing');
    ok (defined *{Symbol::fetch_glob($name1)}->{?PWOF}, 'defined via the correct name works');
    ok (!defined *{Symbol::fetch_glob($name2)}->{?PWOF},
	'defined via a different NUL-containing name gives nothing');

    my @(_, $one) =  %{*{Symbol::fetch_glob($name1)}}{[@('SNIF', 'BEEYOOP')]};
    my @(_, $two) =  %{*{Symbol::fetch_glob($name2)}}{[@('SNIF', 'BEEYOOP')]};
    is ($one, undef, 'Nothing before we start (hash slices)');
    is ($two, undef, 'Nothing before we start');
     %{*{Symbol::fetch_glob($name1)}}{[@('SNIF', 'BEEYOOP')]} = @("Very", "Yummy");
    @(_, $one) =  %{*{Symbol::fetch_glob($name1)}}{[@('SNIF', 'BEEYOOP')]};
    @(_, $two) =  %{*{Symbol::fetch_glob($name2)}}{[@('SNIF', 'BEEYOOP')]};
    is ($one, "Yummy", 'Accessing via the correct name works');
    is ($two, undef,
	'Accessing via a different NUL-containing name gives nothing');
    ok (defined $one, 'defined via the correct name works');
    ok (!defined $two,
	'defined via a different NUL-containing name gives nothing');

    $name1 = "Left"; $name2 = "Left\0Right";
    our $glob1;

    is ($glob1, undef, "We get different typeglobs. In fact, undef");

    *{Symbol::fetch_glob($name1)} = sub {"One"};
    *{Symbol::fetch_glob($name2)} = sub {"Two"};

    is (&{*{Symbol::fetch_glob($name1)}}( < @_ ), "One");
    is (&{*{Symbol::fetch_glob($name2)}}( < @_ ), "Two");
};

# test dereferencing errors
do {
    foreach my $ref (@($^STDOUT)) {
	dies_like(sub { @$ref }, qr/Not an ARRAY reference/, "Array dereference");
	dies_like(sub { %$ref }, qr/Expected a HASH ref but got a IO ref/, "Hash dereference");
	dies_like(sub { &$ref( < @_ ) }, qr/Not a CODE reference/, "Code dereference");
    }

    $ref = $^STDOUT;
    try { *$ref };
    is($^EVAL_ERROR, '', "Glob dereference of PVIO is acceptable");

    cmp_ok($ref, '\==', *{$ref}{IO}, "IO slot of the temporary glob is set correctly");
};

# Bit of a hack to make test.pl happy. There are 3 more tests after it leaves.
$test = curr_test();
curr_test($test + 3);
# test global destruction

my $test1 = $test + 1;
my $test2 = $test + 2;

package FINALE;

our ($ref3, $ref1);

do {
    $ref3 = bless \@("ok $test2 - Package destruction\n");	# package destruction
    my $ref2 = bless \@("ok $test - Lexical destruction\n");	# lexical destruction
    local $ref1 = bless \@("ok $test1 - Dynamic destruction\n");	# dynamic destruction
    1;					# flush any temp values on stack
};

print $^STDOUT, "not ok $test2 # TODO Package destruction\n";

sub DESTROY {
    print $^STDOUT, @_[0]->[0];
}

