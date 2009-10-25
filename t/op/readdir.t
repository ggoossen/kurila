#!./perl

eval 'opendir(NOSUCH, "no/such/directory");'
if ($^EVAL_ERROR) { print: $^STDOUT, "1..0\n"; exit; }

print: $^STDOUT, "1..11\n"

for my $i (1..2000)
    my $op_dh
    opendir: $op_dh, "op" or die: "can't opendir: $^OS_ERROR"
# should auto-closedir() here


my $op_dh
if ((opendir: $op_dh, "op")) { print: $^STDOUT, "ok 1\n"; } else { print: $^STDOUT, "not ok 1\n"; }
our @D = grep:  {m/^[^\.].*\.t$/i }, (@:  (readdir: $op_dh))
closedir: $op_dh

open: my $man, "<", "../MANIFEST" or die: "Can't open ../MANIFEST: $^OS_ERROR"
my $expect
while (~< $man)
    ++$expect if m!^t/op/[^/]+\t!

my (@: $min, $max) = @: $expect - 10, $expect + 10
if ((nelems @D) +> $min && (nelems @D) +< $max) { print: $^STDOUT, "ok 2\n"; }else
    printf: $^STDOUT, "not ok 2 # counting op/*.t, expect $min < \%d < $max files\n"
            scalar nelems @D


our @R = sort: @D
our @G = sort: glob: "op/*.t"
@G = sort: (glob: ":op:*.t") if $^OS_NAME eq 'MacOS'
if (@G[0] =~ m#.*\](\w+\.t)#i)
    # grep is to convert filespecs returned from glob under VMS to format
    # identical to that returned by readdir
    @G = grep:  {s#.*\](\w+\.t).*#op/$1#i }, @: (glob: "op/*.t")

while (@R && @G && @G[0] eq ($^OS_NAME eq 'MacOS' ?? ':op:' !! 'op/').@R[0])
    shift: @R
    shift: @G

if ((nelems @R) == 0 && (nelems @G) == 0)
    print: $^STDOUT, "ok 3\n"
else
    print: $^STDOUT, "not ok 3\n"


our ($fh, @fh, %fh)
if ((opendir: $fh, "op")) { print: $^STDOUT, "ok 4\n"; } else { print: $^STDOUT, "not ok 4\n"; }
if ((ref: $fh) eq 'GLOB') { print: $^STDOUT, "ok 5\n"; } else { print: $^STDOUT, "not ok 5\n"; }
if ((opendir: @fh[+0], "op")) { print: $^STDOUT, "ok 6\n"; } else { print: $^STDOUT, "not ok 6\n"; }
if ((ref: @fh[0]) eq 'GLOB') { print: $^STDOUT, "ok 7\n"; } else { print: $^STDOUT, "not ok 7\n"; }
if ((opendir: %fh{+abc}, "op")) { print: $^STDOUT, "ok 8\n"; } else { print: $^STDOUT, "not ok 8\n"; }
if ((ref: %fh{?abc}) eq 'GLOB') { print: $^STDOUT, "ok 9\n"; } else { print: $^STDOUT, "not ok 9\n"; }
if (not $fh \== @fh[0]) { print: $^STDOUT, "ok 10\n"; } else { print: $^STDOUT, "not ok 10\n"; }
if (not $fh \== %fh{?abc}) { print: $^STDOUT, "ok 11\n"; } else { print: $^STDOUT, "not ok 11\n"; }

# See that perl does not segfault upon readdir($x="."); 
# http://rt.perl.org/rt3/Ticket/Display.html?id=68182
try
    my $x = "."
    my @files = readdir: $x
print: $^STDOUT, "ok 12\n"
