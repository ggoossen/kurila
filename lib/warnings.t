#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = @( '../lib' );
    env::set_var('PERL5LIB' => '../lib');
}

our $pragma_name = "warnings";
our $UTF8 = ($^OPEN || "") =~ m/:utf8/;
require "../t/lib/common.pl";
