#!./perl

BEGIN {
    chdir 't' if -d 't';
    $^INCLUDE_PATH = @( '../lib' );
}

print \*STDOUT, "1..3\n";

use SelectSaver;

open(my $foo_fh, ">", "foo-$^PID") || die;

print \*STDOUT, "ok 1\n";
do {
    my $saver = SelectSaver->new($foo_fh);
    print \*STDOUT, "foo\n";
};

# Get data written to file
open($foo_fh, "<", "foo-$^PID") || die;
chomp(my $foo = ~< $foo_fh);
close $foo_fh;
unlink "foo-$^PID";

print \*STDOUT, "ok 2\n" if $foo eq "foo";

print \*STDOUT, "ok 3\n";
