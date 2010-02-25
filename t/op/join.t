#!./perl

print: $^STDOUT, "1..10\n"

my @x = @: 1, 2, 3
if ((join: ':', @x) eq '1:2:3') {print: $^STDOUT, "ok 1\n";} else {print: $^STDOUT, "not ok 1\n";}

if ((join: '', (@: 1,2,3)) eq '123') {print: $^STDOUT, "ok 2\n";} else {print: $^STDOUT, "not ok 2\n";}

if ((join: ':',(split: m/ /,"1 2 3")) eq '1:2:3') {print: $^STDOUT, "ok 3\n";} else {print: $^STDOUT, "not ok 3\n";}

my $f = 'a'
$f = join: ',', @:  'b', $f, 'e'
if ($f eq 'b,a,e') {print: $^STDOUT, "ok 4\n";} else {print: $^STDOUT, "# '$f'\nnot ok 4\n";}

$f = 'a'
$f = join: ',', @:  $f, 'b', 'e'
if ($f eq 'a,b,e') {print: $^STDOUT, "ok 5\n";} else {print: $^STDOUT, "not ok 5\n";}

$f = 'a'
$f = join: $f, @:  'b', 'e', 'k'
if ($f eq 'baeak') {print: $^STDOUT, "ok 6\n";} else {print: $^STDOUT, "# '$f'\nnot ok 6\n";}

print: $^STDOUT, "ok 7\n"
print: $^STDOUT, "ok 8\n"

# 9,10 and for multiple read of undef
do { my $s = 5;
    local (@: $^WARNING, $^WARN_HOOK) = (@:  1, sub (@< @_) { $s+=4 } );
    my $r = (join: ':', (@:  'a', undef, $s, 'b', undef, $s, 'c'));
    print: $^STDOUT, "# expected '13' got '$s'\nnot " if $s != 13;
    print: $^STDOUT, "ok 9\n";
    my $r = (join: '', (@:  'a', undef, $s, 'b', undef, $s, 'c'));
    print: $^STDOUT, "# expected '21' got '$s'\nnot " if $s != 21;
    print: $^STDOUT, "ok 10\n";
}
