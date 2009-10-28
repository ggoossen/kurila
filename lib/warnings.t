#!./perl

BEGIN 
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @:  '../lib' 
    (env::var: 'PERL5LIB' ) = '../lib'


our $pragma_name = "warnings"
our $UTF8 = ($^OPEN || "") =~ m/:utf8/
require "../t/lib/common.pl"
