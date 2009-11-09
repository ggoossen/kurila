#!./perl

use strict;
use warnings;

require "test.pl";

$/ = undef;
my @tests = split m/####\n/, <DATA>;

for (@tests) {
    my ($prog, $expect) = split m/----\n/, $_;
    test_prog($prog, $expect);
}

sub test_prog {
    my ($prog, $expect) = @_;
    my $prog_output = runperl( prog => $prog, switches => ['-DGq'], stderr => 1);
    my @result = split m/\n/, $prog_output;
    if ($result[0] !~ m/Instructions of codeseq/) {
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
    null
label2:
    unstack
    instr_jump label5
label4:
    leaveloop
label3:
    leave
####
for (@ARGV) {
    print $_;
}
----
    enter
    nextstate
    pushmark
    pushmark
    gv
    rv2av
    gv
    list
    enteriter
label2:
    iter
    instr_cond_jump      label1
    nextstate
    pushmark
    gvsv
    print
    null
    instr_jump   label2
label1:
    leave
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
    null
label2:
   leaveloop
label3:
   leave
####
for (1..4) {
    print $ARGV[$_];
}
----
    enter
    nextstate
    pushmark
    pushmark
    const
    const
    gv
    list
    enteriter
label2:
    iter
    instr_cond_jump    label1
    nextstate
    pushmark
    gv
    rv2av
    gvsv
    aelem
    print
    null
    instr_jump label2
label1:
    leave
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
    gv
    rv2av
    const
    aelem
label2:
    leave
####
$ARGV[0] or $ARGV[1]
----
    enter
    nextstate
    gv
    rv2av
    const
    aelem
    or         label1
    aelemfast
label1:
    leave
####
eval { $ARGV[0] }
----
    enter
    nextstate
    entertry    label1
    nextstate
    aelemfast
    null
    leavetry
label1:
    leave
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
####
shift @ARGV while @ARGV
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

