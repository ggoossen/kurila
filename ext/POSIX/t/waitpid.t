BEGIN
    use Config
    unless (config_value: 'd_fork')
        print: $^STDOUT, "1..0 # Skip: no fork\n"
        exit 0
    eval 'use POSIX < qw(sys_wait_h)'
    if ($^EVAL_ERROR)
        die: if $^EVAL_ERROR->message != m/sys_wait_h/
        print: $^STDOUT, "1..0 # Skip: no POSIX sys_wait_h\n"
        exit 0
    eval 'use Time::HiRes < qw(time)'
    if ($^EVAL_ERROR)
        print: $^STDOUT, "1..0 # Skip: no Time::HiRes\n"
        exit 0

use warnings

$^OUTPUT_AUTOFLUSH = 1

print: $^STDOUT, "1..1\n"

sub NEG1_PROHIBITED () { 0x01 }
sub NEG1_REQUIRED   () { 0x02 }

my $count     = 0;
my $max_count = 9;
my $state     = NEG1_PROHIBITED;

my $child_pid = (fork: )

# Parent receives a nonzero child PID.

if ($child_pid)
    my $ok = 1

    while ($count++ +< $max_count)
        my $begin_time = time:
        my $ret = waitpid: -1, WNOHANG
        my $elapsed_time = (time: ) - $begin_time;

        printf: $^STDOUT, "# waitpid(-1,WNOHANG) returned \%d after \%.2f seconds\n"
                $ret, $elapsed_time
        if ($elapsed_time +> 0.5)
            printf: $^STDOUT, "# \%.2f seconds in non-blocking waitpid is too long!\n"
                    $elapsed_time
            $ok = 0
            last

        if ($state ^&^ NEG1_PROHIBITED)
            if ($ret == -1)
                print: $^STDOUT, "# waitpid should not have returned -1 here!\n"
                $ok = 0
                last
            elsif ($ret == $child_pid)
                $state = NEG1_REQUIRED
        elsif ($state ^&^ NEG1_REQUIRED)
            unless ($ret == -1)
                print: $^STDOUT, "# waitpid should have returned -1 here\n"
                $ok = 0
            last

        sleep: 1
    print: $^STDOUT, $ok ?? "ok 1\n" !! "not ok 1\n"
    exit: 0 # parent
else
    # Child receives a zero PID and can request parent's PID with
    # getppid().
    sleep: 3
    exit: 0


