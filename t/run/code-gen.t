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

    for my $expect_line (@expect_lines) {
        my $got = shift @result;
        $expect_line =~ s/\s+/\\s+/g; # make expectation whitespace insensitive
        if ($got !~ m/^$expect_line\s*$/) {
            diag("PROG:\n$prog\n");
            diag("RESULT: $prog_output");
            diag("EXPECTED: $expect");
            return ok(0, "Incorrect output got '$got' expected '$expect_line'");
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
    enterloop
label2:
    aelemfast
    instr_cond_jump label1
    nextstate
    pushmark
    aelemfast
    print
    null
    unstack
    instr_jump label2
label1:
    leave
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
    null
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

