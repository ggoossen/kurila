#!/usr/bin/perl -w

use Test::More tests => 9

use_ok: 'parent'


package No::Version

do
    our $Foo;
sub VERSION { 42 }

package Test::Version

use parent '-norequire', 'No::Version'
main::is:  $No::Version::VERSION, undef,          '$VERSION gets left alone' 

# Test Inverse: parent.pm should not clobber existing $VERSION
package Has::Version

BEGIN { $Has::Version::VERSION = '42' }

package Test::Version2

use parent '-norequire', 'Has::Version'
main::is:  $Has::Version::VERSION, 42 

package main

my $eval1 = q{
do
    package Eval1
    do
      package Eval2
      use parent '-norequire', 'Eval1'
      $Eval2::VERSION = "1.02"

    $Eval1::VERSION = "1.01"
}

eval $eval1
die: if $^EVAL_ERROR

# String comparisons, just to be safe from floating-point errors
is:  $Eval1::VERSION, '1.01' 

is:  $Eval2::VERSION, '1.02' 


eval q{use parent 'reallyReAlLyNotexists'}
like:  ($^EVAL_ERROR->message: ), q{/^Can't locate reallyReAlLyNotexists.pm in \$\^INCLUDE_PATH \(\$\^INCLUDE_PATH contains:/}, 'baseclass that does not exist'

eval q{use parent 'reallyReAlLyNotexists'}
like:  ($^EVAL_ERROR->message: ), q{/^Can't locate reallyReAlLyNotexists.pm in \$\^INCLUDE_PATH \(\$\^INCLUDE_PATH contains:/}, '  still failing on 2nd load'
do
    my $warning
    local $^WARN_HOOK = sub { $warning = shift }
    eval q{package HomoGenous; use parent 'HomoGenous';}
    like: ($warning->message: )
          q{/^Class 'HomoGenous' tried to inherit from itself/}
          '  self-inheriting'

do
    BEGIN $Has::Version_0::VERSION = 0

    package Test::Version3

    use parent '-norequire', 'Has::Version_0'
    main::is:  $Has::Version_0::VERSION, 0, '$VERSION==0 preserved' 
