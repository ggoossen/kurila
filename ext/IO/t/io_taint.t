#!./perl -T

use Config;

END { unlink "./__taint__$^PID" }

print "1..3\n";
use IO::File;
my $x = IO::File->new( "./__taint__$^PID", ">") || die("Cannot open ./__taint__$^PID\n");
print $x "$^PID\n";
$x->close;

$x = IO::File->new( "./__taint__$^PID", "<") || die("Cannot open ./__taint__$^PID\n");
chop(my $unsafe = ~< $x);
try { kill 0 * $unsafe };
print "not " if ((($^O ne 'MSWin32') && ($^O ne 'NetWare')) and ($^EVAL_ERROR->{?description} !~ m/^Insecure/o));
print "ok 1\n";
$x->close;

# We could have just done a seek on $x, but technically we haven't tested
# seek yet...
$x = IO::File->new( "./__taint__$^PID", "<") || die("Cannot open ./__taint__$^PID\n");
$x->untaint;
print "not " if ($^CHILD_ERROR);
print "ok 2\n"; # Calling the method worked
chop($unsafe = ~< $x);
try { kill 0 * $unsafe };
print "not " if ($^EVAL_ERROR and $^EVAL_ERROR->{?description} =~ m/^Insecure/o);
print "ok 3\n"; # No Insecure message from using the data
$x->close;

exit 0;
