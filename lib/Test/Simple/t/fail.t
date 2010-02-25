#!perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    



require Test::Simple::Catch
use env
my(@: $out, $err) =  (Test::Simple::Catch::caught: )
local (env::var: 'HARNESS_ACTIVE' ) = 0


# Can't use Test.pm, that's a 5.005 thing.
package My::Test

print: $^STDOUT, "1..2\n"

my $test_num = 1;
# Utility testing functions.
sub ok($test, ?$name)
    my $ok = ''
    $ok .= "not " unless $test
    $ok .= "ok $test_num"
    $ok .= " - $name" if defined $name
    $ok .= "\n"
    print: $^STDOUT, $ok
    $test_num++



package main;

require Test::Simple;
(Test::Simple->import: tests => 5);

#line 35
ok:  1, 'passing' 
ok:  2, 'passing still' 
ok:  3, 'still passing' 
ok:  0, 'oh no!' 
(ok:  0, 'damnit' )


END 
    My::Test::ok: $out->$ eq <<OUT
1..5
ok 1 - passing
ok 2 - passing still
ok 3 - still passing
not ok 4 - oh no!
not ok 5 - damnit
OUT

    My::Test::ok: $err->$ eq <<ERR
#   Failed test 'oh no!'
#   at $^PROGRAM_NAME line 38.
#   Failed test 'damnit'
#   at $^PROGRAM_NAME line 39.
# Looks like you failed 2 tests of 5.
ERR

    # Prevent Test::Simple from exiting with non zero
    exit 0

