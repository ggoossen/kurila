#!./perl

BEGIN 
    push: $^INCLUDE_PATH, 'lib'


use warnings
use Test::More tests => 14

use mypragma () # don't enable this pragma yet

BEGIN 
    is: $^HINTS{?mypragma}, undef, "Shouldn't be in %^H yet"


is: (mypragma::in_effect: ), undef, "pragma not in effect yet"
do
    is: (mypragma::in_effect: ), undef, "pragma not in effect yet"
    eval qq{is(mypragma::in_effect(), undef, "pragma not in effect yet"); 1}
        or die: $^EVAL_ERROR

    use mypragma
    use Sans_mypragma;
    is: (mypragma::in_effect: ), 42, "pragma is in effect within this block"
    is: (Sans_mypragma::affected: ), undef
        "pragma not in effect outside this file"
    eval qq{is(mypragma::in_effect(), 42,
               "pragma is in effect within this eval"); 1} or die: $^EVAL_ERROR

    do
        no mypragma
        is: (mypragma::in_effect: ), 0, "pragma no longer in effect"
        eval qq{is(mypragma::in_effect(), 0, "pragma no longer in effect"); 1}
            or die: $^EVAL_ERROR
    

    is: (mypragma::in_effect: ), 42, "pragma is in effect within this block"
    eval qq{is(mypragma::in_effect(), 42,
               "pragma is in effect within this eval"); 1} or die: $^EVAL_ERROR

is: (mypragma::in_effect: ), undef, "pragma no longer in effect"
eval qq{is(mypragma::in_effect(), undef, "pragma not in effect"); 1} or die: $^EVAL_ERROR


BEGIN 
    is: $^HINTS{?mypragma}, undef, "Should no longer be in %^H"

