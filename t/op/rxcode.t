#!./perl

BEGIN {
    require './test.pl';
}

plan tests => 38;

$^LAST_REGEXP_CODE_RESULT = undef;
like( 'a',  qr/^a(?{1})(?:b(?{2}))?/, 'a =~ ab?' );
cmp_ok( $^LAST_REGEXP_CODE_RESULT, '==', 1, '..$^R after a =~ ab?' );

$^LAST_REGEXP_CODE_RESULT = undef;
unlike( 'abc', qr/^a(?{3})(?:b(?{4}))$/, 'abc !~ a(?:b)$' );
ok( !defined $^LAST_REGEXP_CODE_RESULT, '..$^R after abc !~ a(?:b)$' );

$^LAST_REGEXP_CODE_RESULT = undef;
like( 'ab', qr/^a(?{5})b(?{6})/, 'ab =~ ab' );
cmp_ok( $^LAST_REGEXP_CODE_RESULT, '==', 6, '..$^R after ab =~ ab' );

$^LAST_REGEXP_CODE_RESULT = undef;
like( 'ab', qr/^a(?{7})(?:b(?{8}))?/, 'ab =~ ab?' );

cmp_ok( $^LAST_REGEXP_CODE_RESULT, '==', 8, '..$^R after ab =~ ab?' );

$^LAST_REGEXP_CODE_RESULT = undef;
like( 'ab', qr/^a(?{9})b?(?{10})/, 'ab =~ ab? (2)' );
cmp_ok( $^LAST_REGEXP_CODE_RESULT, '==', 10, '..$^R after ab =~ ab? (2)' );

$^LAST_REGEXP_CODE_RESULT = undef;
like( 'ab', qr/^(a(?{11})(?:b(?{12})))?/, 'ab =~ (ab)? (3)' );
cmp_ok( $^LAST_REGEXP_CODE_RESULT, '==', 12, '..$^R after ab =~ ab? (3)' );

$^LAST_REGEXP_CODE_RESULT = undef;
unlike( 'ac', qr/^a(?{13})b(?{14})/, 'ac !~ ab' );
ok( !defined $^LAST_REGEXP_CODE_RESULT, '..$^R after ac !~ ab' );

$^LAST_REGEXP_CODE_RESULT = undef;
like( 'ac', qr/^a(?{15})(?:b(?{16}))?/, 'ac =~ ab?' );
cmp_ok( $^LAST_REGEXP_CODE_RESULT, '==', 15, '..$^R after ac =~ ab?' );

my @ar;
like( 'ab', qr/^a(?{push @ar,101})(?:b(?{push @ar,102}))?/, 'ab =~ ab? with code push' );
cmp_ok( scalar(nelems @ar), '==', 2, '..@ar pushed' );
cmp_ok( @ar[0], '==', 101, '..first element pushed' );
cmp_ok( @ar[1], '==', 102, '..second element pushed' );

$^LAST_REGEXP_CODE_RESULT = undef;
unlike( 'a', qr/^a(?{103})b(?{104})/, 'a !~ ab with code push' );
ok( !defined $^LAST_REGEXP_CODE_RESULT, '..$^R after a !~ ab with code push' );

@ar = @( () );
unlike( 'a', qr/^a(?{push @ar,105})b(?{push @ar,106})/, 'a !~ ab (push)' );
cmp_ok( scalar(nelems @ar), '==', 0, '..nothing pushed' );

@ar = @( () );
unlike( 'abc', qr/^a(?{push @ar,107})b(?{push @ar,108})$/, 'abc !~ ab$ (push)' );
cmp_ok( scalar(nelems @ar), '==', 0, '..still nothing pushed' );

our (@var);

like( 'ab', qr/^a(?{push @var,109})(?:b(?{push @var,110}))?/, 'ab =~ ab? push to package var' );
cmp_ok( scalar(nelems @var), '==', 2, '..@var pushed' );
cmp_ok( @var[0], '==', 109, '..first element pushed (package)' );
cmp_ok( @var[1], '==', 110, '..second element pushed (package)' );

@var = @( () );
unlike( 'a', qr/^a(?{push @var,111})b(?{push @var,112})/, 'a !~ ab (push package var)' );
cmp_ok( scalar(nelems @var), '==', 0, '..nothing pushed (package)' );

@var = @( () );
unlike( 'abc', qr/^a(?{push @var,113})b(?{push @var,114})$/, 'abc !~ ab$ (push package var)' );
cmp_ok( scalar(nelems @var), '==', 0, '..still nothing pushed (package)' );

do {
    local $^LAST_REGEXP_CODE_RESULT = undef;
    ok( 'ac' =~ m/^a(?{30})(?:b(?{31})|c(?{32}))?/, 'ac =~ a(?:b|c)?' );
    ok( $^LAST_REGEXP_CODE_RESULT == 32, '$^R == 32' );
};
do {
    local $^LAST_REGEXP_CODE_RESULT = undef;
    ok( 'abbb' =~ m/^a(?{36})(?:b(?{37})|c(?{38}))+/, 'abbbb =~ a(?:b|c)+' );
    ok( $^LAST_REGEXP_CODE_RESULT == 37, '$^R == 37' ) or print "# \$^R=$^LAST_REGEXP_CODE_RESULT\n";
};
