#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = @( '.' ); 
    push @INC, '../lib';
}

use Tie::Array;
tie our @x,'Tie::StdArray';
require "op/push.t"
