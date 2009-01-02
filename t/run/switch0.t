#!./perl -0
print "1..1\n";
print ord $^INPUT_RECORD_SEPARATOR == 0 ?? "ok 1\n" !! "not ok 1\n";
