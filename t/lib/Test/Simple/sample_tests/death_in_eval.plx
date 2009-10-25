require Test::Simple;
use Carp;

push: $^INCLUDE_PATH, 't/lib';
require Test::Simple::Catch;
my @: $out, $err = Test::Simple::Catch::caught:

Test::Simple->import: tests => 5

ok: 1
ok: 1
ok: 1
try {
        die: "Foo";
};
ok: 1
eval "die: 'Bar'";
ok: 1

try {
        croak: "Moo";
};
