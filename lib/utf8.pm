package utf8;

$utf8::hint_bits = 0x00800000;

our $VERSION = '1.00';

sub import {
    $^H |= $utf8::hint_bits;
    $enc{caller()} = $_[1] if $_[1];
}

sub unimport {
    $^H &= ~$utf8::hint_bits;
}

sub AUTOLOAD {
    require "utf8_heavy.pl";
    goto &$AUTOLOAD if defined &$AUTOLOAD;
    Carp::croak("Undefined subroutine $AUTOLOAD called");
}

1;
__END__

=head1 NAME

utf8 - Perl pragma to enable/disable UTF-8 (or UTF-EBCDIC) in source code

=head1 SYNOPSIS

    use utf8;
    no utf8;

=head1 DESCRIPTION

The C<use utf8> pragma tells the Perl parser to allow UTF-8 in the
program text in the current lexical scope (allow UTF-EBCDIC on EBCDIC based
platforms).  The C<no utf8> pragma tells Perl to switch back to treating 
the source text as literal bytes in the current lexical scope.

This pragma is primarily a compatibility device.  Perl versions
earlier than 5.6 allowed arbitrary bytes in source code, whereas
in future we would like to standardize on the UTF-8 encoding for
source text.  Until UTF-8 becomes the default format for source
text, this pragma should be used to recognize UTF-8 in the source.
When UTF-8 becomes the standard source format, this pragma will
effectively become a no-op.  For convenience in what follows the
term I<UTF-X> is used to refer to UTF-8 on ASCII and ISO Latin based
platforms and UTF-EBCDIC on EBCDIC based platforms.

Enabling the C<utf8> pragma has the following effect:

=over 4

=item *

Bytes in the source text that have their high-bit set will be treated
as being part of a literal UTF-8 character.  This includes most
literals such as identifiers, string constants, constant regular
expression patterns and package names.  On EBCDIC platforms characters
in the Latin 1 character set are treated as being part of a literal
UTF-EBCDIC character.

=back

Note that if you have bytes with the eighth bit on in your script
(for example embedded Latin-1 in your string literals), C<use utf8>
will be unhappy since the bytes are most probably not well-formed
UTF-8.  If you want to have such bytes and use utf8, you can disable
utf8 until the end the block (or file, if at top level) by C<no utf8;>.

=head2 Utility functions

The following functions are defined in the C<utf8::> package by the perl core.

=over 4

=item * $num_octets = utf8::upgrade($string);

Converts internal representation of string to the Perl's internal
I<UTF-X> form.  Returns the number of octets necessary to represent
the string as I<UTF-X>.  Note that this should not be used to convert
a legacy byte encoding to Unicode: use Encode for that.  Affected
by the encoding pragma.

=item * utf8::downgrade($string[, CHECK])

Converts internal representation of string to be un-encoded bytes.
Note that this should not be used to convert Unicode back to a legacy
byte encoding: use Encode for that.  B<Not> affected by the encoding
pragma.

=item * utf8::encode($string)

Converts (in-place) I<$string> from logical characters to octet
sequence representing it in Perl's I<UTF-X> encoding.  Note that this
should not be used to convert a legacy byte encoding to Unicode: use
Encode for that.  =item * $flag = utf8::decode($string)

Attempts to convert I<$string> in-place from Perl's I<UTF-X> encoding
into logical characters.  Note that this should not be used to convert
Unicode back to a legacy byte encoding: use Encode for that.

=back

C<utf8::encode> is like C<utf8::upgrade> but the UTF8 flag does not
get turned on. See L<perlunicode> for more on the UTF8 flag and the C
API functions C<sv_utf8_upgrade>, C<sv_utf8_downgrade>,
C<sv_utf8_encode>, C<sv_utf8_decode> that are wrapped by the Perl
functions C<utf8::upgrade>, C<utf8::downgrade>, C<utf8::encode> and
C<utf8::decode>.

=head1 SEE ALSO

L<perlunicode>, L<bytes>

=cut
