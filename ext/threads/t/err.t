use strict;
use warnings;

BEGIN {
    if (%ENV{'PERL_CORE'}){
        chdir 't';
        unshift @INC, '../lib';
    }

    require(%ENV{PERL_CORE} ? "./test.pl" : "./t/test.pl");

    use Config;
    if (! %Config{'useithreads'}) {
        skip_all(q/Perl not compiled with 'useithreads'/);
    }

    plan(10);
}

use ExtUtils::testlib;

use_ok('threads');

### Start of Testing ###

no warnings 'threads';

# Create a thread that generates an error
my $thr = threads->create(sub { my $x = Foo->new(); });

# Check that thread returns 'undef'
my $result = $thr->join();
ok(! defined($result), 'thread died');

# Check error
like($thr->error()->{description}, q/Can't locate object method/, 'thread error');


# Create a thread that 'die's with an object
$thr = threads->create(sub {
                    threads->yield();
                    sleep(1);
                    die "bogus";
                });

my $err = $thr->error();
ok(! defined($err), 'no error yet');

# Check that thread returns 'undef'
$result = $thr->join();
ok(! defined($result), 'thread died');

# Check that error object is retrieved
$err = $thr->error();
isa_ok($err, 'error', 'error object');
is($err->{description}, 'bogus', 'error field');

# Check that another thread can reference the error object
my $thrx = threads->create(sub { die $thr->error(); });

# Check that thread returns 'undef'
$result = $thrx->join();
ok(! defined($result), 'thread died');

# Check that the rethrown error object is retrieved
$err = $thrx->error();
isa_ok($err, 'error', 'error object');
is($err->{description}, 'bogus', 'error field');

# EOF
