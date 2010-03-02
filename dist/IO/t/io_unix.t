#!./perl

use Config

BEGIN 
    my $reason
    if ($^OS_NAME eq 'os2')
        require IO::Socket

        try {(IO::Socket::pack_sockaddr_un: '/foo/bar') || 1}
            or $^EVAL_ERROR->{?description} !~ m/not implemented/ or
            $reason = 'compiled without TCP/IP stack v4'
    elsif ($^OS_NAME =~ m/^(?:qnx|nto|vos|MSWin32)$/ )
        $reason = "UNIX domain sockets not implemented on $^OS_NAME"
    elsif (! (config_value: 'd_fork'))
        $reason = 'no fork'
    
    if ($reason)
        print: $^STDOUT, "1..0 # Skip: $reason\n"
        exit 0
    


my $PATH = "sock-$^PID"

if ($^OS_NAME eq 'os2') # Can't create sockets with relative path...
    require Cwd
    my $d = (Cwd::cwd: )
    $d =~ s/^[a-z]://i
    $PATH = "$d/$PATH"


# Test if we can create the file within the tmp directory
if (-e $PATH or not (open: my $testfh, ">", "$PATH") and $^OS_NAME ne 'os2')
    print: $^STDOUT, "1..0 # Skip: cannot open '$PATH' for write\n"
    exit 0

unlink: $PATH or $^OS_NAME eq 'os2' or die: "Can't unlink $PATH: $^OS_ERROR"

# Start testing
$^OUTPUT_AUTOFLUSH = 1
print: $^STDOUT, "1..5\n"

use IO::Socket::UNIX

my $listen = IO::Socket::UNIX->new: Local => $PATH, Listen => 0

# Sometimes UNIX filesystems are mounted for security reasons
# with "nodev" option which spells out "no" for creating UNIX
# local sockets.  Therefore we will retry with a File::Temp
# generated filename from a temp directory.
unless (defined $listen)
    try { require File::Temp }
    unless ($^EVAL_ERROR)
        File::Temp->import:  'mktemp'
        for my $TMPDIR (@: (env::var: 'TMPDIR'), "/tmp")
            if (defined $TMPDIR && -d $TMPDIR && -w $TMPDIR)
                $PATH = mktemp: "$TMPDIR/sXXXXXXXX"
                last if $listen = IO::Socket::UNIX->new: Local => $PATH
                                                         Listen => 0
    
    defined $listen or die: "$PATH: $^OS_ERROR"

print: $^STDOUT, "ok 1\n"

if(my $pid = fork: )

    my $sock = $listen->accept:

    if (defined $sock)
        print: $^STDOUT, "ok 2\n"

        print: $^STDOUT, $sock->getline: 

        print: $sock, "ok 4\n"

        $sock->close: 

        waitpid: $pid,0
        (unlink: $PATH) || $^OS_NAME eq 'os2' || warn: "Can't unlink $PATH: $^OS_ERROR"

        print: $^STDOUT, "ok 5\n"
    else
        print: $^STDOUT, "# accept() failed: $^OS_ERROR\n"
        for (2..5)
            print: $^STDOUT, "not ok $_ # accept failed\n"
        
    
elsif(defined $pid)

    my $sock = (IO::Socket::UNIX->new: Peer => $PATH) or die: "$^OS_ERROR"

    print: $sock, "ok 3\n"

    print: $^STDOUT, $sock->getline: 

    $sock->close: 

    exit
else
    die: 

