#!/usr/bin/perl -w

BEGIN {
    if( %ENV{PERL_CORE} ) {
        chdir 't';
        @INC = @('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;

use Test::Builder;
require Test::Simple::Catch;
my($out, $err) = < Test::Simple::Catch::caught();
Test::Builder->new->no_header(1);
Test::Builder->new->no_ending(1);
local %ENV{HARNESS_ACTIVE} = 0;


# Can't use Test.pm, that's a 5.005 thing.
package main;


my $TB = Test::Builder->create;
$TB->plan(tests => 66);

# Utility testing functions.
sub ok ($;$) {
    return $TB->ok(< @_);
}

sub is ($$;$) {
    my($this, $that, $name) = < @_;

    my $ok = $TB->is_eq($$this, $that, $name);

    $$this = '';

    return $ok;
}

sub like ($$;$) {
    my($this, $regex, $name) = < @_;
    $regex = "/$regex/" if !ref $regex and $regex !~ m{^/.*/$}s;

    my $ok = $TB->like($$this, $regex, $name);

    $$this = '';

    return $ok;
}


require Test::More;
Test::More->import(tests => 11, import => \@('is_deeply'));

my $Filename = quotemeta $0;

#line 68
ok !is_deeply('foo', 'bar', 'plain strings');
is( $out, "not ok 1 - plain strings\n",     'plain strings' );
is( $err, <<ERRHEAD . <<'ERR',                            '    right diagnostic' );
#   Failed test 'plain strings'
#   at $0 line 68.
ERRHEAD
#     Structures begin differing at:
#          $got = 'foo'
#     $expected = 'bar'
ERR


#line 78
ok !is_deeply(\%(), \@(), 'different types');
is( $out, "not ok 2 - different types\n",   'different types' );
is( $err, <<ERRHEAD . <<'ERR',                          '   right diagnostic' );
#   Failed test 'different types'
#   at $0 line 78.
ERRHEAD
#     Structures begin differing at:
#     ${     $got} = %(HASH (TODO))
#     ${$expected} = @(ARRAY (TODO))
ERR

#line 88
ok !is_deeply(\%( this => 42 ), \%( this => 43 ), 'hashes with different values');
is( $out, "not ok 3 - hashes with different values\n", 
                                        'hashes with different values' );
is( $err, <<ERRHEAD . <<'ERR',                        '   right diagnostic' );
#   Failed test 'hashes with different values'
#   at $0 line 88.
ERRHEAD
#     Structures begin differing at:
#          $got->{this} = '42'
#     $expected->{this} = '43'
ERR

#line 99
ok !is_deeply(\%( that => 42 ), \%( this => 42 ), 'hashes with different keys');
is( $out, "not ok 4 - hashes with different keys\n",
                                        'hashes with different keys' );
is( $err, <<ERR,                        '    right diagnostic' );
#   Failed test 'hashes with different keys'
#   at $0 line 99.
#     Structures begin differing at:
#          \$got->\{this\} = Does not exist
#     \$expected->\{this\} = 42
ERR

#line 110
ok !is_deeply(\@(1..9), \@(1..10),    'arrays of different length');
is( $out, "not ok 5 - arrays of different length\n",
                                        'arrays of different length' );
is( $err, <<ERR,                        '    right diagnostic' );
#   Failed test 'arrays of different length'
#   at $0 line 110.
#     Structures begin differing at:
#          \$got->[9] = Does not exist
#     \$expected->[9] = 10
ERR

#line 121
ok !is_deeply(\@(undef, undef), \@(undef), 'arrays of undefs' );
is( $out, "not ok 6 - arrays of undefs\n",  'arrays of undefs' );
is( $err, <<ERR,                            '    right diagnostic' );
#   Failed test 'arrays of undefs'
#   at $0 line 121.
#     Structures begin differing at:
#          \$got->[1] = undef
#     \$expected->[1] = Does not exist
ERR

#line 131
ok !is_deeply(\%( foo => undef ), \%(),    'hashes of undefs' );
is( $out, "not ok 7 - hashes of undefs\n",  'hashes of undefs' );
is( $err, <<ERR,                            '    right diagnostic' );
#   Failed test 'hashes of undefs'
#   at $0 line 131.
#     Structures begin differing at:
#          \$got->\{foo\} = undef
#     \$expected->\{foo\} = Does not exist
ERR

#line 141
ok !is_deeply(\42, \23,   'scalar refs');
is( $out, "not ok 8 - scalar refs\n",   'scalar refs' );
is( $err, <<ERRHEAD . <<'ERR',                        '    right diagnostic' );
#   Failed test 'scalar refs'
#   at $0 line 141.
ERRHEAD
#     Structures begin differing at:
#     ${     $got} = '42'
#     ${$expected} = '23'
ERR

#line 151
ok !is_deeply(\@(), \23,    'mixed scalar and array refs');
is( $out, "not ok 9 - mixed scalar and array refs\n",
                                        'mixed scalar and array refs' );
is( $err, <<ERRHEAD . <<'ERR',                      '    right diagnostic' );
#   Failed test 'mixed scalar and array refs'
#   at $0 line 151.
ERRHEAD
#     Structures begin differing at:
#     ${     $got} = @(ARRAY (TODO))
#     ${$expected} = 23
ERR


my($a1, $a2, $a3);
$a1 = \$a2;  $a2 = \$a3;
$a3 = 42;

my($b1, $b2, $b3);
$b1 = \$b2;  $b2 = \$b3;
$b3 = 23;

#line 173
ok !is_deeply($a1, $b1, 'deep scalar refs');
is( $out, "not ok 10 - deep scalar refs\n",     'deep scalar refs' );
is( $err, <<ERR,                              '    right diagnostic' );
#   Failed test 'deep scalar refs'
#   at $0 line 173.
#     Structures begin differing at:
#     \$\{\$\{     \$got\}\} = '42'
#     \$\{\$\{\$expected\}\} = '23'
ERR

# I don't know how to properly display this structure.
# $a2 = { foo => \$a3 };
# $b2 = { foo => \$b3 };
# is_deeply([$a1], [$b1], 'deep mixed scalar refs');

my $foo = \%(
           this => \@(1..10),
           that => \%( up => "down", left => "right" ),
          );

my $bar = \%(
           this => \@(1..10),
           that => \%( up => "down", left => "right", foo => 42 ),
          );

#line 198
ok !is_deeply( $foo, $bar, 'deep structures' );
ok( (nelems @Test::More::Data_Stack) == 0, '@Data_Stack not holding onto things' );
is( $out, "not ok 11 - deep structures\n",  'deep structures' );
is( $err, <<ERR,                            '    right diagnostic' );
#   Failed test 'deep structures'
#   at $0 line 198.
#     Structures begin differing at:
#          \$got->\{that\}->\{foo\} = Does not exist
#     \$expected->\{that\}->\{foo\} = 42
ERR


#line 221
my @tests = @(\@(),
             \@(qw(42)),
             \@(qw(42 23), qw(42 23))
            );

foreach my $test (< @tests) {
    my $num_args = (nelems @$test);

    my $warning;
    local $^WARN_HOOK = sub { $warning .= @_[0]->message; };
    ok !is_deeply(< @$test);

    like \$warning, 
         "/^is_deeply\\(\\) takes two or three args, you gave $num_args\.\n/";
}


#line 240
# [rt.cpan.org 6837]
ok !is_deeply(\@(\%(Foo => undef)),\@(\%(Foo => ""))), 'undef != ""';
ok( (nelems @Test::More::Data_Stack) == 0, '@Data_Stack not holding onto things' );


#line 258
# [rt.cpan.org 7031]
my $a = \@();
ok !is_deeply($a, dump::view($a).''),       "don't compare refs like strings";
ok !is_deeply(\@($a), \@(dump::view($a).'')),   "  even deep inside";


#line 265
# [rt.cpan.org 7030]
ok !is_deeply( \%(), \%(key => \@()) ),  '\@() could match non-existent values';
ok !is_deeply( \@(), \@(\@()) );


#line 273
$$err = $$out = '';
ok !is_deeply( \@(\'a', 'b'), \@(\'a', 'c') );
is( $out, "not ok 20\n",  'scalar refs in an array' );
is( $err, <<ERR,        '    right diagnostic' );
#   Failed test at $0 line 274.
#     Structures begin differing at:
#          \$got->[1] = 'b'
#     \$expected->[1] = 'c'
ERR


#line 285
my $ref = \23;
ok !is_deeply( 23, $ref );
is( $out, "not ok 21\n", 'scalar vs ref' );
is( $err, <<ERR,        '  right diagnostic');
#   Failed test at $0 line 286.
#     Structures begin differing at:
#          \$got = 23
#     \$expected = {dump::view($ref)}
ERR

#line 296
ok !is_deeply( $ref, 23 );
is( $out, "not ok 22\n", 'ref vs scalar' );
is( $err, <<ERR,        '  right diagnostic');
#   Failed test at $0 line 296.
#     Structures begin differing at:
#          \$got = {dump::view($ref)}
#     \$expected = 23
ERR

#line 306
ok !is_deeply( undef, \@() );
is( $out, "not ok 23\n", 'is_deeply and undef [RT 9441]' );
like( $err, <<ERR,	 '  right diagnostic' );
#   Failed test at $Filename line 306\\.
#     Structures begin differing at:
#          \\\$got = undef
#     \\\$expected = ARRAY\\(0x[0-9a-f]+\\)
ERR


# rt.cpan.org 8865
{
    my $array = \@();
    my $hash  = \%();

#line 321
    ok !is_deeply( $array, $hash );
    is( $out, "not ok 24\n", 'is_deeply and different reference types' );
    is( $err, <<ERRHEAD.<<'ERR', 	     '  right diagnostic' );
#   Failed test at $0 line 321.
#     Structures begin differing at:
ERRHEAD
#     ${     $got} = @(ARRAY (TODO))
#     ${$expected} = %(HASH (TODO))
ERR

#line 332
    ok !is_deeply( \@($array), \@($hash) );
    is( $out, "not ok 25\n", 'nested different ref types' );
    is( $err, <<ERRHEAD.<<'ERR',	     '  right diagnostic' );
#   Failed test at $0 line 332.
#     Structures begin differing at:
ERRHEAD
#     ${     $got->[0]} = @(ARRAY (TODO))
#     ${$expected->[0]} = %(HASH (TODO))
ERR

}


# rt.cpan.org 14746
{
  TODO: {
        $TB->todo_skip("different subs", 2);
        last TODO;

# line 349
        ok !is_deeply( sub {"foo"}, sub {"bar"} ), 'function refs';
        is( $out, "not ok 27\n" );
        like( $err, <<ERR,	     '  right diagnostic' );
#   Failed test at $Filename line 349.
#     Structures begin differing at:
#          \\\$got = CODE\\(0x[0-9a-f]+\\)
#     \\\$expected = CODE\\(0x[0-9a-f]+\\)
ERR
    }

    use Symbol;
    my $glob1 = gensym;
    my $glob2 = gensym;

  TODO: {
        $TB->todo_skip("different subs", 2);
        last TODO;
#line 357
        ok !is_deeply( $glob1, $glob2 ), 'typeglobs';
        is( $out, "not ok 28\n" );
        like( $err, <<ERR,	     '  right diagnostic' );
#   Failed test at $Filename line 357.
#     Structures begin differing at:
#          \\\$got = GLOB\\(0x[0-9a-f]+\\)
#     \\\$expected = GLOB\\(0x[0-9a-f]+\\)
ERR

    }
}
