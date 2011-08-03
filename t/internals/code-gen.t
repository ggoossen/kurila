#!./perl

use strict;
use warnings;
use Config;

require "test.pl";

if ($Config{ccflags} !~ m/\bDDEBUGGING\b/) {
    skip_all("requires -DDEBUGGING");
}

$/ = undef;
my @tests = split m/####\n/, <DATA>;

plan(scalar(@tests));

for (@tests) {
    my ($prog, $expect) = split m/----\n/, $_;
    test_prog($prog, $expect);
}

sub test_prog {
    my ($prog, $expect) = @_;
    my $prog_output = runperl( prog => $prog, switches => ['-DGq'], stderr => 1);
    my @result = split m/\n/, $prog_output;
    if ($result[0] !~ m/Instructions of codeseq/) {
        diag("PROG:\n$prog\n");
        return ok(0, "Unpected output header: $result[0]");
    }
    shift @result;

    for (@result) {
        s/^0x[\w\d]+://;
    }
    while ($result[-1] =~ m/ ^ \s+ [(] finished [)] \s* $ /x) {
        pop @result;
    }

    my @expect_lines = split m/\n/, $expect;

    my $linenr = 0;
    for my $expect_line (@expect_lines) {
        my $got = shift @result;
        $linenr++;
        $expect_line =~ s/\s+/\\s+/g; # make expectation whitespace insensitive
        if ($got !~ m/^$expect_line\s*$/) {
            diag("PROG:\n$prog\n");
            diag("RESULT:\n$prog_output");
            diag("EXPECTED:\n$expect");
            return ok(0, "Incorrect line $linenr output got '$got' expected '$expect_line'");
        }
    }

    if (@result) {
        diag("PROG:\n$prog\n");
        diag("RESULT:\n$prog_output");
        diag("EXPECTED:\n$expect");
        return ok(0, "Addidional instructions found");
    }

    return ok(1);
}

__DATA__
print $ARGV[0]
----
    enter
    nextstate
    pushmark
    aelemfast
    print
    leave
    instr_end
####
while ($ARGV[0]) {
   print $ARGV[0];
}
----
    enter
    nextstate
    enterloop    redo=label1  next=label2  last=label3
label5:
    aelemfast
    instr_cond_jump label4
label1:
    nextstate
    pushmark
    aelemfast
    print
label2:
    unstack
    instr_jump label5
label4:
    leaveloop
label3:
    leave
    instr_end
####
for (@ARGV) {
    print $_;
}
----
    enter
    nextstate
    pushmark
    gv
    rv2av
    gv
    enteriter        redo=label1 next=label2 last=label3
label5:
    iter
    instr_cond_jump      label4
label1:
    nextstate
    pushmark
    gvsv
    print
label2:
    unstack
    instr_jump   label5
label4:
    leaveloop
label3:
    leave
    instr_end
####
{
    print $ARGV[0];
}
----
    enter
    nextstate
    enterloop      redo=label1  next=label2 last=label3
label1:
    nextstate
    pushmark
    aelemfast
    print
label2:
   leaveloop
label3:
   leave
   instr_end
####
for (1..4) {
    print $ARGV[$_];
}
----
    enter
    nextstate
    pushmark
    const
    const
    gv
    enteriter        redo=label1 next=label2 last=label3
label5:
    iter
    instr_cond_jump    label4
label1:
    nextstate
    pushmark
    gv
    rv2av
    gvsv
    aelem
    print
label2:
    unstack
    instr_jump label5
label4:
    leaveloop
label3:
    leave
    instr_end
####
$ARGV[0] ? $ARGV[1] : $ARGV[2]
----
    enter
    nextstate
    aelemfast
    cond_expr  label1
    aelemfast
    instr_jump label2
label1:
    aelemfast
label2:
    leave
    instr_end
####
$ARGV[0] or $ARGV[1]
----
    enter
    nextstate
    aelemfast
    or         label1
    aelemfast
label1:
    leave
    instr_end
####
eval { $ARGV[0] }
----
    enter
    nextstate
    entertry    label1
    nextstate
    aelemfast
    leavetry
label1:
    leave
    instr_end
####
{ last }
----
    enter
    nextstate
    enterloop  redo=label1     next=label2     last=label3
label1:
    nextstate
    last
label2:
    leaveloop
label3:
    leave
    instr_end
####
shift @ARGV while @ARGV
----
    enter
    nextstate
    enter
    instr_jump label1
label2:
    gv
    rv2av
    pop
label1:
    gv
    rv2av
    or label2
    leave
    leave
    instr_end
####
do { shift @ARGV } while @ARGV
----
    enter
    nextstate
    enter
label1:
    gv
    rv2av
    pop
    gv
    rv2av
    or label1
    leave
    leave
    instr_end
####
$a..$b
----
    enter
    nextstate
    range      label1
    gvsv
    flip
label1:
    gvsv
    flop
    leave
    instr_end
####
for (@ARGV) { } continue { $ARGV[0] }
----
    enter
    nextstate
    pushmark
    gv
    rv2av
    gv
    enteriter  redo=label1     next=label2     last=label3
label5:
    iter
    instr_cond_jump    label4
label1:
    stub
label2:
    unstack
    aelemfast
    instr_jump label5
label4:
    leaveloop
label3:
    leave
    instr_end
####
# stringify with concat
"b$a"
----
    enter
    nextstate
    const
    gvsv
    concat
    leave
    instr_end
####
# hash in boolean context
%h and 1
----
    enter
    nextstate
    gv
    rv2av
    boolkeys
    and         label1
    const
label1:
    leave
    instr_end
####
# range in list context
@a = 1..$a
----
    enter
    nextstate
    pushmark
    const
    gvsv
    flop
    pushmark
    gv
    rv2av
    aassign
    leave
    instr_end
####
# constant folded range
@a = 1..4
----
    enter
    nextstate
    pushmark
    instr_const_list
    pushmark
    gv
    rv2av
    aassign
    leave
    instr_end
####
# and/or/dor branching
1+1 and $a
----
    enter
    nextstate
    gvsv
    leave
    instr_end
####
1 ? $a : $b
----
    enter
    nextstate
    gvsv
    leave
    instr_end
####
if ($a) {
    1 while 1
}
----
    enter
    nextstate
    gvsv
    and	label1
    enter
    instr_jump	label2
label3:
    const
label2:
    const
    or	label3
    leave
label1:
    leave
    instr_end
