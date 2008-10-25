package Devel::switchd;
 BEGIN { } # use strict; BEGIN { ... } to incite [perl #21890]
sub import { print "import<$(join ' ',@_)>;" }
1;

