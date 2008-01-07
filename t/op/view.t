#! ./perl

BEGIN { require "./test.pl" }

plan tests => 10;

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
    local $TODO = "make this dump something useful";
    my $x;
    is dump::view(\$x), "refence";
}

