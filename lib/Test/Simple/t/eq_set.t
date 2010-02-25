#!perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    

chdir 't'

use Test::More

plan: tests => 3

# RT 3747
ok:  (eq_set: \(@: 1, 2, (@: 3)), \(@: (@: 3), 1, 2)) 
ok:  (eq_set: \(@: 1,2,(@: 3)), \(@: 1,(@: 3),2)) 

:TODO do
    local $TODO = q[eq_set() doesn't really handle references]

    ok:  (eq_set:  \(@: \1, \2, \3), \(@: \2, \3, \1) ) 


