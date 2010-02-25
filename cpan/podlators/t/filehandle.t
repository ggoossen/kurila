#!/usr/bin/perl -w
#
# filehandle.t -- Test the parse_from_filehandle interface.
#
# Copyright 2006 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

use TestInit

BEGIN
    $^OUTPUT_AUTOFLUSH = 1
    print: $^STDOUT, "1..3\n"


use Pod::Man
use Pod::Text

print: $^STDOUT, "ok 1\n"

my $man = (Pod::Man->new: ) or die: "Cannot create parser\n"
my $text = (Pod::Text->new: ) or die: "Cannot create parser\n"
my $n = 2
while ( ~< $^DATA)
    next until $_ eq "###\n"
    open: my $tmp, ">", 'tmp.pod' or die: "Cannot create tmp.pod: $^OS_ERROR\n"
    while ( ~< $^DATA)
        last if $_ eq "###\n"
        print: $tmp, $_

    close $tmp
    open: my $in, "<", 'tmp.pod' or die: "Cannot open tmp.pod: $^OS_ERROR\n"
    open: my $out, ">", 'out.tmp' or die: "Cannot create out.tmp: $^OS_ERROR\n"
    $man->parse_from_filehandle : $in, $out
    close $in
    close $out
    open: $out, "<", 'out.tmp' or die: "Cannot open out.tmp: $^OS_ERROR\n"
    while ( ~< $out) { last if m/^\.nh/ }
    my $output
    do
        local $^INPUT_RECORD_SEPARATOR = undef
        $output = ~< $out

    close $out
    my $expected = ''
    while ( ~< $^DATA)
        last if $_ eq "###\n"
        $expected .= $_

    if ($output eq $expected)
        print: $^STDOUT, "ok $n\n"
    else
        print: $^STDOUT, "not ok $n\n"
        print: $^STDOUT, "Expected\n========\n$expected\nOutput\n======\n$output\n"

    $n++
    open: $in, "<", 'tmp.pod' or die: "Cannot open tmp.pod: $^OS_ERROR\n"
    open: $out, ">", 'out.tmp' or die: "Cannot create out.tmp: $^OS_ERROR\n"
    $text->parse_from_filehandle : $in, $out
    close $in
    close $out
    open: $out, "<", 'out.tmp' or die: "Cannot open out.tmp: $^OS_ERROR\n"
    do
        local $^INPUT_RECORD_SEPARATOR = undef
        $output = ~< $out

    close $out
    unlink: 'tmp.pod', 'out.tmp'
    $expected = ''
    while ( ~< $^DATA)
        last if $_ eq "###\n"
        $expected .= $_

    if ($output eq $expected)
        print: $^STDOUT, "ok $n\n"
    else
        print: $^STDOUT, "not ok $n\n"
        print: $^STDOUT, "Expected\n========\n$expected\nOutput\n======\n$output\n"

    $n++

# Below the marker are bits of POD, corresponding expected nroff output, and
# corresponding expected text output.  The input and output are separated by
# lines containing only ###.

__DATA__

###
=head1 NAME

gcc - GNU project C and C++ compiler

=head1 C++ NOTES

Other mentions of C++.
###
.SH "NAME"
gcc \- GNU project C and C++ compiler
.SH "\*(C+ NOTES"
.IX Header " NOTES"
Other mentions of \*(C+.
###
NAME
    gcc - GNU project C and C++ compiler

C++ NOTES
    Other mentions of C++.

###
