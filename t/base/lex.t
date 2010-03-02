#!./perl

print: $^STDOUT, "1..55\n"

my $x = 'x'

print: $^STDOUT, "#1	:$x: eq :x:\n"
if ($x eq 'x') {print: $^STDOUT, "ok 1\n";} else {print: $^STDOUT, "not ok 1\n";}

$x = ''

if ($x eq '') {print: $^STDOUT, "ok 2\n";} else {print: $^STDOUT, "not ok 2\n";}

our @x
$x = ((nelems @x)-1)

if ($x eq '-1') {print: $^STDOUT, "ok 3\n";} else {print: $^STDOUT, "not ok 3\n";}

$x = '\\' # ';

if ((length: $x) == 2) {print: $^STDOUT, "ok 4\n";} else {print: $^STDOUT, "not ok 4\n";}

eval 'while (0) {
    print: $^STDOUT, "foo\n";
}
m/^/ && (print: $^STDOUT, "ok 5\n");
'

our ($foo, %foo, $bar, $bar, @ary, $A, $X, @X, $N)

eval '%foo{+1} / 1;'
if (!$^EVAL_ERROR) {print: $^STDOUT, "ok 6\n";} else {print: $^STDOUT, "not ok 6 $^EVAL_ERROR\n";}

eval '$foo = 123+123.4+123e4+123.4E5+123.4e+5+.12;'

$foo = int: $foo * 100 + .5
if ($foo eq 2591024652) {print: $^STDOUT, "ok 7\n";} else {print: $^STDOUT, "not ok 7 :$foo:\n";}

print: $^STDOUT, <<'EOF'
ok 8
EOF

$foo = 'ok 9';
print: $^STDOUT, <<EOF;
$foo
EOF

eval <<\EOE, (print: $^STDOUT, $^EVAL_ERROR);
print: $^STDOUT, <<'EOF';
ok 10
EOF

$foo = 'ok 11';
print: $^STDOUT, <<EOF;
$foo
EOF
EOE

print: $^STDOUT, <<'EOS' . <<\EOF;
ok 12 - make sure single quotes are honored \nnot ok
EOS
ok 13
EOF

print: $^STDOUT, qq/ok 14\n/;
print: $^STDOUT, qq(ok 15\n);

print: $^STDOUT, qq
         [ok 16\n]

print: $^STDOUT, q<ok 17
>;

print: $^STDOUT, <<;   # Yow!
ok 18

# previous line intentionally left blank.

print: $^STDOUT, <<E1 eq "foo\n\n" ?? "ok 19\n" !! "not ok 19\n";
$( <<E2
foo
E2
           )
E1

print: $^STDOUT, <<E1 eq "foo\n\n" ?? "ok 20\n" !! "not ok 20\n";
$(
           <<E2
foo
E2
           )
E1

do
    $foo = 'FOO'
    $bar = 'BAR'
    %foo{+$bar} = 'BAZ'
    @ary[+0] = 'ABC'
;

print: $^STDOUT, "%foo{?$bar}" eq "BAZ" ?? "ok 21\n" !! "not ok 21\n";

print: $^STDOUT, "$($foo)\{$bar\}" eq "FOO\{BAR\}" ?? "ok 22\n" !! "not ok 22\n";
print: $^STDOUT, "$(%foo{?$bar})" eq "BAZ" ?? "ok 23\n" !! "not ok 23\n";

#print "FOO:" =~ m/$foo[:]/ ? "ok 24\n" : "not ok 24\n";
print: $^STDOUT, "ok 24\n";
print: $^STDOUT, "ABC" =~ m/^@ary[$A]$/ ?? "ok 25\n" !! "not ok 25\n";
#print "FOOZ" =~ m/^$foo[$A-Z]$/ ? "ok 26\n" : "not ok 26\n";
print: $^STDOUT, "ok 26\n";

# MJD 19980425
(@: $X, @< @X) =  qw(a b c d);
print: $^STDOUT, "d" =~ m/^@X[-1]$/ ?? "ok 27\n" !! "not ok 27\n";
print: $^STDOUT, "a1" !~ m/^@X[-1]$/ ?? "ok 28\n" !! "not ok 28\n";

(print: $^STDOUT, ((q{{\{\(}} . q{{\)\}}}) eq '{\{\(}} . q{{\)\}}') ?? "ok 29\n" !! "not ok 29\n");

$foo = "not ok 30\n";
$foo =~ s/^not /$((substr: <<EOF, 0, 0))/;
  Ignored
EOF
(print: $^STDOUT, $foo);

# Tests for new extended control-character variables
# MJD 19990227

do
    print: $^STDOUT, "ok 31\n"
    print: $^STDOUT, "ok 32\n"
    print: $^STDOUT, "ok 33\n"
    print: $^STDOUT, "ok 34\n"
    print: $^STDOUT, "ok 35\n"
    print: $^STDOUT, "ok 36\n"
    print: $^STDOUT, "ok 37\n"
    print: $^STDOUT, "ok 38\n"

    # Now let's make sure that caret variables are all forced into the main package.
    package Someother;
    $^RE_TRIE_MAXBUF = 'Someother 2'
    $^EMERGENCY_MEMORY = 'Someother 3'
    package main;
    print: $^STDOUT, "ok 39\n"
    print: $^STDOUT, "not " unless $^RE_TRIE_MAXBUF eq 'Someother 2'
    print: $^STDOUT, "ok 40\n"
    print: $^STDOUT, "not " unless $^EMERGENCY_MEMORY eq 'Someother 3'
    print: $^STDOUT, "ok 41\n"


;

# see if eval '', s///e, and heredocs mix

sub T($where, $num)
    my (@: $p,$f,$l) =@:  caller
    print: $^STDOUT, "# $p:$f:$l vs /$where/\nnot " unless "$p:$f:$l" =~ m/$where/
    print: $^STDOUT, "ok $num\n"


my $test = 42;

do {
# line 42 "plink"
    local $_ = "not ok ";
    eval q{
	s/^not /{<<EOT}/ and T '^main:\(eval \d+\):2$', $test++;
# fuggedaboudit
EOT
        print $_, $test++, "\n";
	T('^main:\(eval \d+\):6$', $test++);
# line 1 "plunk"
	T('^main:plunk:1$', $test++);
    };
    print: $^STDOUT, "not ok $test # TODO heredoc inside quoted construct\n" if $^EVAL_ERROR; $test++;
    T: '^main:plink:53$', $test++;
    print: $^STDOUT, "ok 44\nok 45\nok 46\n";
}
#line 179 "lex.t"

# tests 47--51 start here
# tests for new array interpolation semantics:
# arrays now *always* interpolate into "..." strings.
# 20000522 MJD (mjd@plover.com)
do
    my $test = 47
    our (@nosuch, @a, @example)
    (eval: q(">$(join: ' ', < @nosuch)<" eq "><")) || print: $^STDOUT, "# $^EVAL_ERROR", "not "
    print: $^STDOUT, "ok $test\n"
    ++$test

    # Let's make sure that normal array interpolation still works right
    # For some reason, this appears not to be tested anywhere else.
    my @a = @: 1,2,3
    print: $^STDOUT,  ((">$((join: ' ',@a))<" eq ">1 2 3<") ?? '' !! 'not '), "ok $test\n"
    ++$test

    # Ditto.
    eval: q{@nosuch = @: 'a', 'b', 'c'; ">$(join: ' ', @nosuch)<" eq ">a b c<"}
        || print: $^STDOUT, "# $^EVAL_ERROR", "not "
    print: $^STDOUT, "ok $test\n"
    ++$test

    # This isn't actually a lex test, but it's testing the same feature
    sub makearray
        my @array = @: 'fish', 'dog', 'carrot'
        *R::crackers = \@array

    eval: q{makearray(); ">$(join: ' ', @R::crackers)<" eq ">fish dog carrot<"}
        || print: $^STDOUT, "# $^EVAL_ERROR", "not "
    print: $^STDOUT, "ok $test\n"
    ++$test


# Tests 52-54
# => should only quote foo::bar if it isn't a real sub. AMS, 20010621

sub xyz::foo { "bar" }
my %str = %:
    foo      => 1
    (xyz::foo: ) => 1
    'xyz::bar' => 1

my $test = 51
print: $^STDOUT, (exists %str{foo}      ?? "" !! "not ")."ok $test\n"; ++$test
print: $^STDOUT, (exists %str{bar}      ?? "" !! "not ")."ok $test\n"; ++$test
print: $^STDOUT, (exists %str{'xyz::bar'} ?? "" !! "not ")."ok $test\n"; ++$test

sub foo::::::bar { (print: $^STDOUT, "ok $test\n"); $test++ }
(foo::::::bar: )

eval "\$x =\x[E2]foo"
if ($^EVAL_ERROR->{description} =~ m/Unrecognized character \\xE2; marked by <-- HERE after \$x =<-- HERE near column 5/) { print: $^STDOUT, "ok $test\n"; } else { print: $^STDOUT, "not ok $test\n"; }
$test++
