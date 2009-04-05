
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
BEGIN { plan tests => 17 };

use warnings;
use Unicode::Collate;

ok(1);

#########################

# Fix me when UCA and/or keys.txt is upgraded.
my $UCA_Version = "14";
my $Base_Unicode_Version = "4.1.0";
my $Key_Version = "3.1.1";

is(Unicode::Collate::UCA_Version, $UCA_Version);
is(Unicode::Collate->UCA_Version, $UCA_Version);
is(Unicode::Collate::Base_Unicode_Version, $Base_Unicode_Version);
is(Unicode::Collate->Base_Unicode_Version, $Base_Unicode_Version);

my $Collator = Unicode::Collate->new(
  table => 'keys.txt',
  normalization => undef,
);

is($Collator->UCA_Version,   $UCA_Version);
is($Collator->UCA_Version(), $UCA_Version);
is($Collator->Base_Unicode_Version,   $Base_Unicode_Version);
is($Collator->Base_Unicode_Version(), $Base_Unicode_Version);
is($Collator->version,   $Key_Version);
is($Collator->version(), $Key_Version);

my $UndefTable = Unicode::Collate->new(
  table => undef,
  normalization => undef,
);

is($UndefTable->UCA_Version,   $UCA_Version);
is($UndefTable->UCA_Version(), $UCA_Version);
is($UndefTable->Base_Unicode_Version,   $Base_Unicode_Version);
is($UndefTable->Base_Unicode_Version(), $Base_Unicode_Version);
is($UndefTable->version,   "unknown");
is($UndefTable->version(), "unknown");

