#!./perl


use Config

use Test::More tests => 9

use_ok:  'sigtrap' 

package main

# use a version of sigtrap.pm somewhat too high
try{ (sigtrap->import: 99999) }
like:  $^EVAL_ERROR->{?description}, qr/version 99999 required,/, 'import excessive version number' 

# use an invalid signal name
try{ (sigtrap->import: 'abadsignal') }
like:  $^EVAL_ERROR->{?description}, qr/^Unrecognized argument abadsignal/, 'send bad signame to import' 

try{ (sigtrap->import: 'handler') }
like:  $^EVAL_ERROR->{?description}, qr/^No argument specified/, 'send handler without subref' 

my @normal =qw( HUP INT PIPE TERM )
for (@normal)
    (signals::handler: $_) = 'DEFAULT'

sigtrap->import: 'normal-signals'
for (@normal)
    is:  (ref::svtype: (signals::handler: $_)), 'CODE'
         'check normal-signals set' 


# handler_die croaks with first argument
try { (sigtrap::handler_die: 'FAKE') }
like:  $^EVAL_ERROR->{?description}, qr/^Caught a SIGFAKE/, 'does handler_die() croak?' 
