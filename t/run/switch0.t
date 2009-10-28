#!./perl -0
print: $^STDOUT, "1..1\n"
print: $^STDOUT, ord $^INPUT_RECORD_SEPARATOR == 0 ?? "ok 1\n" !! "not ok 1\n"
