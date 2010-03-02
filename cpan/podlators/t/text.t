#!/usr/bin/perl -w
#
# text.t -- Additional specialized tests for Pod::Text.
#
# Copyright 2002, 2004, 2006, 2007 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

use TestInit

BEGIN 
    $^OUTPUT_AUTOFLUSH = 1
    print: $^STDOUT, "1..4\n"


use Pod::Text
use Pod::Simple

print: $^STDOUT, "ok 1\n"

my $parser = (Pod::Text->new: ) or die: "Cannot create parser\n"
my $n = 2
while ( ~< $^DATA)
    next until $_ eq "###\n"
    open: my $tmp, ">", 'tmp.pod' or die: "Cannot create tmp.pod: $^OS_ERROR\n"
    while ( ~< $^DATA)
        last if $_ eq "###\n"
        print: $tmp, $_
    close $tmp
    open: my $out, ">", 'out.tmp' or die: "Cannot create out.tmp: $^OS_ERROR\n"
    $parser->parse_from_file : 'tmp.pod', $out
    close $out
    open: $tmp, "<", 'out.tmp' or die: "Cannot open out.tmp: $^OS_ERROR\n"
    my $output
    do
        local $^INPUT_RECORD_SEPARATOR = undef
        $output = ~< $tmp

    close $tmp
    unlink: 'tmp.pod', 'out.tmp'
    my $expected = ''
    while ( ~< $^DATA)
        last if $_ eq "###\n"
        $expected .= $_

    if ($output eq $expected)
        print: $^STDOUT, "ok $n\n"
    elsif ($n == 4 && $Pod::Simple::VERSION +< 3.06)
        print: $^STDOUT, "ok $n # skip Pod::Simple S<> parsing bug\n"
    else
        print: $^STDOUT, "not ok $n\n"
        print: $^STDOUT, "Expected\n========\n$expected\nOutput\n======\n$output\n"

    $n++

# Below the marker are bits of POD and corresponding expected text output.
# This is used to test specific features or problems with Pod::Text.  The
# input and output are separated by lines containing only ###.

__DATA__

###
=head1 PERIODS

This C<.> should be quoted.
###
PERIODS
    This "." should be quoted.

###

###
=head1 CE<lt>E<gt> WITH SPACES

What does C<<  this.  >> end up looking like?
###
C<> WITH SPACES
    What does "this." end up looking like?

###

###
=head1 Test of SE<lt>E<gt>

This is some S<  > whitespace.
###
Test of S<>
    This is some    whitespace.

###
==
