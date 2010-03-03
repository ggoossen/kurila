package MakeMaker::Test::Setup::XS

our @ISA = qw(Exporter)
require Exporter
our @EXPORT = qw(setup_xs teardown_xs)

use File::Path
use File::Basename
use MakeMaker::Test::Utils

my $Is_VMS = $^OS_NAME eq 'VMS'

my %Files = %:
    'XS-Test/lib/XS/Test.pm'     => <<'END'
package XS::Test;

require Exporter;
require DynaLoader;

our $VERSION = 1.01;
our @ISA    = qw(Exporter DynaLoader);
our @EXPORT = qw(is_even);

bootstrap XS::Test $VERSION;

1;
END

    'XS-Test/Makefile.PL'          => <<'END'
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'XS::Test',
    VERSION_FROM  => 'lib/XS/Test.pm',
    );
END

    'XS-Test/Test.xs'              => <<'END'
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = XS::Test       PACKAGE = XS::Test

PROTOTYPES: DISABLE

int
is_even(input)
       int     input
   CODE:
       RETVAL = (input % 2 == 0);
   OUTPUT:
       RETVAL        
END

    'XS-Test/t/is_even.t'          => <<'END'
#!/usr/bin/perl -w

use Test::More tests => 3;

use_ok "XS::Test";
ok !is_even(1);
ok is_even(2);
END
    


sub setup_xs()
    (setup_mm_test_root: )
    chdir 'MM_TEST_ROOT:[t]' if $Is_VMS

    while(my(@: ?$file, ?$text) =(@:  each %Files))
        # Convert to a relative, native file path.
        $file = File::Spec->catfile: File::Spec->curdir, < (split: m{\/}, $file)

        my $dir = dirname: $file
        mkpath: $dir
        (open: my $file, ">", $file) || die: "Can't create $file: $^OS_ERROR"
        print: $file, $text
        close $file

    return 1


sub teardown_xs
    foreach my $file (keys %Files)
        my $dir = dirname: $file
        if( -e $dir )
            (rmtree: $dir) || return
        
    
    return 1


1
