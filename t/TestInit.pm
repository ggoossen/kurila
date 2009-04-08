# This is a replacement for the old BEGIN preamble which heads (or
# should head) up every core test program to prepare it for running.
# Now instead of:
#
# BEGIN {
#   chdir 't' if -d 't';
#   $^INCLUDE_PATH = '../lib';
# }
#
# t/TEST will use -MTestInit.  You may "use TestInit" in the test
# programs but it is not required.
#
# P.S. This documentation is not in POD format in order to avoid
# problems when there are fundamental bugs in perl.

package TestInit;

our $VERSION = 1.01;

BEGIN {
    chdir 't' if -d 't';
    $^INCLUDE_PATH = @('../lib');
}

env::var('PERL_CORE' ) = 1;

$^PROGRAM_NAME =~ s/\.dp$//; # for the test.deparse make target

1;

