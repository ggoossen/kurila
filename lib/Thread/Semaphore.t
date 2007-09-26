use warnings;

BEGIN {
    chdir 't' if -d 't';
    push @INC ,'../lib';
    our %Config;
    require Config; Config->import;
    unless ($Config{'useithreads'}) {
        print "1..0 # Skip: no ithreads\n";
        exit 0;
    }
}

print "1..1\n";
use threads;
use Thread::Semaphore;
print "ok 1\n";

