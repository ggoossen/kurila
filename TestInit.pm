# This is a replacement for the old BEGIN preamble which heads (or
# should head) up every core test program to prepare it for running.
# Now instead of:
#
# BEGIN
#   chdir 't' if -d 't'
#   @INC = '../lib'
#
# Its primary purpose is to clear @INC so core tests don't pick up
# modules from an installed Perl.
#
# t/TEST will use -MTestInit.  You may "use TestInit" in the test
# programs but it is not required.
#
# P.S. This documentation is not in POD format in order to avoid
# problems when there are fundamental bugs in perl.

package TestInit

our $VERSION = 1.02

# Let tests know they're running in the perl core.  Useful for modules
# which live dual lives on CPAN.
# Don't interfere with the taintedness of %ENV, this could perturbate tests.
# This feels like a better solution than the original, from
# http://www.xray.mpe.mpg.de/mailing-lists/perl5-porters/2003-07/msg00154.html
(env::var: 'PERL_CORE') = $^EXECUTABLE_NAME

sub new_inc(@v)
    $^INCLUDE_PATH = @: < @v, '.'

sub set_opt(@opts)
    my $sep
    if ($^OS_NAME eq 'VMS')
        $sep = '|'
    elsif ($^OS_NAME eq 'MSWin32')
        $sep = ''
    else
        $sep = ':'

    my $lib = join: $sep, @opts
    if (defined (env::var: 'PERL5LIB'))
        (env::var: 'PERL5LIB') = $lib . substr: (env::var: 'PERL5LIB'), 0, 0
    else
        (env::var: 'PERL5LIB') = $lib

my @up_2_t = @: '../../lib', '../../t'
# This is incompatible with the import options.
if (-f 't/TEST' && -f 'MANIFEST' && -d 'lib' && -d 'ext')
    # We're being run from the top level. Try to change directory, and set
    # things up correctly. This is a 90% solution, but for hand-running tests,
    # that's good enough
    if ($^PROGRAM_NAME =~ s!^((?:ext|dist|cpan)[\\/][^\\/]+)[\//](.*\.t)$!$2!)
        # Looks like a test in ext.
        chdir $1 or die: "Can't chdir '$1': $^OS_ERROR"
        new_inc: @up_2_t
        set_opt: @up_2_t
        $^EXECUTABLE_NAME =~ s!^\./!../../!
        $^EXECUTABLE_NAME =~ s!^\.\\!..\\..\\!
    else
        chdir 't' or die: "Can't chdir 't': $^OS_ERROR"
        new_inc: @: '../lib'
else
    new_inc: @: '../lib'

sub import($self, @< @args)
    my $abs
    my @new_inc
    foreach (@args)
        if ($_ eq 'U2T')
            @new_inc = @up_2_t
        elsif ($_ eq 'NC')
            (env::var: 'PERL_CORE') = undef
        elsif ($_ eq 'A')
            $abs = 1
        else
            die: "Unknown option '$_'"

    if ($abs)
        if(!@new_inc)
            @new_inc = @: '../lib'
        $^INCLUDE_PATH = @new_inc
        require File::Spec::Functions
        # Forcibly untaint this.
        @new_inc = map: { $_ = (File::Spec::Functions::rel2abs: $_); m/(.*)/; $1 },
                            @new_inc
        $^EXECUTABLE_NAME = File::Spec::Functions::rel2abs: $^EXECUTABLE_NAME

    if (@new_inc)
        new_inc: @new_inc
        set_opt: @new_inc

$^PROGRAM_NAME =~ s/\.dp$// # for the test.deparse make target

1
