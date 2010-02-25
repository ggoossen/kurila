use Test::More
use Config

if ((config_value: 'd_sem') ne 'define')
    skip_all: '$Config{d_sem} undefined'
elsif ((config_value: 'd_msg') ne 'define')
    skip_all: '$Config{d_msg} undefined'
else
    plan:  tests => 17 


# These constants are common to all tests.
# Later the sem* tests will import more for themselves.

use IPC::SysV < qw(IPC_PRIVATE IPC_NOWAIT IPC_STAT IPC_RMID S_IRWXU)


my $msg
my $sem

# FreeBSD is known to throw this if there's no SysV IPC in the kernel.
(signals::handler: "SYS") = sub (@< @_)
    diag: <<EOM
SIGSYS caught.
It may be that your kernel does not have SysV IPC configured.

EOM
    if ($^OS_NAME eq 'freebsd')
        diag: <<EOM
You must have following options in your kernel:

options         SYSVSHM
options         SYSVSEM
options         SYSVMSG

See config(8).

EOM
    
    diag: 'Bail out! SIGSYS caught'
    exit: 1


my $perm = S_IRWXU

:SKIP do

    skip:  'lacking d_msgget d_msgctl d_msgsnd d_msgrcv', 6  unless
        (config_value: 'd_msgget') eq 'define' &&
        (config_value: 'd_msgctl') eq 'define' &&
        (config_value: 'd_msgsnd') eq 'define' &&
        (config_value: 'd_msgrcv') eq 'define'

    $msg = msgget: IPC_PRIVATE, $perm
    # Very first time called after machine is booted value may be 0
    if (!((defined: $msg) && $msg +>= 0))
        skip:  "msgget failed: $^OS_ERROR", 6
    else
        pass: 'msgget IPC_PRIVATE S_IRWXU'
    

    #Putting a message on the queue
    my $msgtype = 1
    my $msgtext = "hello"

    my $test2bad
    my $test5bad
    my $test6bad

    my $test_name = 'queue a message'
    if ((msgsnd: $msg,(pack: "L! a*",$msgtype,$msgtext),IPC_NOWAIT))
        pass: $test_name
    else
        fail: $test_name
        $test2bad = 1
        diag: <<EOM
The failure of the subtest #2 may indicate that the message queue
resource limits either of the system or of the testing account
have been reached.  Error message "Operating would block" is
usually indicative of this situation.  The error message was now:
"$^OS_ERROR"

You can check the message queues with the 'ipcs' command and
you can remove unneeded queues with the 'ipcrm -q id' command.
You may also consider configuring your system or account
to have more message queue resources.

Because of the subtest #2 failing also the substests #5 and #6 will
very probably also fail.
EOM
    

    my $data
    ok: (msgctl: $msg,IPC_STAT,$data),'msgctl IPC_STAT call'

    cmp_ok: (length: $data),'+>',0,'msgctl IPC_STAT data'

    my $test_name = 'message get call'
    my $msgbuf
    if ((msgrcv: $msg,$msgbuf,256,0,IPC_NOWAIT))
        pass: $test_name
    else
        fail: $test_name
        $test5bad = 1
    
    if ($test5bad && $test2bad)
        diag: <<EOM
This failure was to be expected because the subtest #2 failed.
EOM
    

    my $test_name = 'message get data'
    my($rmsgtype,$rmsgtext)
    (@: $rmsgtype,$rmsgtext) = @: unpack: "L! a*",$msgbuf
    if ($rmsgtype == $msgtype && $rmsgtext eq $msgtext)
        pass: $test_name
    else
        fail: $test_name
        $test6bad = 1
    
    if ($test6bad && $test2bad)
        print: $^STDOUT, <<EOM
This failure was to be expected because the subtest #2 failed.
EOM
    
 # SKIP

:SKIP do

    skip: 'lacking d_semget d_semctl', 11 unless
        (config_value: 'd_semget') eq 'define' &&
        (config_value: 'd_semctl') eq 'define'

    use IPC::SysV < qw(IPC_CREAT GETALL SETALL)

    # FreeBSD's default limit seems to be 9
    my $nsem = 5

    my $test_name = 'sem acquire'
    $sem = semget: IPC_PRIVATE, $nsem, $perm ^|^ IPC_CREAT
    if ($sem)
        pass: $test_name
    else
        diag: "cannot proceed: semget() error: $^OS_ERROR"
        skip: 'semget() resource unavailable', 11
            if $^OS_ERROR eq 'No space left on device'

        # Very first time called after machine is booted value may be 0
        die: "semget: $^OS_ERROR\n" unless (defined: $sem) && $sem +>= 0
    

    my $data
    ok: (semctl: $sem,0,IPC_STAT,$data),'sem data call'

    cmp_ok: (length: $data),'+>',0,'sem data len'

    ok: (semctl: $sem,0,SETALL,(pack: "s!*",< $: (@: 0) x $nsem)), 'set all sems'

    $data = ""
    ok: (semctl: $sem,0,GETALL,$data), 'get all sems'

    is: (length: $data),(length: (pack: "s!*", < $: (@: 0) x $nsem)), 'right length'

    my @data = @: unpack: "s!*",$data

    my $adata = "0" x $nsem

    is: (nelems: @data),$nsem,'right amount'
    cmp_ok: (join: "",@data),'eq',$adata,'right data'

    my $poke = 2

    @data[$poke] = 1
    ok: (semctl: $sem,0,SETALL,(pack: "s!*",<@data)),'poke it'

    $data = ""
    ok: (semctl: $sem,0,GETALL,$data),'and get it back'

    @data = @: unpack: "s!*",$data
    my $bdata = "0" x $poke . "1" . "0" x ($nsem-$poke-1)

    cmp_ok: (join: "",@data),'eq',$bdata,'changed'
 # SKIP

END 
    msgctl: $msg,IPC_RMID,0       if defined $msg
    semctl: $sem,0,IPC_RMID,undef if defined $sem

