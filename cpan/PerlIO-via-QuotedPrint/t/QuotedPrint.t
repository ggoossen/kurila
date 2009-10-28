BEGIN                           # Magic Perl CORE pragma
    unless ((PerlIO::Layer->find:  'perlio'))
        print: $^STDOUT, "1..0 # Skip: PerlIO not used\n"
        exit 0
    require Config
    if (((Config::config_value: 'extensions') !~ m!\bPerlIO/via\b!) )
        print: $^STDOUT, "1..0 # Skip -- Perl configured without PerlIO::via module\n"
        exit 0

use warnings
use Test::More tests => 11

BEGIN use_ok: 'PerlIO::via::QuotedPrint'

my $file = 'test.qp'

my $decoded = <<EOD
This is a tést for quoted-printable text that has hàrdly any speçial characters
in it.
EOD

my $encoded = <<EOD
This is a t=E9st for quoted-printable text that has h=E0rdly any spe=E7ial =
characters
in it.
EOD

# Create the encoded test-file

ok: 
 (open:  my $out,'>:via(PerlIO::via::QuotedPrint)', $file )
 "opening '$file' for writing"
 

ok:  ((print: $out, $decoded)),              'print to file' 
ok:  (close:  $out ),                      'closing encoding handle' 

# Check encoding without layers

do
    local $^INPUT_RECORD_SEPARATOR = undef
    ok:  (open:  my $test, "<",$file ),            'opening without layer' 
    is:  $encoded,(readline:  $test ,             'check encoded content' 
    ok:  (close:  $test ),                 'close test handle' 

# Check decoding _with_ layers

ok: 
 (open:  my $in,'<:via(QuotedPrint)', $file )
 "opening '$file' for reading"
 
is:  $decoded, (join:  '', @: ~< $in ),                'check decoding' 
ok:  (close:  $in ),                       'close decoding handle' 

# Remove whatever we created now

ok:  (unlink:  $file ),                    "remove test file '$file'" 
