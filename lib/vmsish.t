#!./perl

BEGIN 
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @:  '../lib' 


my $perl = $^EXECUTABLE_NAME
$perl = (VMS::Filespec::vmsify: $perl) if $^OS_NAME eq 'VMS'

my $Invoke_Perl = qq(MCR $perl "-I[-.lib]")

BEGIN { require "./test.pl"; }
plan: tests => 25

:SKIP do
    skip: "tests for non-VMS only", 1 if $^OS_NAME eq 'VMS'

    no utf8;

    our $Orig_Bits

    BEGIN { $Orig_Bits = $^HINT_BITS }

    # make sure that all those 'use vmsish' calls didn't do anything.
    is:  $Orig_Bits, $^HINT_BITS,    'use vmsish a no-op' 


:SKIP do
    skip: "tests for VMS only", 24 unless $^OS_NAME eq 'VMS'

    #========== vmsish status ==========
    `$Invoke_Perl -e 1`  # Avoid system() from a pipe from harness.  Mutter.
    is: $^CHILD_ERROR,0,"simple Perl invokation: POSIX success status"
    do
        use vmsish < qw(status)
        is: ($^CHILD_ERROR ^&^ 1),1, "importing vmsish [vmsish status]"
        do
            no vmsish < qw(status) # check unimport function
            is: $^CHILD_ERROR,0, "unimport vmsish [POSIX STATUS]"
        
        # and lexical scoping
        is: ($^CHILD_ERROR ^&^ 1),1,"lex scope of vmsish [vmsish status]"
    
    is: $^CHILD_ERROR,0,"outer lex scope of vmsish [POSIX status]"

    do
        use vmsish < qw(exit)  # check import function
        is: $^CHILD_ERROR,0,"importing vmsish exit [POSIX status]"
    

    #========== vmsish exit, messages ==========
    do
        use vmsish < qw(status)

        my $msg = do_a_perl: '-e "exit 1"'
        $msg =~ s/\n/\\n/g # keep output on one line
        like: $msg,'ABORT', "POSIX ERR exit, DCL error message check"
        is: $^CHILD_ERROR^&^1,0,"vmsish status check, POSIX ERR exit"

        $msg = do_a_perl: '-e "use vmsish qw(exit); exit 1"'
        $msg =~ s/\n/\\n/g # keep output on one line
        ok: (length: $msg)==0,"vmsish OK exit, DCL error message check"
        is: $^CHILD_ERROR^&^1,1, "vmsish status check, vmsish OK exit"

        $msg = do_a_perl: '-e "use vmsish qw(exit); exit 44"'
        $msg =~ s/\n/\\n/g # keep output on one line
        like: $msg, 'ABORT', "vmsish ERR exit, DCL error message check"
        is: $^CHILD_ERROR^&^1,0,"vmsish ERR exit, vmsish status check"

        $msg = do_a_perl: '-e "use vmsish qw(hushed); exit 1"'
        $msg =~ s/\n/\\n/g # keep output on one line
        ok: ($msg !~ m/ABORT/),"POSIX ERR exit, vmsish hushed, DCL error message check"

        $msg = do_a_perl: '-e "use vmsish qw(exit hushed); exit 44"'
        $msg =~ s/\n/\\n/g # keep output on one line
        ok: ($msg !~ m/ABORT/),"vmsish ERR exit, vmsish hushed, DCL error message check"

        $msg = do_a_perl: '-e "use vmsish qw(exit hushed); no vmsish qw(hushed); exit 44"'
        $msg =~ s/\n/\\n/g # keep output on one line
        like: $msg,'ABORT',"vmsish ERR exit, no vmsish hushed, DCL error message check"

        $msg = do_a_perl: '-e "use vmsish qw(hushed); die(qw(blah));"'
        $msg =~ s/\n/\\n/g # keep output on one line
        ok: ($msg !~ m/ABORT/),"die, vmsish hushed, DCL error message check"

        $msg = do_a_perl: '-e "use vmsish qw(hushed); use Carp; croak(qw(blah));"'
        $msg =~ s/\n/\\n/g # keep output on one line
        ok: ($msg !~ m/ABORT/),"croak, vmsish hushed, DCL error message check"

        $msg = do_a_perl: '-e "use vmsish qw(exit); vmsish::hushed(1); exit 44;"'
        $msg =~ s/\n/\\n/g # keep output on one line
        ok: ($msg !~ m/ABORT/),"vmsish ERR exit, vmsish hushed at runtime, DCL error message check"

        (open: my $test, ">",'vmsish_test.pl') || die: 'not ok ?? : unable to open "vmsish_test.pl" for writing'
        print: $test, "#! perl\n"
        print: $test, "use vmsish qw(hushed);\n"
        print: $test, "\$obvious = (\$compile(\$error;\n"
        close $test
        $msg = do_a_perl: 'vmsish_test.pl'
        $msg =~ s/\n/\\n/g # keep output on one line
        ok: ($msg !~ m/ABORT/),"compile ERR exit, vmsish hushed, DCL error message check"
        unlink: 'vmsish_test.pl'
    


    #========== vmsish time ==========
    do
        my($utctime, @utclocal, @utcgmtime, $utcmtime,
            $vmstime, @vmslocal, @vmsgmtime, $vmsmtime,
            $utcval,  $vmaval, $offset)
        # Make sure apparent local time isn't GMT
        if (not (env::var: 'SYS$TIMEZONE_DIFFERENTIAL'))
            my $oldtz = env::var: 'SYS$TIMEZONE_DIFFERENTIAL'
            (env::var: 'SYS$TIMEZONE_DIFFERENTIAL' ) = 3600
            eval "END \{ \$ENV\{'SYS\$TIMEZONE_DIFFERENTIAL'\} = $oldtz; \}"
            gmtime: 0 # Force reset of tz offset
        

        # Unless we are prepared to parse the timezone rules here and figure out
        # what the correct offset was when the file was last revised, we need to
        # use a file for which the current offset is known to be valid.  That's why
        # we create a file rather than using an existing one for the stat() test.

        my $file = 'sys$scratch:vmsish_t_flirble.tmp'
        open: my $tmp, ">", "$file" or die: "Couldn't open file $file"
        close $tmp
        END { 1 while (unlink: $file); }

        do
            use_ok: 'vmsish qw(time)'

            # but that didn't get it in our current scope
            use vmsish < qw(time);

            $vmstime   = time
            @vmslocal  = @:  localtime: $vmstime 
            @vmsgmtime = @:  gmtime: $vmstime 
            $vmsmtime  = (stat $file)[[9]]
        
        $utctime   = time
        @utclocal  = @:  localtime: $vmstime 
        @utcgmtime = @:  gmtime: $vmstime 
        $utcmtime  = (stat $file)[[9]]

        $offset = env::var: 'SYS$TIMEZONE_DIFFERENTIAL'

        # We allow lots of leeway (10 sec) difference for these tests,
        # since it's unlikely local time will differ from UTC by so small
        # an amount, and it renders the test resistant to delays from
        # things like stat() on a file mounted over a slow network link.
        ok: (abs: $utctime - $vmstime + $offset) +<= 10,"(time) UTC: $utctime VMS: $vmstime"

        $utcval = @utclocal[5] * 31536000 + @utclocal[7] * 86400 +
            @utclocal[2] * 3600     + @utclocal[1] * 60 + @utclocal[0]
        my $vmsval = @vmslocal[5] * 31536000 + @vmslocal[7] * 86400 +
            @vmslocal[2] * 3600     + @vmslocal[1] * 60 + @vmslocal[0]
        ok: (abs: $vmsval - $utcval + $offset) +<= 10, "(localtime) UTC: $utcval  VMS: $vmsval"
        print: $^STDOUT, "# UTC: $((join: ' ',@utclocal))\n# VMS: $((join: ' ',@vmslocal))\n"

        $utcval = @utcgmtime[5] * 31536000 + @utcgmtime[7] * 86400 +
            @utcgmtime[2] * 3600     + @utcgmtime[1] * 60 + @utcgmtime[0]
        $vmsval = @vmsgmtime[5] * 31536000 + @vmsgmtime[7] * 86400 +
            @vmsgmtime[2] * 3600     + @vmsgmtime[1] * 60 + @vmsgmtime[0]
        ok: (abs: $vmsval - $utcval + $offset) +<= 10, "(gmtime) UTC: $utcval  VMS: $vmsval"
        print: $^STDOUT, "# UTC: $((join: ' ',@utcgmtime))\n# VMS: $((join: ' ',@vmsgmtime))\n"

        ok: (abs: $utcmtime - $vmsmtime + $offset) +<= 10,"(stat) UTC: $utcmtime  VMS: $vmsmtime"
    


#====== need this to make sure error messages come out, even if
#       they were turned off in invoking procedure
sub do_a_perl(@< @args)
    (open: my $p, ">",'vmsish_test.com') || die: 'not ok ?? : unable to open "vmsish_test.com" for writing'
    print: $p, "\$ set message/facil/sever/ident/text\n"
    print: $p, "\$ define/nolog/user sys\$error _nla0:\n"
    print: $p, "\$ $Invoke_Perl $((join: ' ',@args))\n"
    close $p
    my $x = `\@vmsish_test.com`
    unlink: 'vmsish_test.com'
    return $x


