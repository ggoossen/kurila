#!./perl

BEGIN {
    chdir 't' if -d 't';
    $^INCLUDE_PATH = @( '../lib' );
}

print "1..3\n";

use SelectSaver;

open(FOO, ">", "foo-$^PID") || die;

print "ok 1\n";
do {
    my $saver = SelectSaver->new(*FOO);
    print "foo\n";
};

# Get data written to file
open(FOO, "<", "foo-$^PID") || die;
chomp(my $foo = ~< *FOO);
close FOO;
unlink "foo-$^PID";

print "ok 2\n" if $foo eq "foo";

print "ok 3\n";
