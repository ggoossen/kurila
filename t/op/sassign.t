#! ./perl

BEGIN { require "./test.pl" }

plan tests => 1;

do {
    # test self-assignment with a new type
    my $a = @(\%(aap => "noot"));
    $a = %{$a[0]};
    is( join("*", keys $a), "aap" );
}
