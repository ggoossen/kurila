#!perl -w

use Test::More tests => 1

BEGIN 
    use_ok:  'Sys::Syslog' 


diag:  "Testing Sys::Syslog $Sys::Syslog::VERSION, Perl $^PERL_VERSION, $^EXECUTABLE_NAME" 
    unless env::var: 'PERL_CORE'
