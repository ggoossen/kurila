#! ./perl

BEGIN { require "./test.pl" }

plan tests => 6;

is dump::view('foo'), q|'foo'|;
is dump::view("'foo"), q|"'foo"|;
is dump::view("\nfoo"), q|"\nfoo"|;

is dump::view(*foo), '*main::foo';
is dump::view(15), '15';
{
    local $TODO = "make this dump something useful";
    my $x;
    is dump::view(\$x), "refence";
}

