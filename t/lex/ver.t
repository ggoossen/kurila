#!./perl

# Testing of v-string syntax

our $DOWARN

BEGIN 
    $^WARN_HOOK = sub (@< @_) { warn: @_[0] if $DOWARN }


$DOWARN = 1 # enable run-time warnings now

use Config

require "./test.pl"
plan:  tests => 7 

# printing characters should work
is: ref v111.107.32, 'version','ASCII printing characters'

# poetry optimization should also
sub v77 { "ok" }
my $x = (v77: )
is: 'ok',$x,'poetry optimization'

# but not when dots are involved
$x = v77.78.79
is: ($x->stringify: ), 'v77.78.79','poetry optimization with dots'

# hash keys too
eval "111.107.32"
like:  $^EVAL_ERROR->{?description}, qr/Too many decimal points/ 

# See if the things Camel-III says are true: 29..33

# Tests for magic v-strings

my $v = v1.2_3
is:  (ref: $v), 'version', 'v-string objects with v' 

# [perl #16010]
my %h = %: v65 => 42
ok:  exists %h{v65}, "v-stringness is not engaged for vX" 
eval ' %h = (65.66.67 => 42); '
like: $^EVAL_ERROR->{?description}, qr/Too many decimal points/


