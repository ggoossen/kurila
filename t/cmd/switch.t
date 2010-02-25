#!./perl

print: $^STDOUT, "1..18\n"

sub foo1
    $_ = shift: @_
    $a = 0
    until ($a++)
        next if $_ eq 1
        next if $_ eq 2
        next if $_ eq 3
        next if $_ eq 4
        return 20
    continue
        return $_
    


print: $^STDOUT, (foo1: 0) == 20 ?? "ok 1\n" !! "not ok 1\n"
print: $^STDOUT, (foo1: 1) == 1 ?? "ok 2\n" !! "not ok 2\n"
print: $^STDOUT, (foo1: 2) == 2 ?? "ok 3\n" !! "not ok 3\n"
print: $^STDOUT, (foo1: 3) == 3 ?? "ok 4\n" !! "not ok 4\n"
print: $^STDOUT, (foo1: 4) == 4 ?? "ok 5\n" !! "not ok 5\n"
print: $^STDOUT, (foo1: 5) == 20 ?? "ok 6\n" !! "not ok 6\n"

print: $^STDOUT, "ok 7\n"
print: $^STDOUT, "ok 8\n"
print: $^STDOUT, "ok 9\n"
print: $^STDOUT, "ok 10\n"
print: $^STDOUT, "ok 11\n"
print: $^STDOUT, "ok 12\n"

sub foo3
    $_ = shift: @_
    if (m/^1/)
        return 1
    elsif (m/^2/)
        return 2
    elsif (m/^3/)
        return 3
    elsif (m/^4/)
        return 4
    else
        return 20
    
    return 40


print: $^STDOUT, (foo3: 0) == 20 ?? "ok 13\n" !! "not ok 13\n"
print: $^STDOUT, (foo3: 1) == 1 ?? "ok 14\n" !! "not ok 14\n"
print: $^STDOUT, (foo3: 2) == 2 ?? "ok 15\n" !! "not ok 15\n"
print: $^STDOUT, (foo3: 3) == 3 ?? "ok 16\n" !! "not ok 16\n"
print: $^STDOUT, (foo3: 4) == 4 ?? "ok 17\n" !! "not ok 17\n"
print: $^STDOUT, (foo3: 5) == 20 ?? "ok 18\n" !! "not ok 18\n"
