BEGIN {
    if (env::var('PERL_CORE')) {
	push $^INCLUDE_PATH, "lib/compress";
    }
}

use lib < qw(t t/compress);
 
use warnings ;

use Test::More ;

BEGIN 
{ 
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if try { require Test::NoWarnings ;  Test::NoWarnings->import(); 1 };

    plan tests => 2 + $extra ;

    use_ok('Compress::Raw::Zlib', 2) ; 
}

# Check zlib_version and ZLIB_VERSION are the same.

my $zlib_h = ZLIB_VERSION ;
my $libz   = Compress::Raw::Zlib::zlib_version;

is($zlib_h, $libz, "ZLIB_VERSION ($zlib_h) matches Compress::Raw::Zlib::zlib_version")
    or diag <<EOM;

The version of zlib.h does not match the version of libz
 
You have zlib.h version $zlib_h
     and libz   version $libz
 
You probably have two versions of zlib installed on your system.
Try removing the one you don't want to use and rebuild.
EOM

