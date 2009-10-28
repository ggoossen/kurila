
package Pod::Simple::XMLOutStream

use utf8
use Carp ()
use Pod::Simple ()
our ($ATTR_PAD, @ISA, $VERSION, $SORT_ATTRS)
$VERSION = '2.02'
BEGIN 
    @ISA = @: 'Pod::Simple'
    *DEBUG = \&Pod::Simple::DEBUG unless exists &DEBUG


$ATTR_PAD = "\n" unless defined $ATTR_PAD
# Don't mess with this unless you know what you're doing.

$SORT_ATTRS = 0 unless defined $SORT_ATTRS

sub new($self, @< @_)
    my $new = $self->SUPER::new: < @_
    $new->{+'output_fh'} ||= $^STDOUT
    #$new->accept_codes('VerbatimFormatted');
    return $new


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

sub _handle_element_start
    # ($self, $element_name, $attr_hash_r)
    my $fh = @_[0]->{?'output_fh'}
    DEBUG: and print: $^STDOUT, "++ @_[1]\n"
    print: $fh, "<", @_[1]
    foreach my $key ((sort: keys @_[2]->%))
        unless($key =~ m/^~/s)
            next if $key eq 'start_line' and @_[0]->{?'hide_line_numbers'}
            my $value = @_[2]->{?$key}
            if (@_[1] eq 'L' and $key =~ m/^(?:section|to)$/)
                $value = $value->as_string: 
            
            $value = _xml_escape: $value
            print: $fh, $ATTR_PAD, $key, '="', $value, '"'
        
    
    print: $fh, ">"
    return


sub _handle_text
    DEBUG: and print: $^STDOUT, "== \"@_[1]\"\n"
    if(length @_[1])
        my $text = @_[1]
        $text = _xml_escape: $text
        print: @_[0]->{?'output_fh'} ,$text
    
    return


sub _handle_element_end($self, $name)
    DEBUG: and print: $^STDOUT, "-- $name\n"
    print: $self->{?'output_fh'} ,"</", $name, ">"
    return


# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

sub _xml_escape($x)
    # Escape things very cautiously:
    $x =~ s/([^-\n\t !\#\$\%\(\)\*\+,\.\~\/\:\;=\?\@\[\\\]\^_\`\{\|\}abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789])/$('&#'.((ord: $1)).';')/g
    # Yes, stipulate the list without a range, so that this can work right on
    #  all charsets that this module happens to run under.
    # Altho, hmm, what about that ord?  Presumably that won't work right
    #  under non-ASCII charsets.  Something should be done about that.
    return $x


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
1

__END__

=head1 NAME

Pod::Simple::XMLOutStream -- turn Pod into XML

=head1 SYNOPSIS

  perl -MPod::Simple::XMLOutStream -e \
   "exit Pod::Simple::XMLOutStream->filter(shift)->any_errata_seen" \
   thingy.pod

=head1 DESCRIPTION

Pod::Simple::XMLOutStream is a subclass of L<Pod::Simple> that parses
Pod and turns it into XML.

Pod::Simple::XMLOutStream inherits methods from
L<Pod::Simple>.


=head1 SEE ALSO

L<Pod::Simple::DumpAsXML> is rather like this class; see its
documentation for a discussion of the differences.

L<Pod::Simple>, L<Pod::Simple::DumpAsXML>, L<Pod::SAX>

L<Pod::Simple::Subclassing>

The older (and possibly obsolete) libraries L<Pod::PXML>, L<Pod::XML>


=head1 ABOUT EXTENDING POD

TODO: An example or two of =extend, then point to Pod::Simple::Subclassing


=head1 ASK ME!

If you actually want to use Pod as a format that you want to render to
XML (particularly if to an XML instance with more elements than normal
Pod has), please email me (C<sburke@cpan.org>) and I'll probably have
some recommendations.

For reasons of concision and energetic laziness, some methods and
options in this module (and the dozen modules it depends on) are
undocumented; but one of those undocumented bits might be just what
you're looking for.


=head1 COPYRIGHT AND DISCLAIMERS

Copyright (c) 2002-4 Sean M. Burke.  All rights reserved.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=head1 AUTHOR

Sean M. Burke C<sburke@cpan.org>

=cut

