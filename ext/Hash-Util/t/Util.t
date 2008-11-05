#!/usr/bin/perl -Tw


use Test::More;
my @Exported_Funcs;
BEGIN {
    @Exported_Funcs = qw(
                     hash_seed all_keys
                     lock_keys unlock_keys
                     lock_value unlock_value
                     lock_hash unlock_hash
                     lock_keys_plus
                     hidden_keys legal_keys

                     lock_ref_keys unlock_ref_keys
                     lock_ref_value unlock_ref_value
                     lock_hashref unlock_hashref
                     lock_ref_keys_plus
                     hidden_ref_keys legal_ref_keys
                     hv_store

                    );
    plan tests => 204 + nelems @Exported_Funcs;
    use_ok 'Hash::Util', < @Exported_Funcs;
}
foreach my $func ( @Exported_Funcs) {
    can_ok __PACKAGE__, $func;
}

my %hash = %(foo => 42, bar => 23, locked => 'yep');
lock_keys(%hash);
try { %hash{baz} = 99; };
like( $@->{description}, qr/^Attempt to access disallowed key 'baz' in a restricted hash/,
                                                       'lock_keys()');
is( %hash{bar}, 23 );
ok( !exists %hash{baz},'!exists $hash{baz}' );

delete %hash{bar};
ok( !exists %hash{bar},'!exists $hash{bar}' );
%hash{bar} = 69;
is( %hash{bar}, 69 ,'$hash{bar} == 69');

try { () = %hash{i_dont_exist} };
like( $@->{description}, qr/^Attempt to access disallowed key 'i_dont_exist' in a restricted hash/,
      'Disallowed 1' );

lock_value(%hash, 'locked');
try { print "# oops" if %hash{four} };
like( $@->{description}, qr/^Attempt to access disallowed key 'four' in a restricted hash/,
      'Disallowed 2' );

try { %hash{"\x{2323}"} = 3 };
like( $@->{description}, qr/^Attempt to access disallowed key '(.*)' in a restricted hash/,
                                               'wide hex key' );

try { delete %hash{locked} };
like( $@->{description}, qr/^Attempt to delete readonly key 'locked' from a restricted hash/,
                                           'trying to delete a locked key' );
try { %hash{locked} = 42; };
like( $@->{description}, qr/^Modification of a read-only value attempted/,
                                           'trying to change a locked key' );
is( %hash{locked}, 'yep' );

try { delete %hash{I_dont_exist} };
like( $@->{description}, qr/^Attempt to delete disallowed key 'I_dont_exist' from a restricted hash/,
                             'trying to delete a key that doesnt exist' );

ok( !exists %hash{I_dont_exist},'!exists $hash{I_dont_exist}' );

unlock_keys(%hash);
%hash{I_dont_exist} = 42;
is( %hash{I_dont_exist}, 42,    'unlock_keys' );

try { %hash{locked} = 42; };
like( $@->{description}, qr/^Modification of a read-only value attempted/,
                             '  individual key still readonly' );
try { delete %hash{locked} },
is( $@, '', '  but can be deleted :(' );

unlock_value(%hash, 'locked');
%hash{locked} = 42;
is( %hash{locked}, 42,  'unlock_value' );


do {
    my %hash = %( foo => 42, locked => 23 );

    lock_keys(%hash);
    try { %hash = %( wubble => 42 ) };  # we know this will bomb
    local $TODO = 1;
    like( $@->{description}, qr/^Attempt to access disallowed key 'wubble'/,'Disallowed 3' );
    unlock_keys(%hash);
};

do {
    my %hash = %(KEY => 'val', RO => 'val');
    lock_keys(%hash);
    lock_value(%hash, 'RO');

    try { %hash = %(KEY => 1) };
    local $TODO = 1;
    like( $@->{description}, qr/^Attempt to delete readonly key 'RO' from a restricted hash/ );
};

do {
    my %hash = %(KEY => 1, RO => 2);
    lock_keys(%hash);
    try { %hash = %(KEY => 1, RO => 2) };
    local $TODO = 1;
    is( $@, '');
};



do {
    my %hash = %( () );
    lock_keys(%hash, < qw(foo bar));
    is( nkeys %hash, 0,  'lock_keys() w/keyset shouldnt add new keys' );
    %hash{foo} = 42;
    is( nkeys %hash, 1 );
    try { %hash{wibble} = 42 };
    like( $@->{description}, qr/^Attempt to access disallowed key 'wibble' in a restricted hash/,
                        'write threw error (locked)');

    unlock_keys(%hash);
    try { %hash{wibble} = 23; };
    is( $@, '', 'unlock_keys' );
};


do {
    my %hash = %(foo => 42, bar => undef, baz => 0);
    lock_keys(%hash, < qw(foo bar baz up down));
    is( nkeys %hash, 3,   'lock_keys() w/keyset didnt add new keys' );
    is_deeply( \%hash, \%( foo => 42, bar => undef, baz => 0 ),'is_deeply' );

    try { %hash{up} = 42; };
    is( $@, '','No error 1' );

    try { %hash{wibble} = 23 };
    like( $@->{description}, qr/^Attempt to access disallowed key 'wibble' in a restricted hash/,
          'locked "wibble"' );
};


do {
    my %hash = %(foo => 42, bar => undef);
    try { lock_keys(%hash, < qw(foo baz)); };
    is( $@->{description}, sprintf("Hash has key 'bar' which is not in the new key set"),
                    'carp test' );
};


do {
    my %hash = %(foo => 42, bar => 23);
    lock_hash( %hash );

    ok( Internals::SvREADONLY(%hash),'Was locked %hash' );
    ok( Internals::SvREADONLY(%hash{foo}),'Was locked $hash{foo}' );
    ok( Internals::SvREADONLY(%hash{bar}),'Was locked $hash{bar}' );

    unlock_hash ( %hash );

    ok( !Internals::SvREADONLY(%hash),'Was unlocked %hash' );
    ok( !Internals::SvREADONLY(%hash{foo}),'Was unlocked $hash{foo}' );
    ok( !Internals::SvREADONLY(%hash{bar}),'Was unlocked $hash{bar}' );
};


lock_keys(%ENV);
try { () = %ENV{I_DONT_EXIST} };
like( $@->{description}, qr/^Attempt to access disallowed key 'I_DONT_EXIST' in a restricted hash/,   'locked %ENV');

do {
    my %hash;

    lock_keys(%hash, 'first');

    is (nkeys %hash, 0, "place holder isn't a key");
    %hash{first} = 1;
    is (nkeys %hash, 1, "we now have a key");
    delete %hash{first};
    is (nkeys %hash, 0, "now no key");

    unlock_keys(%hash);

    %hash{interregnum} = 1.5;
    is (nkeys %hash, 1, "key again");
    delete %hash{interregnum};
    is (nkeys %hash, 0, "no key again");

    lock_keys(%hash, 'second');

    is (nkeys %hash, 0, "place holder isn't a key");

    try {%hash{zeroeth} = 0};
    like ($@->{description},
          qr/^Attempt to access disallowed key 'zeroeth' in a restricted hash/,
          'locked key never mentioned before should fail');
    try {%hash{first} = -1};
    like ($@->{description},
          qr/^Attempt to access disallowed key 'first' in a restricted hash/,
          'previously locked place holders should also fail');
    is (nkeys %hash, 0, "and therefore there are no keys");
    %hash{second} = 1;
    is (nkeys %hash, 1, "we now have just one key");
    delete %hash{second};
    is (nkeys %hash, 0, "back to zero");

    unlock_keys(%hash); # We have deliberately left a placeholder.

    %hash{void} = undef;
    %hash{nowt} = undef;

    is (nkeys %hash, 2, "two keys, values both undef");

    lock_keys(%hash);

    is (nkeys %hash, 2, "still two keys after locking");

    try {%hash{second} = -1};
    like ($@->{description},
          qr/^Attempt to access disallowed key 'second' in a restricted hash/,
          'previously locked place holders should fail');

    is (%hash{void}, undef,
        "undef values should not be misunderstood as placeholders");
    is (%hash{nowt}, undef,
        "undef values should not be misunderstood as placeholders (again)");
};

do {
  # perl #18651 - tim@consultix-inc.com found a rather nasty data dependant
  # bug whereby hash iterators could lose hash keys (and values, as the code
  # is common) for restricted hashes.

  my @keys = qw(small medium large);

  # There should be no difference whether it is restricted or not
  foreach my $lock (@(0, 1)) {
    # Try setting all combinations of the 3 keys
    foreach my $usekeys (0..7) {
      my @usekeys;
      for my $bits (@(0,1,2)) {
	push @usekeys, @keys[$bits] if $usekeys ^&^ (1 << $bits);
      }
      my %clean = %( < map {$_ => length $_} @usekeys );
      my %target;
      lock_keys ( %target, < @keys ) if $lock;

      while (my ($k, $v) = each %clean) {
	%target{$k} = $v;
      }

      my $message
	= ($lock ? 'locked' : 'not locked') . ' keys ' . join ',', @usekeys;

      is (nkeys %target, nkeys %clean, "scalar keys for $message");
      is (nelems( values %target), nelems(values %clean),
	  "scalar values for $message");
      # Yes. All these sorts are necessary. Even for "identical hashes"
      # Because the data dependency of the test involves two of the strings
      # colliding on the same bucket, so the iterator order (output of keys,
      # values, each) depends on the addition order in the hash. And locking
      # the keys of the hash involves behind the scenes key additions.
      is_deeply( (sort keys %target) , (sort keys %clean),
		 "list keys for $message");
      is_deeply( (sort values %target) , (sort values %clean),
		 "list values for $message");

      is_deeply( (sort @: < %target) , (sort @: < %clean ),
		 "hash in list context for $message");

      my (@clean, @target);
      while (my ($k, $v) = each %clean) {
	push @clean, $k, $v;
      }
      while (my ($k, $v) = each %target) {
	push @target, $k, $v;
      }

      is_deeply( (sort @target) , (sort @clean),
		 "iterating with each for $message");
    }
  }
};

# Check clear works on locked empty hashes - SEGVs on 5.8.2.
TODO: do {
    todo_skip("magic", 1);
    my %hash;
    lock_hash(%hash);
    %hash = %( () );
    ok(nkeys(%hash) == 0, 'clear empty lock_hash() hash');
};
TODO: do {
    todo_skip("magic", 1);
    my %hash;
    lock_keys(%hash);
    %hash = %( () );
    ok(nkeys(%hash) == 0, 'clear empty lock_keys() hash');
};

my $hash_seed = hash_seed();
ok($hash_seed +>= 0, "hash_seed $hash_seed");

do {
    package Minder;
    my $counter;
    sub DESTROY {
	--$counter;
    }
    sub new {
	++$counter;
	bless \@(), __PACKAGE__;
    }
    package main;

    for my $state (@('', 'locked')) {
	my $a = Minder->new();
	is ($counter, 1, "There is 1 object $state");
	my %hash;
	%hash{a} = $a;
	is ($counter, 1, "There is still 1 object $state");

	lock_keys(%hash) if $state;

	is ($counter, 1, "There is still 1 object $state");
	undef $a;
	is ($counter, 1, "Still 1 object $state");
	delete %hash{a};
	is ($counter, 0, "0 objects when hash key is deleted $state");
	%hash{a} = undef;
	is ($counter, 0, "Still 0 objects $state");
      TODO: do {
            todo_skip("read-only", 1);
            %hash = %( () );
            is ($counter, 0, "0 objects after clear $state");
        };
    }
};
do {
    my %hash = %( < map {$_,$_} qw(fwiffffff foosht teeoo) );
    lock_keys(%hash);
    delete %hash{fwiffffff};
    is (nkeys %hash, 2,"Count of keys after delete on locked hash");
    unlock_keys(%hash);
    is (nkeys %hash, 2,"Count of keys after unlock");

    my ($first, $value) = each %hash;
    is (%hash{$first}, $value, "Key has the expected value before the lock");
    lock_keys(%hash);
    is (%hash{$first}, $value, "Key has the expected value after the lock");

    my ($second, $v2) = each %hash;

    is (%hash{$first}, $value, "Still correct after iterator advances");
    is (%hash{$second}, $v2, "Other key has the expected value");
};
do {
    my $x='foo';
    my %test;
    hv_store(%test,'x',$x);
    is(%test{x},'foo','hv_store() stored');
    %test{x}='bar';
    is($x,'bar','hv_store() aliased');
    is(%test{x},'bar','hv_store() aliased and stored');
};

do {
    my %hash= %(< map { $_ => 1 } qw( a b c d e f) );
    delete %hash{c};
    lock_keys(%hash);
    ok(Internals::SvREADONLY(%hash),'lock_keys DDS/t 1');
    delete %hash{[qw(b e)]};
    my @hidden=sort(hidden_keys(%hash));
    my @legal=sort(legal_keys(%hash));
    my @keys=sort(keys(%hash));
    #warn "@legal\n@keys\n";
    is("$(join ' ',@hidden)","b e",'lock_keys @hidden DDS/t');
    is("$(join ' ',@legal)","a b d e f",'lock_keys @legal DDS/t');
    is("$(join ' ',@keys)","a d f",'lock_keys @keys DDS/t');
};
do {
    my %hash=%( <0..9);
    lock_keys(%hash);
    ok(Internals::SvREADONLY(%hash),'lock_keys DDS/t 2');
    Hash::Util::unlock_keys(%hash);
    ok(!Internals::SvREADONLY(%hash),'unlock_keys DDS/t 2');
};
do {
    my %hash=%( <0..9);
    lock_keys(%hash, <keys(%hash), <'a'..'f');
    ok(Internals::SvREADONLY(%hash),'lock_keys args DDS/t');
    my @hidden=sort(hidden_keys(%hash));
    my @legal=sort(legal_keys(%hash));
    my @keys=sort(keys(%hash));
    is("$(join ' ',@hidden)","a b c d e f",'lock_keys() @hidden DDS/t 3');
    is("$(join ' ',@legal)","0 2 4 6 8 a b c d e f",'lock_keys() @legal DDS/t 3');
    is("$(join ' ',@keys)","0 2 4 6 8",'lock_keys() @keys');
};
do {
    my %hash= %(< map { $_ => 1 } qw( a b c d e f) );
    delete %hash{c};
    lock_ref_keys(\%hash);
    ok(Internals::SvREADONLY(%hash),'lock_ref_keys DDS/t');
    delete %hash{[qw(b e)]};
    my @hidden=sort(hidden_keys(%hash));
    my @legal=sort(legal_keys(%hash));
    my @keys=sort(keys(%hash));
    #warn "@legal\n@keys\n";
    is("$(join ' ',@hidden)","b e",'lock_ref_keys @hidden DDS/t 1');
    is("$(join ' ',@legal)","a b d e f",'lock_ref_keys @legal DDS/t 1');
    is("$(join ' ',@keys)","a d f",'lock_ref_keys @keys DDS/t 1');
};
do {
    my %hash=%( <0..9);
    lock_ref_keys(\%hash, <keys %hash, <'a'..'f');
    ok(Internals::SvREADONLY(%hash),'lock_ref_keys args DDS/t');
    my @hidden=sort(hidden_keys(%hash));
    my @legal=sort(legal_keys(%hash));
    my @keys=sort(keys(%hash));
    is("$(join ' ',@hidden)","a b c d e f",'lock_ref_keys() @hidden DDS/t 2');
    is("$(join ' ',@legal)","0 2 4 6 8 a b c d e f",'lock_ref_keys() @legal DDS/t 2');
    is("$(join ' ',@keys)","0 2 4 6 8",'lock_ref_keys() @keys DDS/t 2');
};
do {
    my %hash=%( <0..9);
    lock_ref_keys_plus(\%hash, <'a'..'f');
    ok(Internals::SvREADONLY(%hash),'lock_ref_keys_plus args DDS/t');
    my @hidden=sort(hidden_keys(%hash));
    my @legal=sort(legal_keys(%hash));
    my @keys=sort(keys(%hash));
    is("$(join ' ',@hidden)","a b c d e f",'lock_ref_keys_plus() @hidden DDS/t');
    is("$(join ' ',@legal)","0 2 4 6 8 a b c d e f",'lock_ref_keys_plus() @legal DDS/t');
    is("$(join ' ',@keys)","0 2 4 6 8",'lock_ref_keys_plus() @keys DDS/t');
};
do {
    my %hash=%( <0..9);
    lock_keys_plus(%hash, <'a'..'f');
    ok(Internals::SvREADONLY(%hash),'lock_keys_plus args DDS/t');
    my @hidden=sort(hidden_keys(%hash));
    my @legal=sort(legal_keys(%hash));
    my @keys=sort(keys(%hash));
    is("$(join ' ',@hidden)","a b c d e f",'lock_keys_plus() @hidden DDS/t 3');
    is("$(join ' ',@legal)","0 2 4 6 8 a b c d e f",'lock_keys_plus() @legal DDS/t 3');
    is("$(join ' ',@keys)","0 2 4 6 8",'lock_keys_plus() @keys DDS/t 3');
};

do {
    my %hash = %( <'a'..'f');
    my @keys = @( () );
    my @ph = @( () );
    my @lock = @('a', 'c', 'e', 'g');
    lock_keys(%hash, < @lock);
    my $ref = all_keys(%hash, @keys, @ph);
    my @crrack = sort( @keys);
    my @ooooff = qw(a c e);
    my @bam = qw(g);

    ok(ref $ref eq ref \%hash && $ref \== \%hash, 
            "all_keys() - \$ref is a reference to \%hash");
    is_deeply(\@crrack, \@ooooff, "Keys are what they should be");
    is_deeply(\@ph, \@bam, "Placeholders in place");
};

