#!./perl -w

BEGIN 
    require './test.pl'


plan:  tests => 2 

is: ( { return 1 }->& <: ), 1 
is: ( { return 1 and 2 }->& <: ), 2 
