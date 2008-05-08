#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = '.'; 
    push @INC, '../lib';
}

use Tie::Array;
tie our @foo,'Tie::StdArray';
tie our @ary,'Tie::StdArray';
tie our @bar,'Tie::StdArray';
require "sv/array.t"
