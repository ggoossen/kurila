#!/usr/bin/perl -w

use Test::More tests => 10

use_ok: 'base'


package No::Version

our ($Foo)
sub VERSION { 42 }

package Test::Version

# Test Inverse of $VERSION bug base.pm should not clobber existing $VERSION
package Has::Version

BEGIN { $Has::Version::VERSION = '42' };

package Test::Version2

use base < qw(Has::Version)
main::is:  $Has::Version::VERSION, 42 

package main

my $eval1 = q{
  do {
    package Eval1;
    do {
      package Eval2;
      use base 'Eval1';
      $Eval2::VERSION = "1.02";
    };
    $Eval1::VERSION = "1.01";
  };
}

eval $eval1
is:  $^EVAL_ERROR, '' 

is:  $Eval1::VERSION, 1.01 

is:  $Eval2::VERSION, 1.02 


eval q{use base 'reallyReAlLyNotexists'}
like:  $^EVAL_ERROR->{?description}, qr/^Base class package "reallyReAlLyNotexists" is empty\./
       'base with empty package'

eval q{use base 'reallyReAlLyNotexists'}
like:  $^EVAL_ERROR->{?description}, qr/^Base class package "reallyReAlLyNotexists" is empty\./
       '  still empty on 2nd load'
do
    my $warning
    local $^WARN_HOOK = sub (@< @_) { $warning = shift }
    eval q{package HomoGenous; use base 'HomoGenous';}
    like: $warning->{?description}, qr/^Class 'HomoGenous' tried to inherit from itself/
          '  self-inheriting'


do
    BEGIN { $Has::Version_0::VERSION = 0 }

    package Test::Version3

    use base < qw(Has::Version_0)
    main::is:  $Has::Version_0::VERSION, 0, '$VERSION==0 preserved' 



do
    package Schlozhauer
    use constant FIELDS => 6

    package Basilisco
    eval q{ use base 'Schlozhauer' }
    main::is:  $^EVAL_ERROR, '', 'Can coexist with a FIELDS constant' 

