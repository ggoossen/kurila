#!./perl

use Config
use Test::More tests => 15

# these two should be kept in sync with the pragma itself
# if hint bits are changed there, other things *will* break
my $hint_bits = 0x00400000
my $error = "filetest: the only implemented subpragma is 'access'.\n"

# can't use it yet, because of the import death
ok:  require filetest, 'required pragma successfully' 

# and here's one culprit, right here
try { (filetest->import: 'bad subpragma') }
is:  $^EVAL_ERROR->{?description}, $error, 'filetest dies with bad subpragma on import' 

is:  $^HINT_BITS ^&^ $hint_bits, 0, 'hint bits not set without pragma in place' 

# now try the normal usage
# can't check $^H here; it's lexically magic (see perlvar)
# the test harness unintentionally hoards the goodies for itself
use_ok:  'filetest', 'access' 

# and import again, to see it here
filetest->import: 'access'
ok:  $^HINT_BITS ^&^ $hint_bits, 'hint bits set with pragma loaded' 

# and now get rid of it
filetest->unimport: 'access'
is:  $^HINT_BITS ^&^ $hint_bits, 0, 'hint bits not set with pragma unimported' 

try { filetest->unimport }
is:  $^EVAL_ERROR->{?description}, $error, 'filetest dies without subpragma on unimport' 

# there'll be a compilation aborted failure here, with the eval string
eval "no filetest 'fake pragma'"
like:  $^EVAL_ERROR->{?description}, qr/^$error/, 'filetest dies with bad subpragma on unuse' 

eval "use filetest 'bad subpragma'"
like:  $^EVAL_ERROR->{?description}, qr/^$error/, 'filetest dies with bad subpragma on use' 

eval "use filetest"
like:  $^EVAL_ERROR->{?description}, qr/^$error/, 'filetest dies with missing subpragma on use' 

eval "no filetest"
like:  $^EVAL_ERROR->{?description}, qr/^$error/, 'filetest dies with missing subpragma on unuse' 

:SKIP do
    # A real test for filetest.
    # This works for systems with /usr/bin/chflags (i.e. BSD4.4 systems).
    my $chflags = "/usr/bin/chflags"
    my $tstfile = "filetest.tst"
    skip: "No $chflags available", 4 if !-x $chflags

    my $skip_eff_user_tests = (!(config_value: "d_setreuid") && !(config_value: "d_setresuid"))
        ||
        (!(config_value: "d_setregid") && !(config_value: "d_setresgid"))

    try {
        if (!-e $tstfile)
            open: my $t, ">", "$tstfile" or die: "Can't create $tstfile: $^OS_ERROR"
            close $t
        
        (system: $chflags, "uchg", $tstfile);
        die: "Can't exec $chflags uchg" if $^CHILD_ERROR != 0;
    }
    skip: "Errors in test using chflags: $^EVAL_ERROR", 4 if $^EVAL_ERROR

    do
        use filetest 'access'
        :SKIP do
            skip: "No tests on effective user id", 1
                if $skip_eff_user_tests
            is: -w $tstfile, undef, "$tstfile should not be recognized as writable"
        
        is: -W $tstfile, undef, "$tstfile should not be recognized as writable"
    

    do
        no filetest 'access'
        :SKIP do
            skip: "No tests on effective user id", 1
                if $skip_eff_user_tests
            is: -w $tstfile, 1, "$tstfile should be recognized as writable"
        
        is: -W $tstfile, 1, "$tstfile should be recognized as writable"
    

    # cleanup
    system: $chflags, "nouchg", $tstfile
    unlink: $tstfile
    warn: "Can't remove $tstfile: $^OS_ERROR" if -e $tstfile

