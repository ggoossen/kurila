#!./perl

use Config

BEGIN 
    if (not (config_value: 'd_readdir'))
        print: $^STDOUT, "1..0 # Skip: readdir() not available\n"
        exit 0
    


iohandle::output_autoflush: $^STDERR, 1
iohandle::output_autoflush: $^STDOUT, 1

use IO::Dir < qw(DIR_UNLINK)

my $tcount = 0

sub ok
    $tcount++
    my $not = @_[0] ?? '' !! 'not '
    print: $^STDOUT, "$($not)ok $tcount\n"


print: $^STDOUT, "1..5\n"

my $DIR = $^OS_NAME eq 'MacOS' ?? ":" !! "."

my $dot = IO::Dir->new:  $DIR
ok: (defined: $dot)

my @a = sort: glob: "*"
my $first
loop { $first = ($dot->read: ) } while (defined: $first) && $first =~ m/^\./
ok:  (grep: { $_ eq $first }, @a) 

my @b = sort:  (@: $first, (< (grep: {m/^[^.]/}, ($dot->read_all: ))))
ok: (join: "\0", @a) eq (join: "\0", @b)

$dot->rewind: 
my @c = sort: grep: {m/^[^.]/}, $dot->read_all: 
ok: (join: "\0", @b) eq (join: "\0", @c)

$dot->close: 
$dot->rewind: 
ok: !(defined: ($dot->read: ))

(open: my $fh,'>', 'X') || die: "Can't create x"
print: $fh, "X"
close: $fh or die: "Can't close: $^OS_ERROR"

