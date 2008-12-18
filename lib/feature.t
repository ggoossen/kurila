#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = @( '../lib' );
    env::set_var('PERL5LIB') = '../lib';
}

our $pragma_name = "feature";
require "../t/lib/common.pl";
