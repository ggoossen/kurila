#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


my $test_num = 1
# Utility testing functions.
sub ok($test, $name)
    my $ok = ''
    $ok .= "not " unless $test
    $ok .= "ok $test_num"
    $ok .= " - $name" if defined $name
    $ok .= "\n"
    print: $^STDOUT, $ok
    $test_num++

    return $test



use Test::Builder
my $Test = Test::Builder->new: 

print: $^STDOUT, "1..2\n"

try { ($Test->plan: 7); }
(ok:  $^EVAL_ERROR->{?description} =~ m/^plan\(\) doesn't understand 7/, 'bad plan()' ) ||
    print: $^STDERR, "# $^EVAL_ERROR"

try { ($Test->plan: wibble => 7); }
(ok:  $^EVAL_ERROR->{?description} =~ m/^plan\(\) doesn't understand wibble 7/, 'bad plan()' ) ||
    print: $^STDERR, "# $^EVAL_ERROR"

