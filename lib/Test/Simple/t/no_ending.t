use Test::Builder

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


BEGIN 
    my $t = Test::Builder->new
    $t->no_ending: 1


use Test::More tests => 3

# Normally, Test::More would yell that we ran too few tests, but we
# supressed the ending diagnostics.
(pass: )
print: $^STDOUT, "ok 2\n"
print: $^STDOUT, "ok 3\n"
