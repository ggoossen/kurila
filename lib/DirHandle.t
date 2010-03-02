#!./perl

use Config

BEGIN 
    if (not (config_value: 'd_readdir'))
        print: $^STDOUT, "1..0\n"
        exit 0
    


use DirHandle
require './test.pl'

plan: 5

my $dot = DirHandle->new: $^OS_NAME eq 'MacOS' ?? ':' !! '.'

ok: (defined: $dot)

my @a = sort: glob: "*"
my $first
loop { $first = ($dot->readdir: ) } while (defined: $first) && $first =~ m/^\./
ok: (grep: { $_ eq $first }, @a)

my @b = sort:  (@: $first, (< (grep: {m/^[^.]/}, ($dot->readdirs: ))))
is: (join: "\0", @a), (join: "\0", @b)

$dot->rewind: 
my @c = sort: grep: {m/^[^.]/}, $dot->readdirs: 
is: (join: "\0", @b), (join: "\0", @c)

$dot->close: 
$dot->rewind: 
ok: !(defined: ($dot->readdir: ))
