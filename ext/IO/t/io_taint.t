#!./perl -T

use Config;

END { unlink "./__taint__$$" }

print "1..3\n";
use IO::File;
my $x = IO::File->new( "./__taint__$$", ">") || die("Cannot open ./__taint__$$\n");
print $x "$$\n";
$x->close;

$x = IO::File->new( "./__taint__$$", "<") || die("Cannot open ./__taint__$$\n");
chop(my $unsafe = ~< $x);
try { kill 0 * $unsafe };
print "not " if ((($^O ne 'MSWin32') && ($^O ne 'NetWare')) and ($@->{description} !~ m/^Insecure/o));
print "ok 1\n";
$x->close;

# We could have just done a seek on $x, but technically we haven't tested
# seek yet...
$x = IO::File->new( "./__taint__$$", "<") || die("Cannot open ./__taint__$$\n");
$x->untaint;
print "not " if ($?);
print "ok 2\n"; # Calling the method worked
chop($unsafe = ~< $x);
try { kill 0 * $unsafe };
print "not " if ($@ and $@->{description} =~ m/^Insecure/o);
print "ok 3\n"; # No Insecure message from using the data
$x->close;

exit 0;
