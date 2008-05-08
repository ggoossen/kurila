#!/usr/bin/perl -w
# $Id: filehandle.t,v 1.2 2006-09-16 20:25:25 eagle Exp $
#
# filehandle.t -- Test the parse_from_filehandle interface.
#
# Copyright 2006 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

use TestInit;

BEGIN {
    $| = 1;
    print "1..3\n";
}

use Pod::Man;
use Pod::Text;

print "ok 1\n";

my $man = Pod::Man->new or die "Cannot create parser\n";
my $text = Pod::Text->new or die "Cannot create parser\n";
my $n = 2;
while ( ~< *DATA) {
    next until $_ eq "###\n";
    open (TMP, ">", 'tmp.pod') or die "Cannot create tmp.pod: $!\n";
    while ( ~< *DATA) {
        last if $_ eq "###\n";
        print TMP $_;
    }
    close TMP;
    open (IN, "<", 'tmp.pod') or die "Cannot open tmp.pod: $!\n";
    open (OUT, ">", 'out.tmp') or die "Cannot create out.tmp: $!\n";
    $man->parse_from_filehandle (\*IN, \*OUT);
    close IN;
    close OUT;
    open (OUT, "<", 'out.tmp') or die "Cannot open out.tmp: $!\n";
    while ( ~< *OUT) { last if m/^\.nh/ }
    my $output;
    {
        local $/;
        $output = ~< *OUT;
    }
    close OUT;
    my $expected = '';
    while ( ~< *DATA) {
        last if $_ eq "###\n";
        $expected .= $_;
    }
    if ($output eq $expected) {
        print "ok $n\n";
    } else {
        print "not ok $n\n";
        print "Expected\n========\n$expected\nOutput\n======\n$output\n";
    }
    $n++;
    open (IN, "<", 'tmp.pod') or die "Cannot open tmp.pod: $!\n";
    open (OUT, ">", 'out.tmp') or die "Cannot create out.tmp: $!\n";
    $text->parse_from_filehandle (\*IN, \*OUT);
    close IN;
    close OUT;
    open (OUT, "<", 'out.tmp') or die "Cannot open out.tmp: $!\n";
    {
        local $/;
        $output = ~< *OUT;
    }
    close OUT;
    unlink ('tmp.pod', 'out.tmp');
    $expected = '';
    while ( ~< *DATA) {
        last if $_ eq "###\n";
        $expected .= $_;
    }
    if ($output eq $expected) {
        print "ok $n\n";
    } else {
        print "not ok $n\n";
        print "Expected\n========\n$expected\nOutput\n======\n$output\n";
    }
    $n++;
}

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
