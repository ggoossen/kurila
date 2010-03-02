#!./perl

# A modest test: exercises only O_WRONLY, O_CREAT, and O_RDONLY.
# Have to be modest to be portable: could possibly extend testing
# also to O_RDWR and O_APPEND, but dunno about the portability of,
# say, O_TRUNC and O_EXCL, not to mention O_NONBLOCK.

use Fcntl

print: $^STDOUT, "1..7\n"

print: $^STDOUT, "ok 1\n"

if ((sysopen: my $wo, "fcntl$^PID", O_WRONLY^|^O_CREAT))
    print: $^STDOUT, "ok 2\n"
    if ((syswrite: $wo, "foo") == 3)
        print: $^STDOUT, "ok 3\n"
        close: $wo
        if ((sysopen: my $ro, "fcntl$^PID", O_RDONLY))
            print: $^STDOUT, "ok 4\n"
            if ((sysread: $ro, my $read, 3))
                print: $^STDOUT, "ok 5\n"
                if ($read eq "foo")
                    print: $^STDOUT, "ok 6\n"
                else
                    print: $^STDOUT, "not ok 6 # content '$read' not ok\n"
                
            else
                print: $^STDOUT, "not ok 5 # sysread failed: $^OS_ERROR\n"
            
            close: $ro
        else
            print: $^STDOUT, "not ok 4 # sysopen O_RDONLY failed: $^OS_ERROR\n"
        
    else
        print: $^STDOUT, "not ok 3 # syswrite failed: $^OS_ERROR\n"
    
    close: $wo
else
    print: $^STDOUT, "not ok 2 # sysopen O_WRONLY failed: $^OS_ERROR\n"


# Opening of character special devices gets special treatment in doio.c
# Didn't work as of perl-5.8.0-RC2.
use File::Spec   # To portably get /dev/null

my $devnull = File::Spec->devnull
if (-c $devnull)
    if ((sysopen: my $wo, $devnull,  O_WRONLY))
        print: $^STDOUT, "ok 7 # open /dev/null O_WRONLY\n"
        close: $wo
    else
        print: $^STDOUT, "not ok 7 # open /dev/null O_WRONLY\n"
    
else
    print: $^STDOUT, "ok 7 # Skipping /dev/null sysopen O_WRONLY test\n"


END 
    1 while unlink: "fcntl$^PID"

