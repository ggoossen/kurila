#!./perl

use Config
use signals
BEGIN 
    require './test.pl'

    if (!(config_value: 'd_fork'))
        skip_all: "fork required to pipe"
    else
        plan: tests => 24


my $Perl = (which_perl: )


$^OUTPUT_AUTOFLUSH = 1

(open: my $pipe, "|-", "-") || exec: $Perl, '-e', 'while (my $_ = ~< $^STDIN) { s/Y/k/g; s/X/o/g; print $^STDOUT, $_ }'

printf: $pipe, "Xk \%d - open |- || exec\n", (curr_test: )
(next_test: )
printf: $pipe, "oY \%d -    again\n", (curr_test: )
(next_test: )
close $pipe

:SKIP do
    # Technically this should be TODO.  Someone try it if you happen to
    # have a vmesa machine.
    skip: "Doesn't work here yet", 6 if $^OS_NAME eq 'vmesa'

    if ((open: $pipe, "-|", "-"))
        while( ~< $pipe)
            s/^not //
            print: $^STDOUT, $_

        close $pipe        # avoid zombies
    else
        printf: $^STDOUT, "not ok \%d - open -|\n", (curr_test: )
        (next_test: )
        my $tnum = (curr_test: )
        (next_test: )
        exec: $Perl, '-e', "print \$^STDOUT, q\{not ok $tnum -     again\n\}"

    # This has to be *outside* the fork
    for (1..2)
        (next_test: )

    my $raw = "abc\nrst\rxyz\r\nfoo\n"
    if ((open: $pipe, "-|", "-"))
        $_ = join: '', @:  ~< $pipe
        (my $raw1 = $_) =~ s/not ok \d+ - //
        my @r  = map: { ord }, split: m//, $raw
        my @r1 = map: { ord }, split: m//, $raw1
        if ($raw1 eq $raw)
            s/^not (ok \d+ -) .*/$1 '$((join: ' ',@r1))' passes through '-|'\n/s
        else
            s/^(not ok \d+ -) .*/$1 expect '$((join: ' ',@r))', got '$((join: ' ',@r1))'\n/s
        
        print: $^STDOUT, $_
        close $pipe        # avoid zombies
    else
        printf: $^STDOUT, "not ok \%d - $raw", (curr_test: )
        exec: $Perl, '-e0'	# Do not run END()...
    

    # This has to be *outside* the fork
    (next_test: )

    if ((open: $pipe, "|-", "-"))
        printf: $pipe, "not ok \%d - $raw", (curr_test: )
        close $pipe        # avoid zombies
    else
        $_ = join: '', @:  ~< $^STDIN
        (my $raw1 = $_) =~ s/not ok \d+ - //
        my @r  = map: { ord }, split: m//, $raw
        my @r1 = map: { ord }, split: m//, $raw1
        if ($raw1 eq $raw)
            s/^not (ok \d+ -) .*/$1 '$((join: ' ',@r1))' passes through '|-'\n/s
        else
            s/^(not ok \d+ -) .*/$1 expect '$((join: ' ',@r))', got '$((join: ' ',@r1))'\n/s
        
        print: $^STDOUT, $_
        exec: $Perl, '-e0'	# Do not run END()...

    # This has to be *outside* the fork
    (next_test: )

    :SKIP do
        skip: "fork required", 2 unless config_value: 'd_fork'

        (pipe: my $reader, my $writer) || die: "Can't open pipe"

        if (my $pid = fork)
            close $writer
            while( ~< $reader)
                s/^not //
                s/([A-Z])/$((lc: $1))/g
                print: $^STDOUT, $_
            
            close $reader     # avoid zombies
        else
            die: "Couldn't fork" unless defined $pid
            close $reader
            printf: $writer, "not ok \%d - pipe & fork\n" (curr_test: )
            (next_test: )

            (open: $^STDOUT, ">&", $writer) || die: "Can't dup WRITER to STDOUT"
            close $writer

            my $tnum = (curr_test: )
            (next_test: )
            exec: $Perl, '-e', "print \$^STDOUT, q\{not ok $tnum -     with fh dup \n\}"


        # This has to be done *outside* the fork.
        for (1..2)
            (next_test: )

wait                            # Collect from $pid

(pipe: my $reader, my $writer) || die: "Can't open pipe"
close $reader

(signals::handler: 'PIPE') = &broken_pipe

sub broken_pipe
    (signals::handler: 'PIPE') = 'IGNORE'       # loop preventer
    (printf: $^STDOUT, "ok \%d - SIGPIPE\n" (curr_test: ))

(printf: $writer, "not ok \%d - SIGPIPE\n" (curr_test: ))
close $writer
sleep 1
(next_test: )
(pass: )

# VMS doesn't like spawning subprocesses that are still connected to
# STDOUT.  Someone should modify these tests to work with VMS.

:SKIP do
    skip: "doesn't like spawning subprocesses that are still connected", 10
        if $^OS_NAME eq 'VMS'

    :SKIP do
        # Sfio doesn't report failure when closing a broken pipe
        # that has pending output.  Go figure.
        # BeOS will not write to broken pipes, either.
        # Nor does POSIX-BC.
        skip: "Won't report failure on broken pipe", 1
            if (config_value: 'd_sfio') || $^OS_NAME eq 'beos' ||
          $^OS_NAME eq 'posix-bc'

        local (signals::handler: "PIPE") = 'IGNORE'
        open: my $nil, '|-', qq{$Perl -e "exit 0"} or die: "open failed: $^OS_ERROR"
        sleep 5
        if (print: $nil, 'foo')
            # If print was allowed we had better get an error on close
            ok:  !close $nil,     'close error on broken pipe' 
        else
            ok: close $nil,       'print failed on broken pipe'

    :SKIP do
        skip: "Don't work yet", 9 if $^OS_NAME eq 'vmesa'

        # check that errno gets forced to 0 if the piped program exited
        # non-zero
        open: my $nil, '|-', qq{$Perl -e "exit 23";} or die: "fork failed: $^OS_ERROR"
        $^OS_ERROR = 1
        ok: !close $nil,  'close failure on non-zero piped exit'
        is: $^OS_ERROR, '',      '       errno'
        isnt: $^CHILD_ERROR, 0,     '       status'

        :SKIP do
            skip: "Don't work yet", 6 if $^OS_NAME eq 'mpeix'

            # check that status for the correct process is collected
            my $zombie
            unless( $zombie = fork )
                our $NO_ENDING = 1
                exit 37
            
            my $pipe = (open: my $fh, "-|", "sleep 2;exit 13") or die: "Open: $^OS_ERROR\n"
            (signals::handler: "ALRM") = sub (@< @_) { return }
            alarm: 1
            is:  close $fh, '',   'close failure for... umm, something' 
            is:  $^CHILD_ERROR, 13*256,     '       status' 
            is:  $^OS_ERROR, '',         '       errno'

            my $wait = wait
            is:  $^CHILD_ERROR, 37*256,     'status correct after wait' 
            is:  $wait, $zombie, '       wait pid' 
            is:  $^OS_ERROR, '',         '       errno'


# Test new semantics for missing command in piped open
# 19990114 M-J. Dominus mjd@plover.com
do
    no warnings 'pipe'
    my $p
    ok:  !(open: $p, "|-", ""),        'missing command in piped open input' 
    ok:  !(open: $p, "-|", ""),       '                              output'


# check that status is unaffected by implicit close
do
    open: my $nil, '|-', qq{$Perl -e "exit 23"} or die: "fork failed: $^OS_ERROR"
    $^CHILD_ERROR = 42
# NIL implicitly closed here

is: $^CHILD_ERROR, 42,      'status unaffected by implicit close'
$^CHILD_ERROR = 0

# check that child is reaped if the piped program can't be executed
:SKIP do
    skip: "/no_such_process exists", 1 if -e "/no_such_process"
    open: my $nil, "-|", '/no_such_process'
    close $nil

    my $child = 0
    try {
        local (signals::handler: "ALRM") = sub () { (die: ); };
        alarm 2;
        $child = wait;
        alarm 0;
    }

    is: $child, -1, 'child reaped if piped program cannot be executed'

