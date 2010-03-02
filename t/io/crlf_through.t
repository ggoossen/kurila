#!./perl

no warnings 'once'
$main::use_crlf = 1
evalfile './io/through.t' or die: "no kid script"
