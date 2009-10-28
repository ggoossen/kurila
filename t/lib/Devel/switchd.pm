package Devel::switchd
BEGIN { }
sub import { (print: $^STDOUT, "import<$((join: ' ',@_))>;") }
1

