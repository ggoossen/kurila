#!/usr/bin/perl -Tw

BEGIN {
    if( env::var('PERL_CORE') ) {
        chdir 't' if -d 't';
        @INC = @( '../lib' );
    }
    else {
        # ./lib is there so t/lib can be seen even after we chdir.
        unshift @INC, 't/lib', './lib';
    }
}
chdir 't';

use Test::More tests => 5;

BEGIN { 
    # non-core tests will have blib in their path.  We remove it
    # and just use the one in lib/.
    unless( env::var('PERL_CORE') ) {
        @INC = grep !m/blib/, @INC;
        unshift @INC, '../lib';
    }
}

my @blib_paths = grep m/blib/, @INC;
is( (nelems @blib_paths), 0, 'No blib dirs yet in @INC' );

use_ok( 'ExtUtils::testlib' );

@blib_paths = grep { m/blib/ } @INC;
is( (nelems @blib_paths), 2, 'ExtUtils::testlib added two @INC dirs!' );
ok( !(grep !File::Spec->file_name_is_absolute($_), @blib_paths),
                    '  and theyre absolute');

try { eval "# $(join ' ',@INC)"; };
is( $@, '',     '@INC is not tainted' );
