BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


use Test::More

plan: skip_all => 'Just testing plan & skip_all'

fail: 'We should never get here'
