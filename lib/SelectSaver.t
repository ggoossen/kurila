#!./perl

BEGIN {
    chdir 't' if -d 't';
    $^INCLUDE_PATH = @( '../lib' );
}

print "1..3\n";

use SelectSaver;

open(my $foo_fh, ">", "foo-$^PID") || die;

print "ok 1\n";
do {
    my $saver = SelectSaver->new($foo_fh);
    print "foo\n";
};

# Get data written to file
open($foo_fh, "<", "foo-$^PID") || die;
chomp(my $foo = ~< $foo_fh);
close $foo_fh;
unlink "foo-$^PID";

print "ok 2\n" if $foo eq "foo";

print "ok 3\n";
