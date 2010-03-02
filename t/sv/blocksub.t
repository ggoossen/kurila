#!/usr/bin/perl

BEGIN 
    require "./test.pl"


plan: tests => 1

do
    my $blocksub = { return $_ }
    is: ( $blocksub->& <: 33), 33 

