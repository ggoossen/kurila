#!./perl

require "./test.pl"

plan: 33

# because of ebcdic.c these should be the same on asciiish
# and ebcdic machines.
# Peter Prymmer <pvhp@best.com>.

my $c = "\c@"
is: (ord: $c), 0
$c = "\cA"
is: (ord: $c), 1
$c = "\cB"
is: (ord: $c), 2
$c = "\cC"
is: (ord: $c), 3
$c = "\cD"
is: (ord: $c), 4
$c = "\cE"
is: (ord: $c), 5
$c = "\cF"
is: (ord: $c), 6
$c = "\cG"
is: (ord: $c), 7
$c = "\cH"
is: (ord: $c), 8
$c = "\cI"
is: (ord: $c), 9
$c = "\cJ"
is: (ord: $c), 10
$c = "\cK"
is: (ord: $c), 11
$c = "\cL"
is: (ord: $c), 12
$c = "\cM"
is: (ord: $c), 13
$c = "\cN"
is: (ord: $c), 14
$c = "\cO"
is: (ord: $c), 15
$c = "\cP"
is: (ord: $c), 16
$c = "\cQ"
is: (ord: $c), 17
$c = "\cR"
is: (ord: $c), 18
$c = "\cS"
is: (ord: $c), 19
$c = "\cT"
is: (ord: $c), 20
$c = "\cU"
is: (ord: $c), 21
$c = "\cV"
is: (ord: $c), 22
$c = "\cW"
is: (ord: $c), 23
$c = "\cX"
is: (ord: $c), 24
$c = "\cY"
is: (ord: $c), 25
$c = "\cZ"
is: (ord: $c), 26
$c = "\c["
is: (ord: $c), 27
$c = "\c\\"
is: (ord: $c), 28
$c = "\c]"
is: (ord: $c), 29
$c = "\c^"
is: (ord: $c), 30
$c = "\c_"
is: (ord: $c), 31
$c = "\c?"
is: (ord: $c), 127
