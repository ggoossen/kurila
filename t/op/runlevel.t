#!./perl

##
## Many of these tests are originally from Michael Schroeder
## <Michael.Schroeder@informatik.uni-erlangen.de>
## Adapted and expanded by Gurusamy Sarathy <gsar@activestate.com>
##

require './test.pl';

undef $/;
our @prgs = @( split "\n########\n", ~< *DATA );

plan(tests => nelems @prgs);

for (< @prgs){
    my $switch = "";
    if (s/^\s*(-\w+)//){
       $switch = $1;
    }
    my($prog,$expected) = split(m/\nEXPECT\n/, $_);

    fresh_perl_is( $prog, $expected, \%( switch => $switch, stderr => 1, ) );
}

__END__
our @a = @(1, 2, 3);
{
  @a = @( sort { last ; } < @a );
}
EXPECT
Can't "last" outside a loop block at - line 3.
########
package TEST;
 
sub TIESCALAR {
  my $foo;
  return bless \$foo;
}
sub FETCH {
  eval 'die("test")';
  print "still in fetch\n";
  return ">" . $@->message() . "<";
}
package main;
 
tie my $bar, 'TEST';
print "- $bar\n";
EXPECT
still in fetch
- >test at (eval 1) line 1.
    (eval) called at - line 8.
    TEST::FETCH called at - line 15.
<
########
package TEST;
 
sub TIESCALAR {
  my $foo;
  eval('die("foo\n")');
  print "after eval\n";
  return bless \$foo;
}
sub FETCH {
  return "ZZZ";
}
 
package main;
 
tie my $bar, 'TEST';
print "- $bar\n";
print "OK\n";
EXPECT
after eval
- ZZZ
OK
########
sub warnhook {
  print "WARNHOOK\n";
  eval('die("foooo\n")');
}
$^WARN_HOOK = \&warnhook;
warn("dfsds\n");
print "END\n";
EXPECT
WARNHOOK
END
########
package TEST;
 
use overload
     "\"\""   =>  \&str
;
 
sub str {
  eval('die("test\n")');
  return "STR";
}
 
package main;
 
our $bar = bless \%(), 'TEST';
print "$bar\n";
print "OK\n";
EXPECT
STR
OK
########
sub foo {
  goto bar if $a == 0 || $b == 0;
  $a <+> $b;
}
our @a = @(3, 2, 0, 1);
@a = @( sort foo < @a );
print join(', ', < @a)."\n";
exit;
bar:
print "bar reached\n";
EXPECT
Can't "goto" out of a pseudo block at - line 2.
    main::foo called at - line 6.
########
our @a = @(3, 2, 1);
@a = @( sort { eval('die("no way")') ;  $a <+> $b} < @a );
print join(", ", < @a)."\n";
EXPECT
1, 2, 3
########
our @a = @(1, 2, 3);
foo:
{
  @a = @( sort { last foo; } < @a );
}
EXPECT
Label not found for "last foo" at - line 2.
########
package TEST;
 
sub TIESCALAR {
  my $foo;
  return bless \$foo;
}
sub FETCH {
  next;
  return "ZZZ";
}
sub STORE {
}
 
package main;
 
tie our $bar, 'TEST';
{
  print "- $bar\n";
}
print "OK\n";
EXPECT
Can't "next" outside a loop block at - line 8.
    TEST::FETCH called at - line 18.
########
package TEST;
 
sub TIESCALAR {
  my $foo;
  return bless \$foo;
}
sub FETCH {
  goto bbb;
  return "ZZZ";
}
 
package main;
 
tie my $bar, 'TEST';
print "- $bar\n";
exit;
bbb:
print "bbb\n";
EXPECT
Can't find label bbb at - line 8.
    TEST::FETCH called at - line 15.
########
package TEST;
sub TIESCALAR {
  my $foo;
  return bless \$foo;
}
sub FETCH {
  return "fetch";
}
sub STORE {
(split(m/./, 'x'x10000))[0];
}
package main;
tie our $bar, 'TEST';
$bar = "x";
########
package TEST;
sub TIESCALAR {
  my $foo;
  next;
  return bless \$foo;
}
package main;
{
tie my $bar, 'TEST';
}
EXPECT
Can't "next" outside a loop block at - line 4.
    TEST::TIESCALAR called at - line 9.
########
our @a = @(1, 2, 3);
foo:
{
  @a = @( sort { exit(0) } < @a );
}
END { print "foobar\n" }
EXPECT
foobar
########
package TH;
sub TIEHASH { bless \%(), 'TH' }
sub STORE { try { print "{ join ' ', @_[[1,2]]}\n" }; die "bar\n" }
tie our %h, 'TH';
try { %h{A} = 1; print "never\n"; };
print $@->{description};
try { %h{B} = 2; };
print $@->{description};
EXPECT
A 1
bar
B 2
bar
########
sub n { 0 }
sub f { my $x = shift; d(); }
f(n());
f();

sub d {
    my $i = 0; my @a;
    while (do { { package DB; @a = @( caller($i++) ) } } ) {
        @a = @DB::args;
        for (<@a) { print "$_\n"; $_ = '' }
    }
}
EXPECT
0
