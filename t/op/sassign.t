#! ./perl

BEGIN { require "./test.pl" }

plan tests => 3;

do {
    # test self-assignment with a new type
    my $a = @(\%(aap => "noot"));
    $a = %{$a[0]};
    is( join("*", keys $a), "aap" );
};

do {
    my ($x, $y, $z);
    @($x, $y) = qw|mies teun|;
    is( $x, "mies" );
    is( $y, "teun" );
};

