use strict;
use warnings;

BEGIN {
    if ($ENV{'PERL_CORE'}){
        chdir 't';
        unshift @INC, '../lib';
    }
    use Config;
    if (! $Config{'useithreads'}) {
        print("1..0 # Skip: Perl not compiled with 'useithreads'\n");
        exit(0);
    }
}

use ExtUtils::testlib;

sub ok {
    my ($id, $ok, $name) = @_;

    # You have to do it this way or VMS will get confused.
    if ($ok) {
        print("ok $id - $name\n");
    } else {
        print("not ok $id - $name\n");
        printf("# Failed test at line %d\n", (caller)[2]);
    }

    return ($ok);
}

BEGIN {
    $| = 1;
    print("1..63\n");   ### Number of tests that will be run ###
};

use threads;
ok(1, 1, 'Loaded');

### Start of Testing ###

my @threads;
for (2..32) {
    ok($_, 1, "Multiple thread test");
    push(@threads , threads->create(sub {
                                        my $i = shift;
                                        for (1..500000) { $i++ }
                                    }, $_));
}

my $i = 33;
for (@threads) {
    $_->join;
    ok($i++, 1 ,"Thread joined");
}

# EOF
