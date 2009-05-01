package Devel::switchd;
BEGIN { }
sub import(@< @_) { print $^STDOUT, "import<$(join ' ',@_)>;" }
1;

