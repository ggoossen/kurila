#
# $Id: GSM0338.pm,v 2.0 2007/04/22 14:54:22 dankogai Exp $
#
package Encode::GSM0338;

use strict;
use warnings;
use Carp;

use vars qw($VERSION);
$VERSION = do { my @r = ( q$Revision: 2.0 $ =~ m/\d+/g ); sprintf "%d." . "%02d" x $#r, @r };

use Encode qw(:fallbacks);

use base qw(Encode::Encoding);
__PACKAGE__->Define('gsm0338');

sub needs_lines { 1 }
sub perlio_ok   { 0 }

use utf8;
our %UNI2GSM = (
    "\x{0040}" => "\x[00]",        # COMMERCIAL AT
    "\x{000A}" => "\x[0A]",        # LINE FEED
    "\x{000C}" => "\x[1B0A]",    # FORM FEED
    "\x{000D}" => "\x[0D]",        # CARRIAGE RETURN
    "\x{0020}" => "\x[20]",        # SPACE
    "\x{0021}" => "\x[21]",        # EXCLAMATION MARK
    "\x{0022}" => "\x[22]",        # QUOTATION MARK
    "\x{0023}" => "\x[23]",        # NUMBER SIGN
    "\x{0024}" => "\x[02]",        # DOLLAR SIGN
    "\x{0025}" => "\x[25]",        # PERCENT SIGN
    "\x{0026}" => "\x[26]",        # AMPERSAND
    "\x{0027}" => "\x[27]",        # APOSTROPHE
    "\x{0028}" => "\x[28]",        # LEFT PARENTHESIS
    "\x{0029}" => "\x[29]",        # RIGHT PARENTHESIS
    "\x{002A}" => "\x[2A]",        # ASTERISK
    "\x{002B}" => "\x[2B]",        # PLUS SIGN
    "\x{002C}" => "\x[2C]",        # COMMA
    "\x{002D}" => "\x[2D]",        # HYPHEN-MINUS
    "\x{002E}" => "\x[2E]",        # FULL STOP
    "\x{002F}" => "\x[2F]",        # SOLIDUS
    "\x{0030}" => "\x[30]",        # DIGIT ZERO
    "\x{0031}" => "\x[31]",        # DIGIT ONE
    "\x{0032}" => "\x[32]",        # DIGIT TWO
    "\x{0033}" => "\x[33]",        # DIGIT THREE
    "\x{0034}" => "\x[34]",        # DIGIT FOUR
    "\x{0035}" => "\x[35]",        # DIGIT FIVE
    "\x{0036}" => "\x[36]",        # DIGIT SIX
    "\x{0037}" => "\x[37]",        # DIGIT SEVEN
    "\x{0038}" => "\x[38]",        # DIGIT EIGHT
    "\x{0039}" => "\x[39]",        # DIGIT NINE
    "\x{003A}" => "\x[3A]",        # COLON
    "\x{003B}" => "\x[3B]",        # SEMICOLON
    "\x{003C}" => "\x[3C]",        # LESS-THAN SIGN
    "\x{003D}" => "\x[3D]",        # EQUALS SIGN
    "\x{003E}" => "\x[3E]",        # GREATER-THAN SIGN
    "\x{003F}" => "\x[3F]",        # QUESTION MARK
    "\x{0041}" => "\x[41]",        # LATIN CAPITAL LETTER A
    "\x{0042}" => "\x[42]",        # LATIN CAPITAL LETTER B
    "\x{0043}" => "\x[43]",        # LATIN CAPITAL LETTER C
    "\x{0044}" => "\x[44]",        # LATIN CAPITAL LETTER D
    "\x{0045}" => "\x[45]",        # LATIN CAPITAL LETTER E
    "\x{0046}" => "\x[46]",        # LATIN CAPITAL LETTER F
    "\x{0047}" => "\x[47]",        # LATIN CAPITAL LETTER G
    "\x{0048}" => "\x[48]",        # LATIN CAPITAL LETTER H
    "\x{0049}" => "\x[49]",        # LATIN CAPITAL LETTER I
    "\x{004A}" => "\x[4A]",        # LATIN CAPITAL LETTER J
    "\x{004B}" => "\x[4B]",        # LATIN CAPITAL LETTER K
    "\x{004C}" => "\x[4C]",        # LATIN CAPITAL LETTER L
    "\x{004D}" => "\x[4D]",        # LATIN CAPITAL LETTER M
    "\x{004E}" => "\x[4E]",        # LATIN CAPITAL LETTER N
    "\x{004F}" => "\x[4F]",        # LATIN CAPITAL LETTER O
    "\x{0050}" => "\x[50]",        # LATIN CAPITAL LETTER P
    "\x{0051}" => "\x[51]",        # LATIN CAPITAL LETTER Q
    "\x{0052}" => "\x[52]",        # LATIN CAPITAL LETTER R
    "\x{0053}" => "\x[53]",        # LATIN CAPITAL LETTER S
    "\x{0054}" => "\x[54]",        # LATIN CAPITAL LETTER T
    "\x{0055}" => "\x[55]",        # LATIN CAPITAL LETTER U
    "\x{0056}" => "\x[56]",        # LATIN CAPITAL LETTER V
    "\x{0057}" => "\x[57]",        # LATIN CAPITAL LETTER W
    "\x{0058}" => "\x[58]",        # LATIN CAPITAL LETTER X
    "\x{0059}" => "\x[59]",        # LATIN CAPITAL LETTER Y
    "\x{005A}" => "\x[5A]",        # LATIN CAPITAL LETTER Z
    "\x{005F}" => "\x[11]",        # LOW LINE
    "\x{0061}" => "\x[61]",        # LATIN SMALL LETTER A
    "\x{0062}" => "\x[62]",        # LATIN SMALL LETTER B
    "\x{0063}" => "\x[63]",        # LATIN SMALL LETTER C
    "\x{0064}" => "\x[64]",        # LATIN SMALL LETTER D
    "\x{0065}" => "\x[65]",        # LATIN SMALL LETTER E
    "\x{0066}" => "\x[66]",        # LATIN SMALL LETTER F
    "\x{0067}" => "\x[67]",        # LATIN SMALL LETTER G
    "\x{0068}" => "\x[68]",        # LATIN SMALL LETTER H
    "\x{0069}" => "\x[69]",        # LATIN SMALL LETTER I
    "\x{006A}" => "\x[6A]",        # LATIN SMALL LETTER J
    "\x{006B}" => "\x[6B]",        # LATIN SMALL LETTER K
    "\x{006C}" => "\x[6C]",        # LATIN SMALL LETTER L
    "\x{006D}" => "\x[6D]",        # LATIN SMALL LETTER M
    "\x{006E}" => "\x[6E]",        # LATIN SMALL LETTER N
    "\x{006F}" => "\x[6F]",        # LATIN SMALL LETTER O
    "\x{0070}" => "\x[70]",        # LATIN SMALL LETTER P
    "\x{0071}" => "\x[71]",        # LATIN SMALL LETTER Q
    "\x{0072}" => "\x[72]",        # LATIN SMALL LETTER R
    "\x{0073}" => "\x[73]",        # LATIN SMALL LETTER S
    "\x{0074}" => "\x[74]",        # LATIN SMALL LETTER T
    "\x{0075}" => "\x[75]",        # LATIN SMALL LETTER U
    "\x{0076}" => "\x[76]",        # LATIN SMALL LETTER V
    "\x{0077}" => "\x[77]",        # LATIN SMALL LETTER W
    "\x{0078}" => "\x[78]",        # LATIN SMALL LETTER X
    "\x{0079}" => "\x[79]",        # LATIN SMALL LETTER Y
    "\x{007A}" => "\x[7A]",        # LATIN SMALL LETTER Z
    "\x{000C}" => "\x[1B0A]",    # FORM FEED
    "\x{005B}" => "\x[1B3C]",    # LEFT SQUARE BRACKET
    "\x{005C}" => "\x[1B2F]",    # REVERSE SOLIDUS
    "\x{005D}" => "\x[1B3E]",    # RIGHT SQUARE BRACKET
    "\x{005E}" => "\x[1B14]",    # CIRCUMFLEX ACCENT
    "\x{007B}" => "\x[1B28]",    # LEFT CURLY BRACKET
    "\x{007C}" => "\x[1B40]",    # VERTICAL LINE
    "\x{007D}" => "\x[1B29]",    # RIGHT CURLY BRACKET
    "\x{007E}" => "\x[1B3D]",    # TILDE
    "\x{00A0}" => "\x[1B]",        # NO-BREAK SPACE
    "\x{00A1}" => "\x[40]",        # INVERTED EXCLAMATION MARK
    "\x{00A3}" => "\x[01]",        # POUND SIGN
    "\x{00A4}" => "\x[24]",        # CURRENCY SIGN
    "\x{00A5}" => "\x[03]",        # YEN SIGN
    "\x{00A7}" => "\x[5F]",        # SECTION SIGN
    "\x{00BF}" => "\x[60]",        # INVERTED QUESTION MARK
    "\x{00C4}" => "\x[5B]",        # LATIN CAPITAL LETTER A WITH DIAERESIS
    "\x{00C5}" => "\x[0E]",        # LATIN CAPITAL LETTER A WITH RING ABOVE
    "\x{00C6}" => "\x[1C]",        # LATIN CAPITAL LETTER AE
    "\x{00C9}" => "\x[1F]",        # LATIN CAPITAL LETTER E WITH ACUTE
    "\x{00D1}" => "\x[5D]",        # LATIN CAPITAL LETTER N WITH TILDE
    "\x{00D6}" => "\x[5C]",        # LATIN CAPITAL LETTER O WITH DIAERESIS
    "\x{00D8}" => "\x[0B]",        # LATIN CAPITAL LETTER O WITH STROKE
    "\x{00DC}" => "\x[5E]",        # LATIN CAPITAL LETTER U WITH DIAERESIS
    "\x{00DF}" => "\x[1E]",        # LATIN SMALL LETTER SHARP S
    "\x{00E0}" => "\x[7F]",        # LATIN SMALL LETTER A WITH GRAVE
    "\x{00E4}" => "\x[7B]",        # LATIN SMALL LETTER A WITH DIAERESIS
    "\x{00E5}" => "\x[0F]",        # LATIN SMALL LETTER A WITH RING ABOVE
    "\x{00E6}" => "\x[1D]",        # LATIN SMALL LETTER AE
    "\x{00E7}" => "\x[09]",        # LATIN SMALL LETTER C WITH CEDILLA
    "\x{00E8}" => "\x[04]",        # LATIN SMALL LETTER E WITH GRAVE
    "\x{00E9}" => "\x[05]",        # LATIN SMALL LETTER E WITH ACUTE
    "\x{00EC}" => "\x[07]",        # LATIN SMALL LETTER I WITH GRAVE
    "\x{00F1}" => "\x[7D]",        # LATIN SMALL LETTER N WITH TILDE
    "\x{00F2}" => "\x[08]",        # LATIN SMALL LETTER O WITH GRAVE
    "\x{00F6}" => "\x[7C]",        # LATIN SMALL LETTER O WITH DIAERESIS
    "\x{00F8}" => "\x[0C]",        # LATIN SMALL LETTER O WITH STROKE
    "\x{00F9}" => "\x[06]",        # LATIN SMALL LETTER U WITH GRAVE
    "\x{00FC}" => "\x[7E]",        # LATIN SMALL LETTER U WITH DIAERESIS
    "\x{0393}" => "\x[13]",        # GREEK CAPITAL LETTER GAMMA
    "\x{0394}" => "\x[10]",        # GREEK CAPITAL LETTER DELTA
    "\x{0398}" => "\x[19]",        # GREEK CAPITAL LETTER THETA
    "\x{039B}" => "\x[14]",        # GREEK CAPITAL LETTER LAMDA
    "\x{039E}" => "\x[1A]",        # GREEK CAPITAL LETTER XI
    "\x{03A0}" => "\x[16]",        # GREEK CAPITAL LETTER PI
    "\x{03A3}" => "\x[18]",        # GREEK CAPITAL LETTER SIGMA
    "\x{03A6}" => "\x[12]",        # GREEK CAPITAL LETTER PHI
    "\x{03A8}" => "\x[17]",        # GREEK CAPITAL LETTER PSI
    "\x{03A9}" => "\x[15]",        # GREEK CAPITAL LETTER OMEGA
    "\x{20AC}" => "\x[1B65]",    # EURO SIGN
);
our %GSM2UNI = reverse %UNI2GSM;
our $ESC    = "\x[1b]";
our $ATMARK = "\x[40]";
our $FBCHAR = "\x[3F]";
our $NBSP   = "\x{00A0}";

#define ERR_DECODE_NOMAP "%s \"\\x%02" UVXf "\" does not map to Unicode"

sub decode ($$;$) {
    my ( $obj, $bytes, $chk ) = @_;
    my $str;
    while ( length $bytes ) {
        my $c = substr( $bytes, 0, 1, '' );
        my $u;
        if ( $c eq "\x[00]" ) {
            my $c2 = substr( $bytes, 0, 1, '' );
            $u =
                !length $c2 ? $ATMARK
              : $c2 eq "\x[00]" ? "\x{0000}"
              : exists $GSM2UNI{$c2} ? $ATMARK . $GSM2UNI{$c2}
              : $chk
              ? croak sprintf( "\\x%02X\\x%02X does not map to Unicode",
			       ord($c), ord($c2) )
              : $ATMARK . $FBCHAR;

        }
        elsif ( $c eq $ESC ) {
            my $c2 = substr( $bytes, 0, 1, '' );
            $u =
                exists $GSM2UNI{ $c . $c2 } ? $GSM2UNI{ $c . $c2 }
              : exists $GSM2UNI{$c2}        ? $NBSP . $GSM2UNI{$c2}
              : $chk
              ? croak sprintf( "\\x%02X\\x%02X does not map to Unicode",
			       ord($c), ord($c2) )
              : $NBSP . $FBCHAR;
        }
        else {
            $u =
              exists $GSM2UNI{$c} ? $GSM2UNI{$c}
              : $chk
              ? croak sprintf( "\\x%02X does not map to Unicode", ord($c) )
              : $FBCHAR;
        }
        $str .= $u;
    }
    $_[1] = $bytes if $chk;
    return $str;
}

#define ERR_ENCODE_NOMAP "\"\\x{%04" UVxf "}\" does not map to %s"

sub encode($$;$) {
    my ( $obj, $str, $chk ) = @_;
    my $bytes;
    while ( length $str ) {
        my $u = substr( $str, 0, 1, '' );
        my $c;
        $bytes .=
          exists $UNI2GSM{$u} ? $UNI2GSM{$u}
          : $chk
          ? croak sprintf( "\\x\{%04x\} does not map to %s", 
			   ord($u), $obj->name )
          : $FBCHAR;
    }
    $_[1] = $str if $chk;
    return $bytes;
}

1;
__END__

=head1 NAME

Encode::GSM0338 -- ESTI GSM 03.38 Encoding

=head1 SYNOPSIS

  use Encode qw/encode decode/; 
  $gsm0338 = encode("gsm0338", $utf8);    # loads Encode::GSM0338 implicitly
  $utf8    = decode("gsm0338", $gsm0338); # ditto

=head1 DESCRIPTION

GSM0338 is for GSM handsets. Though it shares alphanumerals with ASCII,
control character ranges and other parts are mapped very differently,
mainly to store Greek characters.  There are also escape sequences
(starting with 0x1B) to cover e.g. the Euro sign.

This was once handled by L<Encode::Bytes> but because of all those
unusual specifications, Encode 2.20 has relocated the support to
this module.

=head1 NOTES

Unlike most other encodings,  the following aways croaks on error
for any $chk that evaluates to true.

  $gsm0338 = encode("gsm0338", $utf8      $chk);
  $utf8    = decode("gsm0338", $gsm0338,  $chk);

So if you want to check the validity of the encoding, surround the
expression with C<eval {}> block as follows;

  eval {
    $utf8    = decode("gsm0338", $gsm0338,  $chk);
  };
  if ($@){
    # handle exception here
  }

=head1 BUGS

ESTI GSM 03.38 Encoding itself.

Mapping \x00 to '@' causes too much pain everywhere.

Its use of \x1b (escape) is also very questionable.  

Because of those two, the code paging approach used use in ucm-based
Encoding SOMETIMES fails so this module was written.

=head1 SEE ALSO

L<Encode>

=cut
