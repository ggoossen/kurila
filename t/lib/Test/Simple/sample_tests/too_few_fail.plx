require Test::Simple;

push $^INCLUDE_PATH, 't/lib';
require Test::Simple::Catch;
my @: $out, $err = Test::Simple::Catch::caught();

Test::Simple->import(tests => 5);


ok(0);
ok(1);
ok(0);
