#! ./perl

BEGIN { require "./test.pl" }

plan tests => 3;

do {
    # OPf_ASSIGN
    my $x;
    $x = 3;
    is( $x, 3, "basic sv stuff");
};

do {
    # OPf_ASSIGN_PART
    my $x;
    @($x) = qw|aap|;
    is( $x, "aap" );
};

do {
    # OPf_OPTIONAL
    my $x = "aap";
    @( ? $x ) = @();
    is( $x, undef );
};
