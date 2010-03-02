BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    



BEGIN { $^OUTPUT_AUTOFLUSH = 1; $^WARNING = 1; }

use Test::Simple tests => 3

ok: 1, 'compile'

ok: 1
ok: 1, 'foo'
