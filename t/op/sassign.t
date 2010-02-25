#! ./perl

BEGIN { require "./test.pl" }

plan: tests => 5

do
    # test self-assignment with a new type
    my $a = @: \%: aap => "noot"
    $a = $a[0]->%
    is:  (join: "*", keys $a), "aap" 


do
    # array assignments
    my ($x, $y, $z)
    (@: $x, $y) = qw|Mies Wim|
    is:  $x, "Mies" 
    is:  $y, "Wim" 

    dies_like:  { (@: $x, $y) = qw|zus Jet Teun| }
                qr/\QGot extra value(s) in anonymous array (\E[@]\Q:) assignment\E/, "assignment with one extra item" 
    dies_like:  { (@: $x, $y) = qw|zus|; }
                qr/Missing required assignment value/, "assignment with one missing item" 
