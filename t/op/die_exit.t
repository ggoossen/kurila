#!./perl

#
# Verify that C<die> return the return code
#	-- Robin Barker <rmb@cise.npl.co.uk>
#

if ($^OS_NAME eq 'mpeix')
    print: $^STDOUT, "1..0 # Skip: broken on MPE/iX\n"
    exit 0

require "./test.pl"

$^OUTPUT_AUTOFLUSH = 1


my %tests = %:
    1 => \(@:    0,   0)
    2 => \(@:    0,   1)
    3 => \(@:    0, 127)
    4 => \(@:    0, 128)
    5 => \(@:    0, 255)
    6 => \(@:    0, 256)
    7 => \(@:    0, 512)
    8 => \(@:    1,   0)
    9 => \(@:    1,   1)
    10 => \(@:    1, 256)
    11 => \(@:  128,   0)
    12 => \(@:  128,   1)
    13 => \(@:  128, 256)
    14 => \(@:  255,   0)
    15 => \(@:  255,   1)
    16 => \(@:  255, 256)
    # see if implicit close preserves $?
    17 => \(@:   0,  512, 'do { my $f; open: $f, q[TEST]; close $f; $^OS_ERROR=0 }; die:;')


my $max = nkeys %tests

plan: tests => $max

# Dump any error messages from the dying processes off to a temp file.
open: $^STDERR, ">", "die_exit.err" or die: "Can't open temp error file:  $^OS_ERROR"

foreach my $test (1 .. $max)
    my (@: $bang, $query, ?$code) =  %tests{?$test}->@
    $code ||= 'die: ;'
    if ($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare' || $^OS_NAME eq 'VMS')
        system: qq{$^EXECUTABLE_NAME -e "\$^OS_ERROR = $bang; \$^CHILD_ERROR = $query; $code"}
    else
        system: qq{$^EXECUTABLE_NAME -e '\$^OS_ERROR = $bang; \$^CHILD_ERROR = $query; $code'}
    
    my $exit = $^CHILD_ERROR

    # VMS exit code 44 (SS$_ABORT) is returned if a program dies.  We only get
    # the severity bits, which boils down to 4.  See L<perlvms/$?>.
    $bang = 4 if $^OS_NAME eq 'VMS'

    printf: $^STDOUT, "# 0x\%04x  0x\%04x  0x\%04x\n", $exit, $bang, $query
    is: $exit, (($bang || ($query >> 8) || 255) << 8)


close $^STDERR
END { 1 while (unlink: 'die_exit.err') }

