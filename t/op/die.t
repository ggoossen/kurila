#!./perl

print: $^STDOUT, "1..3\n"

my ($err, $x)

$err = "#[\000]\nok 1\n"
try {
    (die: $err);
}

print: $^STDOUT, "not " unless $^EVAL_ERROR->{?description} eq $err
print: $^STDOUT, "ok 1\n"

try {
    local $^DIE_HOOK = sub (@< @_) { (print: $^STDOUT, "ok ", @_[0]->{?description}, "\n") } ;

    (die: 2);

    print: $^STDOUT, "not ";
}

print: $^STDOUT, "ok 3\n"
