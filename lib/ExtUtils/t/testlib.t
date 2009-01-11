#!/usr/bin/perl -w

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
is( $^EVAL_ERROR, '',     '@INC is not tainted' );
