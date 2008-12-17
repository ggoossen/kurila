#!./perl -Tw
# Testing Cwd under taint mode.



use Cwd;

use File::Spec;
use lib File::Spec->catdir('t', 'lib');
use Test::More tests => 17;

use Scalar::Util < qw/tainted/;

my @Functions = qw(getcwd cwd fastcwd fastgetcwd
                   abs_path fast_abs_path
                   realpath fast_realpath
                  );

foreach my $func ( @Functions) {
    my $cwd;
    try { $cwd = &{*{Symbol::fetch_glob('Cwd::'.$func)}} };
    die if $@;
    is( $@, '',		"$func() should not explode under taint mode" );
    ok( tainted($cwd),	"its return value should be tainted" );
}

# Previous versions of Cwd tainted $^O
is !tainted($^O), 1, "\$^O should not be tainted";
