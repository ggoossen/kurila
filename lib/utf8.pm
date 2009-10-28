package utf8

BEGIN 
    $utf8::hint_bits = 0x01000000
    $bytes::hint_bits = 0x00000008
    $utf8::codepoints_hint_bits = 0x00800000

    $^HINT_BITS ^|^= $utf8::codepoints_hint_bits
    $^HINT_BITS ^&^= ^~^$bytes::hint_bits


our $VERSION = '1.07'

# toggle utf8/codepoints hints
sub import
    $^HINT_BITS ^|^= $utf8::hint_bits
    $^HINT_BITS ^|^= $utf8::codepoints_hint_bits
    $^HINT_BITS ^&^= ^~^$bytes::hint_bits


sub unimport
    $^HINT_BITS ^&^= ^~^$utf8::hint_bits
    $^HINT_BITS ^&^= ^~^$utf8::codepoints_hint_bits


# SWASHNEW
sub SWASHNEW
    require "utf8_heavy.pl"
    return utf8::SWASHNEW_real: < @_


# utf version of string functions

sub length($s)
    BEGIN { (utf8::import: ) }
    return CORE::length: $s


sub substr($strref, @< @_)
    BEGIN { (utf8::import: ) }
    return
        (nelems @_) == 1 ?? (CORE::substr: $strref->$, @_[0]) !!
        (nelems @_) == 2 ?? (CORE::substr: $strref->$, @_[0], @_[1]) !!
        CORE::substr: $strref->$, @_[0], @_[1], @_[2] 


sub ord($s)
    BEGIN { (utf8::import: ) }
    return CORE::ord: $s


sub chr ($s)
    BEGIN { (utf8::import: ) }
    return CORE::chr: $s


sub index($s, @< @_)
    BEGIN { (utf8::import: ) }
    return
        (nelems @_) == 1 ?? (CORE::index: $s, @_[0]) !!
        CORE::index: $s, @_[0], @_[1] 


sub rindex($s, @< @_)
    BEGIN { (utf8::import: ) }
    return
        (nelems @_) == 1 ?? (CORE::rindex: $s, @_[0]) !!
        CORE::rindex: $s, @_[0], @_[1] 


1
__END__

=head1 NAME

utf8 - Perl pragma to enable/disable UTF-8 (or UTF-EBCDIC) in source code

=head1 SYNOPSIS

    use utf8;
    no utf8;

    # Convert a Perl scalar to/from UTF-8.
    $num_octets = utf8::upgrade($string);
    $success    = utf8::downgrade($string[, FAIL_OK]);

    # Change the native bytes of a Perl scalar to/from UTF-8 bytes.
    utf8::encode($string);
    utf8::decode($string);

    $flag = utf8::valid(STRING);

=head1 DESCRIPTION

The C<use utf8> pragma tells the Perl parser to allow UTF-8 in the
program text in the current lexical scope (allow UTF-EBCDIC on EBCDIC based
platforms).  The C<no utf8> pragma tells Perl to switch back to treating
the source text as literal bytes in the current lexical scope.

B<Do not use this pragma for anything else than telling Perl that your
script is written in UTF-8.> The utility functions described below are
directly usable without C<use utf8;>.

Because it is not possible to reliably tell UTF-8 from native 8 bit
encodings, you need either a Byte Order Mark at the beginning of your
source code, or C<use utf8;>, to instruct perl.

When UTF-8 becomes the standard source format, this pragma will
effectively become a no-op.  For convenience in what follows the term
I<UTF-X> is used to refer to UTF-8 on ASCII and ISO Latin based
platforms and UTF-EBCDIC on EBCDIC based platforms.

See also the effects of the C<-C> switch and its cousin, the
C<$ENV{PERL_UNICODE}>, in L<perlrun>.

Enabling the C<utf8> pragma has the following effect:

=over 4

=item *

Bytes in the source text that have their high-bit set will be treated
as being part of a literal UTF-X sequence.  This includes most
literals such as identifier names, string constants, and constant
regular expression patterns.

On EBCDIC platforms characters in the Latin 1 character set are
treated as being part of a literal UTF-EBCDIC character.

=back

Note that if you have bytes with the eighth bit on in your script
(for example embedded Latin-1 in your string literals), C<use utf8>
will be unhappy since the bytes are most probably not well-formed
UTF-X.  If you want to have such bytes under C<use utf8>, you can disable
this pragma until the end the block (or file, if at top level) by
C<no utf8;>.

=head2 Utility functions

The following functions are defined in the C<utf8::> package by the
Perl core.  You do not need to say C<use utf8> to use these and in fact
you should not say that  unless you really want to have UTF-8 source code.

=over 4

=item * $num_octets = utf8::upgrade($string)

Converts in-place the internal octet sequence in the native encoding
(Latin-1 or EBCDIC) to the equivalent character sequence in I<UTF-X>.
I<$string> already encoded as characters does no harm.  Returns the
number of octets necessary to represent the string as I<UTF-X>.  Can be
used to make sure that the UTF-8 flag is on, so that C<\w> or C<lc()>
work as Unicode on strings containing characters in the range 0x80-0xFF
(on ASCII and derivatives).

B<Note that this function does not handle arbitrary encodings.>
Therefore Encode is recommended for the general purposes; see also
L<Encode>.

=item * $success = utf8::downgrade($string[, FAIL_OK])

Converts in-place the internal octet sequence in I<UTF-X> to the
equivalent octet sequence in the native encoding (Latin-1 or EBCDIC).
I<$string> already encoded as native 8 bit does no harm.  Can be used to
make sure that the UTF-8 flag is off, e.g. when you want to make sure
that the substr() or length() function works with the usually faster
byte algorithm.

Fails if the original I<UTF-X> sequence cannot be represented in the
native 8 bit encoding. On failure dies or, if the value of C<FAIL_OK> is
true, returns false. 

Returns true on success.

B<Note that this function does not handle arbitrary encodings.>
Therefore Encode is recommended for the general purposes; see also
L<Encode>.

=item * utf8::encode($string)

Converts in-place the character sequence to the corresponding octet
sequence in I<UTF-X>.  The UTF8 flag is turned off, so that after this
operation, the string is a byte string.  Returns nothing.

B<Note that this function does not handle arbitrary encodings.>
Therefore Encode is recommended for the general purposes; see also
L<Encode>.

=item * $success = utf8::decode($string)

Attempts to convert in-place the octet sequence in I<UTF-X> to the
corresponding character sequence.  The UTF-8 flag is turned on only if
the source string contains multiple-byte I<UTF-X> characters.  If
I<$string> is invalid as I<UTF-X>, returns false; otherwise returns
true.

B<Note that this function does not handle arbitrary encodings.>
Therefore Encode is recommended for the general purposes; see also
L<Encode>.

=item * $flag = utf8::valid(STRING)

[INTERNAL] Will return true if the string is well-formed UTF-8.

=back

C<utf8::encode> is like C<utf8::upgrade>, but the UTF8 flag is
cleared.  See L<perlunicode> for more on the UTF8 flag and the C API
functions C<sv_utf8_encode>,
and C<sv_utf8_decode>, which are wrapped by the Perl functions
C<utf8::encode> and
C<utf8::decode>.  Note that in the Perl 5.8.0 and 5.8.1 implementation
the functions utf8::valid, utf8::encode, utf8::decode,
utf8::upgrade, and utf8::downgrade are always available, without a
C<require utf8> statement-- this may change in future releases.

=head1 BUGS

One can have Unicode in identifier names, but not in package/class or
subroutine names.  While some limited functionality towards this does
exist as of Perl 5.8.0, that is more accidental than designed; use of
Unicode for the said purposes is unsupported.

One reason of this unfinishedness is its (currently) inherent
unportability: since both package names and subroutine names may need
to be mapped to file and directory names, the Unicode capability of
the filesystem becomes important-- and there unfortunately aren't
portable answers.

=head1 SEE ALSO

L<perlunitut>, L<perluniintro>, L<perlrun>, L<bytes>, L<perlunicode>

=cut
