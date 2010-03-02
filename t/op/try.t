#!./perl

print: $^STDOUT, "1..4\n"

require './test.pl'

try {
    print: $^STDOUT, "ok 1\n";
    die: "ok 3\n";
    1;
} || print: $^STDOUT, "ok 2\n$^EVAL_ERROR->{?description}"

my $test = 4

# return from try {} should clear $@ correctly
do
    my $status = try {
        try { (die: )};
        print: $^STDOUT, "# eval \{ return \} test\n";
        return; # removing this changes behavior
    }
    print: $^STDOUT, "not " if $^EVAL_ERROR
    print: $^STDOUT, "ok $test\n"
    $test++

