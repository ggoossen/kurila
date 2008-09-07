#!./perl

BEGIN {
    require Config; Config->import;
    require "./test.pl";
}

plan tests => 8;

if (%Config{ebcdic} eq 'define') {
    $_ = join "", map chr($_), 129..233;

    # 105 characters - 52 letters = 53 backslashes
    # 105 characters + 53 backslashes = 158 characters
    $_ = quotemeta $_;
    is(length($_), 158, "quotemeta string");
    # 104 non-backslash characters
    is((nelems @(m/([^\\])/g)), 104, "tr count non-backslashed");
} else { # some ASCII descendant, then.
    $_ = join "", map chr($_), 32..127;

    # 96 characters - 52 letters - 10 digits - 1 underscore = 33 backslashes
    # 96 characters + 33 backslashes = 129 characters
    $_ = quotemeta $_;
    is(length($_), 129, "quotemeta string");
    # 95 non-backslash characters
    is((nelems @(m/([^\\])/g)), 95, "tr count non-backslashed");
}

is(length(quotemeta ""), 0, "quotemeta empty string");

is(quotemeta('{'), '\{', 'quotemeta {');

is("Pe\Q#x#\ErL", "Pe\\#x\\#rL", '\u\LpE\Q#X#\ER\EL');

use utf8;
my $x = "\x{263a}";
is(quotemeta($x), "\x{263a}", "quotemeta Unicode");
no utf8;
is(quotemeta($x), "\\\x[E2]\\\x[98]\\\x[BA]", "quotemeta bytes");

$a = "foo|bar";
is("a\Q\Ec$a", "acfoo|bar", '\Q\E');
