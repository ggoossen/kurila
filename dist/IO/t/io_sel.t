#!./perl -w

iohandle::output_autoflush: $^STDERR, 1
iohandle::output_autoflush: $^STDOUT, 1

print: $^STDOUT, "1..21\n"

use IO::Select v1.09

my $sel = IO::Select->new: $^STDIN
($sel->add: 4, 5) == 2 or print: $^STDOUT, "not "
print: $^STDOUT, "ok 1\n"

($sel->add: \(@: $^STDOUT, 'foo')) == 1 or print: $^STDOUT, "not "
print: $^STDOUT, "ok 2\n"

my @handles = $sel->handles
print: $^STDOUT, "not " unless $sel->count == 4 && (nelems @handles) == 4
print: $^STDOUT, "ok 3\n"
#print $sel->as_string, "\n";

($sel->remove: $^STDIN) == 1 or print: $^STDOUT, "not "
print: $^STDOUT, "ok 4\n"

($sel->remove: $^STDIN, 5, 6) == 1  # two of there are not present
    or print: $^STDOUT, "not "
print: $^STDOUT, "ok 5\n"

print: $^STDOUT, "not " unless $sel->count == 2
print: $^STDOUT, "ok 6\n"
#print $sel->as_string, "\n";

$sel->remove: 1, 4
print: $^STDOUT, "not " unless $sel->count == 0 && !defined: $sel->bits
print: $^STDOUT, "ok 7\n"

$sel = IO::Select->new
print: $^STDOUT, "not " unless $sel->count == 0 && !defined: $sel->bits
print: $^STDOUT, "ok 8\n"

$sel->remove: \(@: $^STDOUT, 5)
print: $^STDOUT, "not " unless $sel->count == 0 && !defined: $sel->bits
print: $^STDOUT, "ok 9\n"

my @a = $sel->can_read  # should return imediately
print: $^STDOUT, "not " unless (nelems @a) == 0
print: $^STDOUT, "ok 10\n"

# we assume that we can write to STDOUT :-)
$sel->add: \(@: $^STDOUT, "ok 12\n")

@a = $sel->can_write
print: $^STDOUT, "not " unless (nelems @a) == 1
print: $^STDOUT, "ok 11\n"

my(@: $fd, $msg) =  (shift @a)->@
print: $fd, $msg

$sel->add: $^STDOUT  # update

@a = IO::Select::select: undef, $sel, undef, 1
print: $^STDOUT, "not " unless (nelems @a) == 3
print: $^STDOUT, "ok 13\n"

my (@: $r, $w, $e) =  @a

print: $^STDOUT, "not " unless (nelems $r->@) == 0 && (nelems $w->@) == 1 && (nelems $e->@) == 0
print: $^STDOUT, "ok 14\n"

$fd = $w->[0]
print: $fd, "ok 15\n"

# Test new exists() method
$sel->exists: $^STDIN and print: $^STDOUT, "not "
print: $^STDOUT, "ok 16\n"

(($sel->exists: 0) || ($sel->exists: \(@: $^STDERR))) and print: $^STDOUT, "not "
print: $^STDOUT, "ok 17\n"

$fd = $sel->exists: $^STDOUT
if ($fd)
    print: $fd, "ok 18\n"
else
    print: $^STDOUT, "not ok 18\n"


$fd = $sel->exists: \(@: 1, 'foo')
if ($fd)
    print: $fd, "ok 19\n"
else
    print: $^STDOUT, "not ok 19\n"


# Try self clearing
$sel->add: 5,6,7,8,9,10
print: $^STDOUT, "not " unless $sel->count == 7
print: $^STDOUT, "ok 20\n"

$sel->remove:  <$sel->handles
print: $^STDOUT, "not " unless $sel->count == 0 && !defined: $sel->bits
print: $^STDOUT, "ok 21\n"
