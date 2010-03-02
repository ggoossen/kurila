BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


use Test::More tests => 5

require_ok: 'Test::Builder'
require_ok: "Test::More"
require_ok: "Test::Simple"

do
    package Foo
    use Test::More import => \qw(ok is can_ok)
    can_ok: 'Foo', < qw(ok is can_ok)
    ok:  !(Foo->can: 'like'),  'import working properly' 

