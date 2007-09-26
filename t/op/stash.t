#!./perl

BEGIN { require "./test.pl"; }

plan( tests => 12 );

# Used to segfault (bug #15479)
fresh_perl_is(
    '%:: = ""',
    'Odd number of elements in hash assignment at - line 1.',
    { switches => [ '-w' ] },
    'delete $::{STDERR} and print a warning',
);

# Used to segfault
fresh_perl_is(
    'BEGIN { $::{"X::"} = 2 }',
    '',
    { switches => [ '-w' ] },
    q(Insert a non-GV in a stash, under warnings 'once'),
);

{
    no strict 'refs';
    ok( !scalar %{Symbol::stash("oedipa::maas")}, q(stashes aren't defined if not used) );
    ok( !scalar %{*{Symbol::qualify_to_ref("oedipa::maas::")}}, q(- work with hard refs too) );

    ok( defined %{Symbol::stash("tyrone::slothrop")}, q(stashes are defined if seen at compile time) );
    ok( defined %{*{Symbol::qualify_to_ref("tyrone::slothrop::")}}, q(- work with hard refs too) );

    ok( defined %{Symbol::stash("bongo::shaftsbury")}, q(stashes are defined if a var is seen at compile time) );
    ok( defined %{*{Symbol::qualify_to_ref("bongo::shaftsbury::")}}, q(- work with hard refs too) );
}

package tyrone::slothrop;
$bongo::shaftsbury::scalar = 1;

package main;

# Used to warn
# Unbalanced string table refcount: (1) for "A::" during global destruction.
# for ithreads.
{
    local $ENV{PERL_DESTRUCT_LEVEL} = 2;
    fresh_perl_is(
		  'package A; sub a { // }; %::=""',
		  '',
		  '',
		  );
}

# now tests in eval

ok( !eval  { scalar %{Symbol::stash("achtfaden")} },   'works in eval{}' );
ok( !eval q{ defined %schoenmaker:: }, 'works in eval("")' );

# now tests with strictures

use strict;
ok( !scalar %{Symbol::stash("pig")}, q(referencing a non-existent stash doesn't produce stricture errors) );
