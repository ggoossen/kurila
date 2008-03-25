#! ./perl

BEGIN { require "./test.pl" }

plan tests => 11;

is dump::view('foo'), q|'foo'|;
is dump::view("'foo"), q|"'foo"|;
is dump::view("\nfoo"), q|"\nfoo"|;
is dump::view("\x[01]foo"), q|"\x{01}foo"|, 'string with \x[01] byte';
is dump::view("\x[FF]"), q|"\x[ff]"|, "string with broken UTF-8";

is dump::view(*foo), '*main::foo';
is dump::view(15), '15';
is dump::view(15.55), '15.55';
is dump::view(undef), q|undef|, "undef";
{
    local $TODO = 1;
    is dump::view(qr/foo/), '...', "view regex";
}
like dump::view(\"foobar"), qr/SCALAR[(]0x\w*[)]/;

