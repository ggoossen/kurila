#!./perl

sub foo
    if (@_[0] == 1)
        1
    elsif (@_[0] == 2)
        2
    elsif (@_[0] == 3)
        3
    else
        4
    


print: $^STDOUT, "1..4\n"

our $x
if (($x = (foo: 1)) == 1) {print: $^STDOUT, "ok 1\n";} else {print: $^STDOUT, "not ok 1 '$x'\n";}
if (($x = (foo: 2)) == 2) {print: $^STDOUT, "ok 2\n";} else {print: $^STDOUT, "not ok 2 '$x'\n";}
if (($x = (foo: 3)) == 3) {print: $^STDOUT, "ok 3\n";} else {print: $^STDOUT, "not ok 3 '$x'\n";}
if (($x = (foo: 4)) == 4) {print: $^STDOUT, "ok 4\n";} else {print: $^STDOUT, "not ok 4 '$x'\n";}
