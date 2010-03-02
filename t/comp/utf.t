#!./perl

use Config;

BEGIN
    unless ('PerlIO::Layer'->find: 'perlio')
        print: $^STDOUT, "1..0 # Skip: not perlio\n"
        exit 0
    if (env::var: 'PERL_CORE_MINITEST')
        print: $^STDOUT, "1..0 # Skip: no dynamic loading on miniperl, no threads\n"
        exit 0
    if ((config_value: 'extensions') !~ m/\bEncode\b/)
      print: $^STDOUT, "1..0 # Skip: Encode was not built\n"
      exit 0

BEGIN { require "./test.pl"; }

plan(tests => 18);

my $BOM = "\x[FEFF]";

sub test {
    my ($enc, $tag, $bom) = @_;
  SKIP: {
    skip "Only utf8 support", 1 if $enc ne "utf8" or $bom;
    open(UTF_PL, ">:raw:encoding($enc)", "utf.pl")
        or die "utf.pl($enc,$tag,$bom): $!";
    print UTF_PL $BOM if $bom;
    print UTF_PL "$tag\n";
    print UTF_PL $BOM if $bom;
    close(UTF_PL);
    my $got = do "./utf$$.pl";
    is($got, $tag);
  }
}

test("utf16le",    123,   1);
test("utf16le",    1234,  1);
test("utf16le",    12345, 1);
test("utf16be",    123,   1);
test("utf16be",    1234,  1);
test("utf16be",    12345, 1);
test("utf8",       123,   1);
test("utf8",       1234,  1);
test("utf8",       12345, 1);

test("utf16le",    123,   0);
test("utf16le",    1234,  0);
test("utf16le",    12345, 0);
test("utf16be",    123,   0);
test("utf16be",    1234,  0);
test("utf16be",    12345, 0);
test("utf8",       123,   0);
test("utf8",       1234,  0);
test("utf8",       12345, 0);

END {
    1 while unlink "utf$$.pl";
}
