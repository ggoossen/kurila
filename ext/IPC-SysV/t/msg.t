use Config;

BEGIN {
    my $reason;

    if (%Config{'d_sem'} ne 'define') {
      $reason = '%Config{d_sem} undefined';
    } elsif (%Config{'d_msg'} ne 'define') {
      $reason = '%Config{d_msg} undefined';
    }
    if ($reason) {
	print "1..0 # Skip: $reason\n";
	exit 0;
    }
}

use IPC::SysV < qw(IPC_PRIVATE IPC_RMID IPC_NOWAIT IPC_STAT S_IRWXU S_IRWXG S_IRWXO);

use IPC::Msg;
#Creating a message queue

print "1..9\n";

my $msq =
    IPC::Msg->new(IPC_PRIVATE, S_IRWXU ^|^ S_IRWXG ^|^ S_IRWXO)
    || die "msgget: ",$!+0," $!\n";
	
print "ok 1\n";

#Putting a message on the queue
my $msgtype = 1;
my $msg = "hello";
print $msq->snd($msgtype,$msg,IPC_NOWAIT) ? "ok 2\n" : "not ok 2 # $!\n";

#Check if there are messages on the queue
my $ds = $msq->stat() or print "not ";
print "ok 3\n";

print "not " unless $ds && $ds->qnum() == 1;
print "ok 4\n";

#Retreiving a message from the queue
my $rmsgtype = 0; # Give me any type
$rmsgtype = $msq->rcv(my $rmsg,256,$rmsgtype,IPC_NOWAIT) || print "not ";
print "ok 5\n";

print "not " unless $rmsgtype == $msgtype && $rmsg eq $msg;
print "ok 6\n";

$ds = $msq->stat() or print "not ";
print "ok 7\n";

print "not " unless $ds && $ds->qnum() == 0;
print "ok 8\n";

END {
	(defined $msq && $msq->remove) || print "not ";
	print "ok 9\n";
}
