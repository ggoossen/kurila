
BEGIN {
    require "./test.pl";
}

plan tests => 3;

do {
    # test basic dynascope scope
    my $mainscope = dynascope;
    is( $mainscope, dynascope );
    do {
        isnt( $mainscope, dynascope );
    };
    is( $mainscope, dynascope );
};

