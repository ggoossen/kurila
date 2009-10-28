#!./perl

#
# grep() and map() tests
#

require "./test.pl"
plan:  tests => 52 

our $test

do
    my @lol = @: \qw(a b c), \$@, \qw(1 2 3)
    my @mapped = map: {scalar nelems $_->@}, @lol
    cmp_ok: "$((join: ' ',@mapped))", 'eq', "3 0 3", 'map scalar list of list'

    my @grepped = grep: {scalar nelems $_->@}, @lol
    cmp_ok:  ((join: ' ', (map: { (dump::view: $_) }, @grepped))), 'eq'
             (dump::view: @lol[0]) . ' ' . (dump::view: @lol[2]), 'grep scalar list of list'
    $test++

    @grepped = grep: { $_ }, @mapped
    cmp_ok:  "$((join: ' ',@grepped))", 'eq',  "3 3", 'grep basic'


do
    my @res

    @res = map: {$_}, (@:  ("geronimo"))
    cmp_ok:  (scalar: nelems @res), '==', 1, 'basic map nr'
    cmp_ok:  @res[0], 'eq', 'geronimo', 'basic map is'

    @res = map
        : {$_}, (@:  ("yoyodyne"))
    cmp_ok:  (scalar: nelems @res), '==', 1, 'linefeed map nr'
    cmp_ok:  @res[0], 'eq', 'yoyodyne', 'linefeed map is'

    @res = @:  ((map:  { \%: a =>$_ }, @: "chobb"))[0]->{?a} 
    cmp_ok:  (scalar: nelems @res), '==', 1, 'deref map nr'
    cmp_ok:  @res[0], 'eq', 'chobb', 'deref map is'

    @res = map: {$_}, @:  ("geronimo")
    cmp_ok:  (scalar: nelems @res), '==', 1, 'no paren basic map nr'
    cmp_ok:  @res[0], 'eq', 'geronimo', 'no paren basic map is'

    @res = map: 
        {$_}, @:  ("yoyodyne")
    cmp_ok:  (scalar: nelems @res), '==', 1, 'no paren linefeed map nr'
    cmp_ok:  @res[0], 'eq', 'yoyodyne', 'no paren linefeed map is'

    @res = @:  ((map: { \%: a =>$_ }, (@: "chobb")))[0]->{?a} 
    cmp_ok:  (scalar: nelems @res), '==', 1, 'no paren deref map nr'
    cmp_ok:  @res[0], 'eq', 'chobb', 'no paren deref map is'

    my $x = "\x[FFFFFFFFFFFFFF]\n"

    @res = map:  {$_^&^$x }, (@: ("sferics\n"))
    cmp_ok:  (scalar: nelems @res), '==', 1, 'binand map nr 1'
    cmp_ok:  @res[0], 'eq', "sferics\n", 'binand map is 1'

    @res = map
        :  {$_ ^&^ $x }, (@:  ("sferics\n"))
    cmp_ok:  (scalar: nelems @res), '==', 1, 'binand map nr 2'
    cmp_ok:  @res[0], 'eq', "sferics\n", 'binand map is 2'

    @res = map: { $_ ^&^ $x }, @:  ("sferics\n")
    cmp_ok:  (scalar: nelems @res), '==', 1, 'binand map nr 3'
    cmp_ok:  @res[0], 'eq', "sferics\n", 'binand map is 3'

    @res = map: 
        { $_^&^$x }, @:  ("sferics\n")
    cmp_ok:  (scalar: nelems @res), '==', 1, 'binand map nr 4'
    cmp_ok:  @res[0], 'eq', "sferics\n", 'binand map is 4'

    @res = grep: {$_}, (@:  ("geronimo"))
    cmp_ok:  (scalar: nelems @res), '==', 1, 'basic grep nr'
    cmp_ok:  @res[0], 'eq', 'geronimo', 'basic grep is'

    @res = grep
        : {$_}, (@:  ("yoyodyne"))
    cmp_ok:  (scalar: nelems @res), '==', 1, 'linefeed grep nr'
    cmp_ok:  @res[0], 'eq', 'yoyodyne', 'linefeed grep is'

    @res = grep
        :  {(%: a=>$_){?a} }, (@:
               ("chobb"))
    cmp_ok:  (scalar: nelems @res), '==', 1, 'deref grep nr'
    cmp_ok:  @res[0], 'eq', 'chobb', 'deref grep is'

    @res = grep: {$_}, @:  ("geronimo")
    cmp_ok:  (scalar: nelems @res), '==', 1, 'no paren basic grep nr'
    cmp_ok:  @res[0], 'eq', 'geronimo', 'no paren basic grep is'

    @res = grep: 
        {$_}, @:  ("yoyodyne")
    cmp_ok:  (scalar: nelems @res), '==', 1, 'no paren linefeed grep nr'
    cmp_ok:  @res[0], 'eq', 'yoyodyne', 'no paren linefeed grep is'

    @res = grep: { (%: a=>$_){?a} }, @:  ("chobb")
    cmp_ok:  (scalar: nelems @res), '==', 1, 'no paren deref grep nr'
    cmp_ok:  @res[0], 'eq', 'chobb', 'no paren deref grep is'

    @res = grep: {
                     (%: a=>$_){?a} }, @:  ("chobb")
    cmp_ok:  (scalar: nelems @res), '==', 1, 'no paren deref linefeed  nr'
    cmp_ok:  @res[0], 'eq', 'chobb', 'no paren deref linefeed  is'

    @res = grep:  {$_^&^"X" }, (@:  ("bodine"))
    cmp_ok:  (scalar: nelems @res), '==', 1, 'binand X grep nr'
    cmp_ok:  @res[0], 'eq', 'bodine', 'binand X grep is'

    @res = grep
        :  {$_^&^"X" }, (@:  ("bodine"))
    cmp_ok:  (scalar: nelems @res), '==', 1, 'binand X linefeed grep nr'
    cmp_ok:  @res[0], 'eq', 'bodine', 'binand X linefeed grep is'

    @res = grep: {$_^&^"X"}, @:  ("bodine")
    cmp_ok:  (scalar: nelems @res), '==', 1, 'no paren binand X grep nr'
    cmp_ok:  @res[0], 'eq', 'bodine', 'no paren binand X grep is'

    @res = grep: 
        {$_^&^"X"}, @:  ("bodine")
    cmp_ok:  (scalar: nelems @res), '==', 1, 'no paren binand X linefeed grep nr'
    cmp_ok:  @res[0], 'eq', 'bodine', 'no paren binand X linefeed grep is'


do
    # Tests for "for" in "map" and "grep"
    # Used to dump core, bug [perl #17771]

    my @x
    my $y = ''
    @x = map: { for (1..2) { $y .= $_ }; 1 }, 3..4
    cmp_ok:  "$((join: ' ',@x)),$y",'eq',"1 1,1212", '[perl #17771] for in map 1'

    $y = ''
    @x = map: { for (1..2) { $y .= $_ }; $y .= $_ }, 3..4
    cmp_ok:  "$((join: ' ',@x)),$y",'eq',"123 123124,123124", '[perl #17771] for in map 2'

    $y = ''
    @x = map: { for (1..2) { $y .= $_ } $y .= $_ }, 3..4
    cmp_ok:  "$((join: ' ',@x)),$y",'eq',"123 123124,123124", '[perl #17771] for in map 3'

    $y = ''
    @x = grep: { for (1..2) { $y .= $_ }; 1 }, 3..4
    cmp_ok:  "$((join: ' ',@x)),$y",'eq',"3 4,1212", '[perl #17771] for in grep 1'

    $y = ''
    @x = grep: { for (1..2) { $y .= $_ } 1 }, 3..4
    cmp_ok:  "$((join: ' ',@x)),$y",'eq',"3 4,1212", '[perl #17771] for in grep 2'

    # Add also a sample test from [perl #18153].  (The same bug).
    $a = 1; map: {if ($a){}}, @:  (2)
    pass:  '[perl #18153] (not dead yet)'  # no core dump is all we need


do
    # This shouldn't loop indefinitively.
    my @empty = map: { while (1) {} }, $@
    cmp_ok: "$((join: ' ',@empty))", 'eq', '', 'staying alive'

