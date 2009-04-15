
use Test::More;
BEGIN { plan tests => 53 };

use warnings;
use Unicode::Collate;

#########################

ok(1);

my $Collator = Unicode::Collate->new(
  table => 'keys.txt',
  normalization => undef,
);

##############

is($Collator->viewSortKey(""), "[| | |]");

is($Collator->viewSortKey("A"), "[0A15 | 0020 | 0008 | FFFF]");

is($Collator->viewSortKey("ABC"),
    "[0A15 0A29 0A3D | 0020 0020 0020 | 0008 0008 0008 | FFFF FFFF FFFF]");

is($Collator->viewSortKey("(12)"),
    "[0A0C 0A0D | 0020 0020 | 0002 0002 | 027A FFFF FFFF 027B]");

is($Collator->viewSortKey("!\x{300}"), "[| | | 024B]");

is($Collator->viewSortKey("\x{300}"), "[| 0035 | 0002 | FFFF]");

$Collator->change(level => 3);
is($Collator->viewSortKey("A"), "[0A15 | 0020 | 0008 |]");

$Collator->change(level => 2);
is($Collator->viewSortKey("A"), "[0A15 | 0020 | |]");

$Collator->change(level => 1);
is($Collator->viewSortKey("A"), "[0A15 | | |]");

### Version 8

$Collator->change(level => 4, UCA_Version => 8);

is($Collator->viewSortKey(""), "[|||]");

is($Collator->viewSortKey("A"), "[0A15|0020|0008|FFFF]");

is($Collator->viewSortKey("ABC"),
    "[0A15 0A29 0A3D|0020 0020 0020|0008 0008 0008|FFFF FFFF FFFF]");

is($Collator->viewSortKey("(12)"),
    "[0A0C 0A0D|0020 0020|0002 0002|027A FFFF FFFF 027B]");

is($Collator->viewSortKey("!\x{300}"), "[|0035|0002|024B FFFF]");

is($Collator->viewSortKey("\x{300}"), "[|0035|0002|FFFF]");

$Collator->change(level => 3);
is($Collator->viewSortKey("A"), "[0A15|0020|0008|]");

$Collator->change(level => 2);
is($Collator->viewSortKey("A"), "[0A15|0020||]");

$Collator->change(level => 1);
is($Collator->viewSortKey("A"), "[0A15|||]");

# Version 9

$Collator->change(level => 3, UCA_Version => 9);
is($Collator->viewSortKey("A\x{300}z\x{301}"),
    "[0A15 0C13 | 0020 0035 0020 0032 | 0008 0002 0002 0002 |]");

$Collator->change(backwards => 1);
is($Collator->viewSortKey("A\x{300}z\x{301}"),
    "[0C13 0A15 | 0020 0035 0020 0032 | 0008 0002 0002 0002 |]");

$Collator->change(backwards => 2);
is($Collator->viewSortKey("A\x{300}z\x{301}"),
    "[0A15 0C13 | 0032 0020 0035 0020 | 0008 0002 0002 0002 |]");

$Collator->change(backwards => \@(1,3));
is($Collator->viewSortKey("A\x{300}z\x{301}"),
    "[0C13 0A15 | 0020 0035 0020 0032 | 0002 0002 0002 0008 |]");

$Collator->change(backwards => \@(2));
is($Collator->viewSortKey("\x{300}\x{301}\x{302}\x{303}"),
    "[| 004E 003C 0032 0035 | 0002 0002 0002 0002 |]");

$Collator->change(backwards => \@());
is($Collator->viewSortKey("A\x{300}z\x{301}"),
    "[0A15 0C13 | 0020 0035 0020 0032 | 0008 0002 0002 0002 |]");

$Collator->change(level => 4);

# Variable

our %origVar = %( < $Collator->change(variable => 'Blanked') );
is($Collator->viewSortKey("1+2"),
    '[0A0C 0A0D | 0020 0020 | 0002 0002 | 0031 002B 0032]');

is($Collator->viewSortKey("?\x{300}!\x{301}\x{315}."),
    '[| | | 003F 0021 002E]');

is($Collator->viewSortKey("?!."), '[| | | 003F 0021 002E]');

$Collator->change(variable => 'Non-ignorable');
is($Collator->viewSortKey("1+2"),
    '[0A0C 039F 0A0D | 0020 0020 0020 | 0002 0002 0002 | 0031 002B 0032]');

is($Collator->viewSortKey("?\x{300}!"),
    '[024E 024B | 0020 0035 0020 | 0002 0002 0002 | 003F 0300 0021]');

is($Collator->viewSortKey("?!."),
    '[024E 024B 0255 | 0020 0020 0020 | 0002 0002 0002 | 003F 0021 002E]');

$Collator->change(variable => 'Shifted');
is($Collator->viewSortKey("1+2"),
    '[0A0C 0A0D | 0020 0020 | 0002 0002 | FFFF 039F FFFF]');

is($Collator->viewSortKey("?\x{300}!\x{301}\x{315}."),
    '[| | | 024E 024B 0255]');

is($Collator->viewSortKey("?!."), '[| | | 024E 024B 0255]');

$Collator->change(variable => 'Shift-Trimmed');
is($Collator->viewSortKey("1+2"),
    '[0A0C 0A0D | 0020 0020 | 0002 0002 | 039F]');

is($Collator->viewSortKey("?\x{300}!\x{301}\x{315}."),
    '[| | | 024E 024B 0255]');

is($Collator->viewSortKey("?!."), '[| | | 024E 024B 0255]');

$Collator->change(< %origVar);

#####

# Level 3 weight

is($Collator->viewSortKey("a\x{3042}"),
    '[0A15 1921 | 0020 0020 | 0002 000E | FFFF FFFF]');

is($Collator->viewSortKey("A\x{30A2}"),
    '[0A15 1921 | 0020 0020 | 0008 0011 | FFFF FFFF]');

$Collator->change(upper_before_lower => 1);

is($Collator->viewSortKey("a\x{3042}"),
    '[0A15 1921 | 0020 0020 | 0008 000E | FFFF FFFF]');

is($Collator->viewSortKey("A\x{30A2}"),
    '[0A15 1921 | 0020 0020 | 0002 0011 | FFFF FFFF]');

$Collator->change(katakana_before_hiragana => 1);

is($Collator->viewSortKey("a\x{3042}"),
    '[0A15 1921 | 0020 0020 | 0008 0013 | FFFF FFFF]');
is($Collator->viewSortKey("A\x{30A2}"),
    '[0A15 1921 | 0020 0020 | 0002 000F | FFFF FFFF]');

$Collator->change(upper_before_lower => 0);

is($Collator->viewSortKey("a\x{3042}"),
    '[0A15 1921 | 0020 0020 | 0002 0013 | FFFF FFFF]');

is($Collator->viewSortKey("A\x{30A2}"),
    '[0A15 1921 | 0020 0020 | 0008 000F | FFFF FFFF]');

$Collator->change(katakana_before_hiragana => 0);

is($Collator->viewSortKey("a\x{3042}"),
    '[0A15 1921 | 0020 0020 | 0002 000E | FFFF FFFF]');

is($Collator->viewSortKey("A\x{30A2}"),
    '[0A15 1921 | 0020 0020 | 0008 0011 | FFFF FFFF]');

#####

our $el = Unicode::Collate->new(
  entry => <<'ENTRY',
006C ; [.0B03.0020.0002.006C] # LATIN SMALL LETTER L
FF4C ; [.0B03.0020.0003.FF4C] # FULLWIDTH LATIN SMALL LETTER L; QQK
217C ; [.0B03.0020.0004.217C] # SMALL ROMAN NUMERAL FIFTY; QQK
2113 ; [.0B03.0020.0005.2113] # SCRIPT SMALL L; QQK
24DB ; [.0B03.0020.0006.24DB] # CIRCLED LATIN SMALL LETTER L; QQK
004C ; [.0B03.0020.0008.004C] # LATIN CAPITAL LETTER L
FF2C ; [.0B03.0020.0009.FF2C] # FULLWIDTH LATIN CAPITAL LETTER L; QQK
216C ; [.0B03.0020.000A.216C] # ROMAN NUMERAL FIFTY; QQK
2112 ; [.0B03.0020.000B.2112] # SCRIPT CAPITAL L; QQK
24C1 ; [.0B03.0020.000C.24C1] # CIRCLED LATIN CAPITAL LETTER L; QQK
ENTRY
  table => undef,
  normalization => undef,
);

our $el12 = '0B03 0B03 0B03 0B03 0B03 | 0020 0020 0020 0020 0020';

is($el->viewSortKey("l\x{FF4C}\x{217C}\x{2113}\x{24DB}"),
    "[$el12 | 0002 0003 0004 0005 0006 | FFFF FFFF FFFF FFFF FFFF]");

is($el->viewSortKey("L\x{FF2C}\x{216C}\x{2112}\x{24C1}"),
    "[$el12 | 0008 0009 000A 000B 000C | FFFF FFFF FFFF FFFF FFFF]");

$el->change(upper_before_lower => 1);

is($el->viewSortKey("l\x{FF4C}\x{217C}\x{2113}\x{24DB}"),
    "[$el12 | 0008 0009 000A 000B 000C | FFFF FFFF FFFF FFFF FFFF]");

is($el->viewSortKey("L\x{FF2C}\x{216C}\x{2112}\x{24C1}"),
    "[$el12 | 0002 0003 0004 0005 0006 | FFFF FFFF FFFF FFFF FFFF]");

$el->change(upper_before_lower => 0);

is($el->viewSortKey("l\x{FF4C}\x{217C}\x{2113}\x{24DB}"),
    "[$el12 | 0002 0003 0004 0005 0006 | FFFF FFFF FFFF FFFF FFFF]");

is($el->viewSortKey("L\x{FF2C}\x{216C}\x{2112}\x{24C1}"),
    "[$el12 | 0008 0009 000A 000B 000C | FFFF FFFF FFFF FFFF FFFF]");

#####

