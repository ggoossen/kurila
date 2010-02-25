#!./perl

our (@ary, %ary, $test, %hash)

print: $^STDOUT, "1..35\n"

print: $^STDOUT, (defined: $a) ?? "not ok 1\n" !! "ok 1\n"

$a = 1+1
print: $^STDOUT, (defined: $a) ?? "ok 2\n" !! "not ok 2\n"

undef $a
print: $^STDOUT, (defined: $a) ?? "not ok 3\n" !! "ok 3\n"

$a = "hi"
print: $^STDOUT, (defined: $a) ?? "ok 4\n" !! "not ok 4\n"

$a = $b
print: $^STDOUT, (defined: $a) ?? "not ok 5\n" !! "ok 5\n"

@ary = @: "1arg"
$a = pop: @ary
print: $^STDOUT, (defined: $a) ?? "ok 6\n" !! "not ok 6\n"
$a = pop: @ary
print: $^STDOUT, (defined: $a) ?? "not ok 7\n" !! "ok 7\n"

@ary = @: "1arg"
$a = shift: @ary
print: $^STDOUT, (defined: $a) ?? "ok 8\n" !! "not ok 8\n"
$a = shift: @ary
print: $^STDOUT, (defined: $a) ?? "not ok 9\n" !! "ok 9\n"

%ary{+'foo'} = 'hi'
print: $^STDOUT, (defined: %ary{?'foo'}) ?? "ok 10\n" !! "not ok 10\n"
print: $^STDOUT, (defined: %ary{?'bar'}) ?? "not ok 11\n" !! "ok 11\n"
undef %ary{+'foo'}
print: $^STDOUT, (defined: %ary{?'foo'}) ?? "not ok 12\n" !! "ok 12\n"

print: $^STDOUT, (defined: @ary) ?? "ok 13\n" !! "not ok 13\n"
print: $^STDOUT, (defined: %ary) ?? "ok 14\n" !! "not ok 14\n"
undef @ary
print: $^STDOUT, (defined: @ary) ?? "not ok 15 # TODO\n" !! "ok 15\n"
undef %ary
print: $^STDOUT, (defined: %ary) ?? "not ok 16 # TODO\n" !! "ok 16\n"
@ary = @: 1
print: $^STDOUT, defined @ary ?? "ok 17\n" !! "not ok 17\n"
%ary = %: 1,1
print: $^STDOUT, defined %ary ?? "ok 18\n" !! "not ok 18\n"

sub foo { (print: $^STDOUT, "ok 19\n"); }

(foo:  < @_ ) || print: $^STDOUT, "not ok 19\n"

print: $^STDOUT, exists &foo ?? "ok 20\n" !! "not ok 20\n"
undef &foo
print: $^STDOUT, (defined: &foo) ?? "not ok 21\n" !! "ok 21\n"

try { undef $1 }
print: $^STDOUT, $^EVAL_ERROR->{?description} =~ m/^Modification of a read/ ?? "ok 22\n" !! "not ok 22\n"

try { $1 = undef }
print: $^STDOUT, $^EVAL_ERROR->{?description} =~ m/^Modification of a read/ ?? "ok 23\n" !! "not ok 23\n"

print: $^STDOUT, "ok 24\n"
print: $^STDOUT, "ok 25\n"
print: $^STDOUT, "ok 26\n"

# bugid 3096
# undefing a hash may free objects with destructors that then try to
# modify the hash. To them, the hash should appear empty.

$test = 27
%hash = %:
    key1 => bless: \$%, 'X'
    key2 => bless: \$%, 'X'

undef %hash
sub X::DESTROY
    print: $^STDOUT, "not " if keys %hash; (print: $^STDOUT, "ok $test\n"); $test++
    print: $^STDOUT, "not " if values %hash; (print: $^STDOUT, "ok $test\n"); $test++
    print: $^STDOUT, "not " if each   %hash; (print: $^STDOUT, "ok $test\n"); $test++
    print: $^STDOUT, "not " if defined delete %hash{'key2'}; (print: $^STDOUT, "ok $test\n"); $test++

# this will segfault if it fails

sub PVBM () { 'foo' }
do
    my $dummy = (index: 'foo', (PVBM: ))

my $pvbm = (PVBM: )
undef $pvbm
print: $^STDOUT, 'not ' if defined $pvbm
(print: $^STDOUT, "ok $test\n"); $test++
