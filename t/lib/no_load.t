#!./perl
#
# Check that certain modules don't get loaded when other modules are used.
#

use strict;
use warnings;

require "./test.pl";

#
# Format: [Module-that-should-not-be-loaded => modules to test]
#
my @TESTS = @(
    \@(Carp  => < qw [warnings Exporter]),
);

my $count = 0;
$count += (nelems @$_) - 1 for  @TESTS;

print "1..$count\n";

foreach my $test ( @TESTS) {
    my ($exclude, < @modules) = < @$test;

    foreach my $module ( @modules) {
        my $prog = <<"        --";
            use $module;
            print exists \%INC \{'$exclude.pm'\} ? "not ok" : "ok";
        --
        fresh_perl_is ($prog, "ok", "", "$module does not load $exclude");
    }
}


__END__
