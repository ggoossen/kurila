#!./perl

# ** DO NOT ADD ANY MORE TESTS HERE **
# Instead, put the test in the appropriate test file and use the
# fresh_perl_is()/fresh_perl_like() functions in t/test.pl.

# This is for tests that used to abnormally cause segfaults, and other nasty
# errors that might kill the interpreter and for some reason you can't
# use an eval().

BEGIN
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @: '../lib'

BEGIN
    require './test.pl'	# for which_perl() etc

my $Perl = (which_perl: )

$^OUTPUT_AUTOFLUSH=1

my @prgs = $@
while( ~< $^DATA)
    if(m/^#{8,}\s*(.*)/)
        push: @prgs, \@: '', $1
    else
        @prgs[-1]->[0] .= $_
    

plan: tests => scalar nelems @prgs

foreach my $prog ( @prgs)
    my(@: $raw_prog, $name) =  $prog->@

    my $switch
    if ($raw_prog =~ s/^\s*(-\w.*)\n//)
        $switch = $1
    

    my(@: $prog,?$expected) =  split: m/\nEXPECT\n/, $raw_prog
    $prog .= "\n"
    $expected = '' unless defined $expected

    if ($prog =~ m/^\# SKIP: (.+)/m)
        if (eval $1)
            ok: 1, "Skip: $1"
            next

    $expected =~ s/\n+$//

    fresh_perl_is: $prog, $expected, \(%:  switches => \(@: $switch || '') ), $name


__END__
########
our $cusp = ^~^0 ^^^ (^~^0 >> 1);
use integer;
$^OUTPUT_FIELD_SEPARATOR = " ";
print($^STDOUT, ($cusp - 1) % 8, $cusp % 8, -$cusp % 8, 8 ^|^ (($cusp + 1) % 8 + 7), "!\n");
EXPECT
7 0 0 8 !
########
our $foo=undef; $foo->go;
EXPECT
Can't call method "go" on UNDEF at - line 1 character 21.
########
BEGIN
        {
            "foo";
        }
########
our @array;
@array[+128]=1
########
our $x=0x0eabcd; print $^STDOUT, $x->ref;
EXPECT
Can't locate object method "ref" via package "961485" (perhaps you forgot to load "961485"?) at - line 1 character 36.
########
our $str;
chop ($str .= ~< *DATA);
########
our ($x, $y);
$x=2;$y=3;$x+<$y ?? $x !! $y += 23;print $^STDOUT, $x;
EXPECT
25
########
eval 'sub bar {print $^STDOUT, "In bar"}';
########
our $file;
chop($file = ~< *DATA);
########
package N;
sub new($obj,$n) { bless \$n }
our $aa=N->new(1);
$aa=12345;
print $^STDOUT, $aa;
EXPECT
12345
########
$_="foo";
printf($^STDOUT, "\%s\n", $_);
EXPECT
foo
########
our @a;
push(@a, 1, 2, 3,)
########
quotemeta ""
########
$_="foo";
s/.{1}//s;
print $^STDOUT, $_;
EXPECT
oo
########
BEGIN { die "phooey" }
EXPECT
phooey at - line 1 character 9.
    BEGIN called at - line 1 character 1.
########
BEGIN { 1/0 }
EXPECT
Illegal division by zero at - line 1 character 10.
    BEGIN called at - line 1 character 1.
########
BEGIN { undef = 0 }
EXPECT
Can't assign to undef operator at - line 1 character 9.
BEGIN not safe after errors--compilation aborted at - line 1 character 20.
########
my @a; @a[+2] = 1; for (@a) { $_ = 2 } print $^STDOUT, join(' ', @a) . "\n"
EXPECT
2 2 2
########
# used to attach defelem magic to all immortal values,
# which made restore of local $_ fail.
foo(2+>1);
sub foo
    for ($: @_)
        bar()
sub bar { local $_; }
print $^STDOUT, "ok\n";
EXPECT
ok
########
print $^STDOUT, "ok\n" if ("\0" cmp "\x[FF]") +< 0;
EXPECT
ok
########
open(my $h,"<",$^OS_NAME eq 'MacOS' ?? ':run:fresh_perl.t' !! 'run/fresh_perl.t'); # must be in the 't' directory
stat($h);
print $^STDOUT, "ok\n" if (-e _ and -f _ and -r _);
EXPECT
ok
########
my $a = 'outer';
eval q[ my $a = 'inner'; eval q[ print $^STDOUT, "$a " ] ];
try { my $x = 'peace'; eval q[ print $^STDOUT, "$x\n" ] }
EXPECT
inner peace
########
our $s = 0;
map {#this newline here tickles the bug
     $s += $_}, @: 1,2,4;
print $^STDOUT, "eat flaming death\n" unless ($s == 7);
########
BEGIN { @ARGV = qw(a b c d e) }
BEGIN { print $^STDOUT, "argv <$(join ' ', @ARGV)>\nbegin <",shift(@ARGV),">\n" }
END { print $^STDOUT, "end <",shift(@ARGV),">\nargv <$(join ' ', @ARGV)>\n" }
INIT { print $^STDOUT, "init <",shift(@ARGV),">\n" }
CHECK { print $^STDOUT, "check <",shift(@ARGV),">\n" }
EXPECT
argv <a b c d e>
begin <a>
check <b>
init <c>
end <d>
argv <e>
########
# TODO
package X;
sub ascalar { my $r; bless \$r }
sub DESTROY { print $^STDOUT, "destroyed\n" };
package main;
*s = X->ascalar();
EXPECT
destroyed
########
# TODO
package X;
sub anarray { bless \$@ }
sub DESTROY { print $^STDOUT, "destroyed\n" };
package main;
*a = X->anarray();
EXPECT
destroyed
########
# TODO
package X;
sub ahash { bless \$% }
sub DESTROY { print $^STDOUT, "destroyed\n" };
package main;
*h = X->ahash();
EXPECT
destroyed
########
# TODO
package X;
sub aclosure { my $x; bless sub { ++$x } }
sub DESTROY { print $^STDOUT, "destroyed\n" };
package main;
*c = X->aclosure;
EXPECT
destroyed
########
# TODO fix trace back of "call_sv"
BEGIN {
  $^OUTPUT_AUTOFLUSH = 1;
  $^WARN_HOOK = sub {
    try { print $^STDOUT, @_[0]->{description} };
    die "bar";
  };
  warn "foo\n";
}
EXPECT
foo
bar at - line 5 character 5.
    main::__ANON__ called at - line 5 character 11.
    BEGIN called at - line 2 character 1.
########
re();
sub re {
    my $re = join '', @: eval 'qr/(??{ $obj->method })/' ;
    $re;
}
EXPECT
########
my $foo = "ZZZ\n";
END { print $^STDOUT, $foo }
EXPECT
ZZZ
########
eval '
my $foo = "ZZZ\n";
END { print $^STDOUT, $foo }
';
EXPECT
ZZZ
########
-w
if (@ARGV) { print $^STDOUT, "" }
else {
  our $x;
  if ($x == 0) { print $^STDOUT, "" } else { print $^STDOUT, $x }
}
EXPECT
Use of uninitialized value $main::x in numeric eq (==) at - line 4 character 10.
########
our $x = sub {};
foo();
sub foo { try { return }; }
print $^STDOUT, "ok\n";
EXPECT
ok
########
print $^STDOUT, < qw(ab a\b a\\b);
EXPECT
aba\ba\\b
########
# lexicals declared after the myeval() definition should not be visible
# within it
our $foo;
sub myeval { eval @_[0] }
$foo = "ok 2\n";
myeval('sub foo { local $foo = "ok 1\n"; print $^STDOUT, $foo; }');
die $^EVAL_ERROR if $^EVAL_ERROR;
foo();
print $^STDOUT, $foo;
EXPECT
ok 1
ok 2
########
# lexicals outside an eval"" should be visible inside subroutine definitions
# within it
eval <<'EOT'; die $^EVAL_ERROR if $^EVAL_ERROR;
do {
    my $X = "ok\n";
    eval 'sub Y { print $^STDOUT, $X }'; die $^EVAL_ERROR if $^EVAL_ERROR;
    Y();
};
EOT
EXPECT
ok
########
# [ID 20001202.002] and change #8066 added 'at -e line 1';
# reversed again as a result of [perl #17763]
die qr(x)
EXPECT
(error description isn't a string) at - line 3 character 1.
########
# David Dyck
# coredump in 5.7.1
close $^STDERR; die;
EXPECT
########
# core dump in 20000716.007
-w
"x" =~ m/(\G?x)?/;
########
# Bug 20010515.004
my @h = 1 .. 10
bad(<@h)
sub bad
   undef @h
   print $^STDOUT, "O"
   for (@_)
       print $^STDOUT, $_
   print $^STDOUT, "K"
EXPECT
O12345678910K
########
# Bug 20010506.041
use utf8;
"abcd\x{1234}" =~ m/(a)(b[c])(d+)?/i and print $^STDOUT, "ok\n";
EXPECT
ok
######## (?{...}) compilation bounces on PL_rs
-0
our $x;
do {
  m/(?{ $x })/;
  # {
};
BEGIN { print $^STDOUT, "ok\n" }
EXPECT
ok
######## scalar ref to file test operator segfaults on 5.6.1 [ID 20011127.155]
# This only happens if the filename is 11 characters or less.
my $foo = \-f "blah";
print $^STDOUT, "ok" if ref $foo && !$foo->$;
EXPECT
ok
######## [ID 20011128.159] 'X' =~ m/\X/ segfault in 5.6.1
print $^STDOUT, "ok" if 'X' =~ m/\X/;
EXPECT
ok
######## segfault in 5.6.1 within peep()
my (@a, @b, @c, @d)
@a = 1..9
@b = sort { nelems( @c = sort { @d = sort { 0 }, @a; nelems(@d); }, @a ); }, @a;
print $^STDOUT, join '', @a, "\n";
EXPECT
123456789
######## example from Camel 5, ch. 15, pp.406 (with my)
# SKIP: ord "A" == 193 # EBCDIC
use utf8;
my $人 = 2; # 0xe4 0xba 0xba: U+4eba, "human" in CJK ideograph
$人++; # a child is born
print $^STDOUT, $人, "\n";
EXPECT
3
######## example from Camel 5, ch. 15, pp.406 (with our)
# SKIP: ord "A" == 193 # EBCDIC
use utf8;
our $人 = 2; # 0xe4 0xba 0xba: U+4eba, "human" in CJK ideograph
$人++; # a child is born
print $^STDOUT, $人, "\n";
EXPECT
3
######## example from Camel 5, ch. 15, pp.406 (with package vars)
# SKIP: ord "A" == 193 # EBCDIC
use utf8;
our $人 = 2; # 0xe4 0xba 0xba: U+4eba, "human" in CJK ideograph
$人++; # a child is born
print $^STDOUT, $人, "\n";
EXPECT
3
########
# test that closures generated by eval"" hold on to the CV of the eval""
# for their entire lifetime
our $x;
our $code = eval q[
  sub { eval '$x = "ok 1\n"'; }
];
$code->();
print $^STDOUT, $x;
EXPECT
ok 1
######## [ID 20020623.009] nested eval/sub segfaults
our $eval = eval 'sub { eval q|sub { %S }| }';
$eval->(\$%);
