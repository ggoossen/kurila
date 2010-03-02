use Config

BEGIN 
    my $reason

    if ((config_value: 'd_sem') ne 'define')
        $reason = '%Config{d_sem} undefined'
    elsif ((config_value: 'd_msg') ne 'define')
        $reason = '%Config{d_msg} undefined'
    
    if ($reason)
        print: $^STDOUT, "1..0 # Skip: $reason\n"
        exit 0
    


use IPC::SysV < qw(IPC_PRIVATE IPC_RMID IPC_NOWAIT IPC_STAT S_IRWXU S_IRWXG S_IRWXO)

use IPC::Msg
#Creating a message queue

print: $^STDOUT, "1..9\n"

my $msq =
    IPC::Msg->new: IPC_PRIVATE, S_IRWXU ^|^ S_IRWXG ^|^ S_IRWXO
    || die: "msgget: ",$^OS_ERROR+0," $^OS_ERROR\n"

print: $^STDOUT, "ok 1\n"

#Putting a message on the queue
my $msgtype = 1
my $msg = "hello"
print: $^STDOUT, ($msq->snd: $msgtype,$msg,IPC_NOWAIT) ?? "ok 2\n" !! "not ok 2 # $^OS_ERROR\n"

#Check if there are messages on the queue
my $ds = $msq->stat or print: $^STDOUT, "not "
print: $^STDOUT, "ok 3\n"

print: $^STDOUT, "not " unless $ds && $ds->qnum == 1
print: $^STDOUT, "ok 4\n"

#Retreiving a message from the queue
my $rmsgtype = 0 # Give me any type
my $rmsg
$rmsgtype = ($msq->rcv: \$rmsg, 256,$rmsgtype,IPC_NOWAIT) || print: $^STDOUT, "not "
print: $^STDOUT, "ok 5\n"

print: $^STDOUT, "not " unless $rmsgtype == $msgtype && $rmsg eq $msg
print: $^STDOUT, "ok 6\n"

$ds = $msq->stat or print: $^STDOUT, "not "
print: $^STDOUT, "ok 7\n"

print: $^STDOUT, "not " unless $ds && $ds->qnum == 0
print: $^STDOUT, "ok 8\n"

END 
    (defined $msq && $msq->remove) || print: $^STDOUT, "not "
    print: $^STDOUT, "ok 9\n"

