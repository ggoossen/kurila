#!./perl

BEGIN 
    require './test.pl'


plan: tests => 7

our ($x)

$x='banana'
$x=~m/.a/g
is: (pos: $x), 2

$x=~m/.z/gc
is: (pos: $x), 2

sub f { my $p=@_[0]; return $p }

$x=~m/.a/g
is: (f: (pos: $x)), 4

# Is pos() set inside //g? (bug id 19990615.008)
$x = "test string?"; $x =~ s/\w/$( do { (pos: $x) } )/g
is: $x, "0123 5678910?"

do
    local our $TODO = "pos() inside //g without new scope"
    $x = "test string?"; $x =~ s/\w/$( do { (pos: $x) } )/g
    is: $x, "0123 5678910?"


$x = "123 56"; $x =~ m/ /g
is: (pos: $x), 4
do { local $x }
is: (pos: $x), 4
