#!/usr/bin/perl -w
#
# text-options.t -- Additional tests for Pod::Text options.
#
# Copyright 2002, 2004, 2006 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

use TestInit

BEGIN
    $^OUTPUT_AUTOFLUSH = 1
    print: $^STDOUT, "1..5\n"


use Pod::Text

print: $^STDOUT, "ok 1\n"

my $n = 2
while ( ~< $^DATA)
    my %options
    next until $_ eq "###\n"
    while ( ~< $^DATA)
        last if $_ eq "###\n"
        my (@: $option, $value) =  split: 
        %options{+$option} = $value
    open: my $tmp, ">", 'tmp.pod' or die: "Cannot create tmp.pod: $^OS_ERROR\n"
    while ( ~< $^DATA)
        last if $_ eq "###\n"
        print: $tmp, $_
    close $tmp
    my $parser = (Pod::Text->new : < %options) or die: "Cannot create parser\n"
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

# Below the marker are bits of POD and corresponding expected text output.
# This is used to test specific features or problems with Pod::Text.  The
# input and output are separated by lines containing only ###.

__DATA__

###
alt 1
###
=head1 SAMPLE

=over 4

=item F

Paragraph.

=item Bar

=item B

Paragraph.

=item Longer

Paragraph.

=back

###

==== SAMPLE ====

:   F   Paragraph.

:   Bar
:   B   Paragraph.

:   Longer
        Paragraph.

###

###
margin 4
###
=head1 SAMPLE

This is some body text that is long enough to be a paragraph that wraps,
thereby testing margins with wrapped paragraphs.

 This is some verbatim text.

=over 6

=item Test

This is a test of an indented paragraph.

This is another indented paragraph.

=back
###
    SAMPLE
        This is some body text that is long enough to be a paragraph that
        wraps, thereby testing margins with wrapped paragraphs.

         This is some verbatim text.

        Test  This is a test of an indented paragraph.

              This is another indented paragraph.

###

###
code 1
###
This is some random text.
This is more random text.

This is some random text.
This is more random text.

=head1 SAMPLE

This is POD.

=cut

This is more random text.
###
This is some random text.
This is more random text.

This is some random text.
This is more random text.

SAMPLE
    This is POD.


This is more random text.
###

###
sentence 1
###
=head1 EXAMPLE

Whitespace around C<<  this.  >> must be ignored per perlpodspec.  >>
needs to eat all of the space in front of it.

=cut
###
EXAMPLE
    Whitespace around "this." must be ignored per perlpodspec.  >> needs to
    eat all of the space in front of it.

###
