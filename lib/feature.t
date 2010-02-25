#!./perl

BEGIN 
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @:  '../lib' 
    (env::var: 'PERL5LIB' ) = '../lib'


our $pragma_name = "feature"
require "../t/lib/common.pl"
