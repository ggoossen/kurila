#!/usr/bin/perl -w
#
# man-options.t -- Additional tests for Pod::Man options.
#
# Copyright 2002, 2004, 2006, 2008 Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

use Test::More tests => 1

use Pod::Man

my $n = 2
while (~< $^DATA)
    my %options
    next until $_ eq "###\n"
    while (~< $^DATA)
        last if $_ eq "###\n"
        my @: $option, $value = split
        %options{+$option} = $value

    open (my $tmpfh, '>', 'tmp.pod') or die "Cannot create tmp.pod: $^OS_ERROR\n"
    while (~< $^DATA)
        last if $_ eq "###\n"
        print $tmpfh, $_
    close $tmpfh
    my $parser = Pod::Man->new( < %options) or die "Cannot create parser\n"
    open (my $outfh, '>', 'out.tmp') or die "Cannot create out.tmp: $^OS_ERROR\n"
    $parser->parse_from_file('tmp.pod', $outfh)
    close $outfh
    open ($tmpfh, '<', 'out.tmp') or die "Cannot open out.tmp: $^OS_ERROR\n"
    while (~< $tmpfh) 
        last if m/^\.nh/
    my $output
    do
        local $^INPUT_RECORD_SEPARATOR = undef
        $output = ~< $tmpfh
    close $tmpfh
    unlink ('tmp.pod', 'out.tmp')
    my $expected = ''
    while (~< $^DATA)
        last if $_ eq "###\n"
        $expected .= $_

    ok($output eq $expected)
        or diag "Expected\n========\n$expected\nOutput\n======\n$output\n"
    $n++

# Below the marker are bits of POD and corresponding expected text output.
# This is used to test specific features or problems with Pod::Man.  The
# input and output are separated by lines containing only ###.

__DATA__

###
utf8 1
###
=head1 BEYONCÉ

Beyoncé!  Beyoncé!  Beyoncé!!

    Beyoncé!  Beyoncé!
      Beyoncé!  Beyoncé!
        Beyoncé!  Beyoncé!

Older versions did not convert Beyoncé in verbatim.
###
.SH "BEYONCÉ"
.IX Header "BEYONCÉ"
Beyoncé!  Beyoncé!  Beyoncé!!
.PP
.Vb 3
\&    Beyoncé!  Beyoncé!
\&      Beyoncé!  Beyoncé!
\&        Beyoncé!  Beyoncé!
.Ve
.PP
Older versions did not convert Beyoncé in verbatim.
###
