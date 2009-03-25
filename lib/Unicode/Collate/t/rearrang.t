
BEGIN {
    unless ("A" eq pack('U', 0x41)) {
	print $^STDOUT, "1..0 # Unicode::Collate " .
	    "cannot stringify a Unicode code point\n";
	exit 0;
    }
    if (env::var('PERL_CORE')) {
	chdir('t') if -d 't';
	$^INCLUDE_PATH = @( $^OS_NAME eq 'MacOS' ?? < qw(::lib) !! < qw(../lib) );
    }
}

use Test::More;
BEGIN { plan tests => 23 };

use warnings;
use Unicode::Collate;

ok(1);

#########################

my $Collator = Unicode::Collate->new(
  table => 'keys.txt',
  normalization => undef,
  UCA_Version => 9,
);

# rearrange : 0x0E40..0x0E44, 0x0EC0..0x0EC4 (default)

##### 2..9

my %old_rearrange = %( < $Collator->change(rearrange => undef) );

is($Collator->cmp("\x{0E41}A", "\x{0E40}B"), 1);
is($Collator->cmp("A\x{0E41}A", "A\x{0E40}B"), 1);

$Collator->change(rearrange => \@( 0x61 ));
 # U+0061, 'a': This is a Unicode value, never a native value.

is($Collator->cmp("ab", "AB"), 1); # as 'ba' > 'AB'

$Collator->change(< %old_rearrange);

is($Collator->cmp("ab", "AB"), -1);
is($Collator->cmp("\x{0E40}", "\x{0E41}"), -1);
is($Collator->cmp("\x{0E40}A", "\x{0E41}B"), -1);
is($Collator->cmp("\x{0E41}A", "\x{0E40}B"), -1);
is($Collator->cmp("A\x{0E41}A", "A\x{0E40}B"), -1);

##### 10..13

my $all_undef_8 = Unicode::Collate->new(
  table => undef,
  normalization => undef,
  overrideCJK => undef,
  overrideHangul => undef,
  UCA_Version => 8,
);

is($all_undef_8->cmp("\x{0E40}", "\x{0E41}"), -1);
is($all_undef_8->cmp("\x{0E40}A", "\x{0E41}B"), -1);
is($all_undef_8->cmp("\x{0E41}A", "\x{0E40}B"), -1);
is($all_undef_8->cmp("A\x{0E41}A", "A\x{0E40}B"), -1);

##### 14..18

my $no_rearrange = Unicode::Collate->new(
  table => undef,
  normalization => undef,
  rearrange => \@(),
  UCA_Version => 9,
);

is($no_rearrange->cmp("A", "B"), -1);
is($no_rearrange->cmp("\x{0E40}", "\x{0E41}"), -1);
is($no_rearrange->cmp("\x{0E40}A", "\x{0E41}B"), -1);
is($no_rearrange->cmp("\x{0E41}A", "\x{0E40}B"), 1);
is($no_rearrange->cmp("A\x{0E41}A", "A\x{0E40}B"), 1);

##### 19..23

my $undef_rearrange = Unicode::Collate->new(
  table => undef,
  normalization => undef,
  rearrange => undef,
  UCA_Version => 9,
);

is($undef_rearrange->cmp("A", "B"), -1);
is($undef_rearrange->cmp("\x{0E40}", "\x{0E41}"), -1);
is($undef_rearrange->cmp("\x{0E40}A", "\x{0E41}B"), -1);
is($undef_rearrange->cmp("\x{0E41}A", "\x{0E40}B"), 1);
is($undef_rearrange->cmp("A\x{0E41}A", "A\x{0E40}B"), 1);

