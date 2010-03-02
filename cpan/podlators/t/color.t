#!/usr/bin/perl -w
#
# color.t -- Additional specialized tests for Pod::Text::Color.
#
# Copyright 2002, 2004, 2006 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

use TestInit

BEGIN 
    $^OUTPUT_AUTOFLUSH = 1
    print: $^STDOUT, "1..2\n"


try { require Term::ANSIColor }
if ($^EVAL_ERROR)
    for (1..2)
        print: $^STDOUT, "ok $_ # skip\n"
    
    exit

require Pod::Text::Color

print: $^STDOUT, "ok 1\n"

my $parser = Pod::Text::Color->new or die: "Cannot create parser\n"
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
    else
        print: $^STDOUT, "not ok $n\n"
        print: $^STDOUT, "Expected\n========\n$expected\nOutput\n======\n$output\n"
    
    $n++


# Below the marker are bits of POD and corresponding expected output.  This is
# used to test specific features or problems with Pod::Text::Termcap.  The
# input and output are separated by lines containing only ###.

__DATA__

###
=head1 WRAPPING

B<I<Do>> I<B<not>> B<I<include>> B<I<formatting codes when>> B<I<wrapping>>.
###
[1mWRAPPING[0m
    [1m[33mDo[0m[0m [33m[1mnot[0m[0m [1m[33minclude[0m[0m [1m[33mformatting codes when[0m[0m [1m[33mwrapping[0m[0m.

###
