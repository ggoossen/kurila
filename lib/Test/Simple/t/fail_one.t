#!/usr/bin/perl -w

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

    return $test ?? 1 !! 0



package main

require Test::Simple
Test::Simple->import: tests => 1

#line 45
ok: 0

END 
    My::Test::ok: $out->$ eq <<OUT
1..1
not ok 1
OUT

    (My::Test::ok: $err->$ eq <<ERR) || print: $^STDOUT, $err->$
#   Failed test at $^PROGRAM_NAME line 45.
# Looks like you failed 1 test of 1.
ERR

    # Prevent Test::Simple from existing with non-zero
    exit 0

