BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


# Can't use Test.pm, that's a 5.005 thing.
package My::Test

print: $^STDOUT, "1..2\n"

my $test_num = 1
# Utility testing functions.
sub ok($test, ?$name)
    my $ok = ''
    $ok .= "not " unless $test
    $ok .= "ok $test_num"
    $ok .= " - $name" if defined $name
    $ok .= "\n"
    print: $^STDOUT, $ok
    $test_num++



package main

require Test::Simple

require Test::Simple::Catch
my(@: $out, $err) =  (Test::Simple::Catch::caught: )


Test::Simple->import: 'no_plan'

ok: 1, 'foo'


END 
    My::Test::ok: $out->$ eq <<OUT
ok 1 - foo
1..1
OUT

    My::Test::ok: $err->$ eq <<ERR
ERR

    # Prevent Test::Simple from exiting with non zero
    exit 0

