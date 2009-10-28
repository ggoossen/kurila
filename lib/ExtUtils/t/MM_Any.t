#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @:  '../lib' 
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    

chdir 't'

use Test::More tests => 7
BEGIN { (use_ok: 'ExtUtils::MM') }


### OS Flavor methods

can_ok:  'MM', 'os_flavor', 'os_flavor_is' 

# Can't really know what the flavors are going to be, so we just
# make sure it returns something.
my @flavors = MM->os_flavor: 
ok:  (nelems @flavors),   'os_flavor() returned something' 

ok:  (MM->os_flavor_is: @flavors[rand nelems @flavors])
     'os_flavor_is() one flavor' 
ok:  (MM->os_flavor_is: @flavors[rand nelems @flavors], 'BogusOS')
     '    many flavors' 
ok:  !(MM->os_flavor_is: 'BogusOS'),        '    wrong flavor' 
ok:  !(MM->os_flavor_is: ),                 '    no flavor' 

