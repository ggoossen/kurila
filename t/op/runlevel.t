#!./perl

##
## Many of these tests are originally from Michael Schroeder
## <Michael.Schroeder@informatik.uni-erlangen.de>
## Adapted and expanded by Gurusamy Sarathy <gsar@activestate.com>
##

require './test.pl'

undef $^INPUT_RECORD_SEPARATOR
our @prgs = split: "\n########\n", ~< $^DATA

plan: tests => nelems @prgs

for ( @prgs)
    my $switch = ""
    if (s/^\s*(-\w+)//)
        $switch = $1
    
    my(@: $prog,$expected) =  split: m/\nEXPECT\n/, $_

    fresh_perl_is:  $prog, $expected, \(%:  switch => $switch, stderr => 1, ) 


__END__
our @a = @: 1, 2, 3
do
  @a = sort { last ; }, @a
EXPECT
Can't "last" outside a loop block at - line 3 character 15.
    main::__ANON__ called at - line 3 character 8.
########
sub warnhook
  print $^STDOUT, "WARNHOOK\n"
  eval('die("foooo\n")')

$^WARN_HOOK = \&warnhook
warn("dfsds\n")
print $^STDOUT, "END\n"
EXPECT
WARNHOOK
END
########
our @a = @: 3, 2, 1
@a = sort { eval('die("no way")') ;  $a <+> $b}, @a
print $^STDOUT, join(", ", @a)."\n"
EXPECT
1, 2, 3
########
our @a = @: 1, 2, 3
:foo do
  @a = sort { last foo; }, @a
EXPECT
Label not found for "last foo" at - line 3 character 15.
    main::__ANON__ called at - line 3 character 8.
########
our @a = @: 1, 2, 3
:foo do
  @a = sort { exit(0) }, @a
END { print $^STDOUT, "foobar\n" }
EXPECT
foobar
