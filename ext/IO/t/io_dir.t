#!./perl

use Config;

BEGIN {
    if (not %Config{'d_readdir'}) {
	print "1..0 # Skip: readdir() not available\n";
	exit 0;
    }
}

select(STDERR); $| = 1;
select(STDOUT); $| = 1;

use IO::Dir < qw(DIR_UNLINK);

my $tcount = 0;

sub ok {
  $tcount++;
  my $not = @_[0] ? '' : 'not ';
  print "{$not}ok $tcount\n";
}

print "1..10\n";

my $DIR = $^O eq 'MacOS' ? ":" : ".";

my $dot = IO::Dir->new( $DIR);
ok(defined($dot));

my @a = sort glob("*");
my $first;
do { $first = $dot->read } while defined($first) && $first =~ m/^\./;
ok(+(< grep { $_ eq $first } @a));

my @b = sort( @($first, (< grep {m/^[^.]/} $dot->read_all)));
ok(+(join("\0", @a) eq join("\0", @b)));

$dot->rewind;
my @c = sort grep {m/^[^.]/} $dot->read_all;
ok(+(join("\0", @b) eq join("\0", @c)));

$dot->close;
$dot->rewind;
ok(!defined($dot->read));

open(FH,'>', 'X') || die "Can't create x";
print FH "X";
close(FH) or die "Can't close: $!";

tie my %dir, 'IO::Dir', $DIR;
my @files = keys %dir;

# I hope we do not have an empty dir :-)
ok(scalar nelems @files);

my $stat = %dir{'X'};
ok(defined($stat) && UNIVERSAL::isa($stat,'File::stat') && $stat->size == 1);

delete %dir{'X'};

ok(-f 'X');

tie my %dirx, 'IO::Dir', $DIR, DIR_UNLINK;

my $statx = %dirx{'X'};
ok(defined($statx) && UNIVERSAL::isa($statx,'File::stat') && $statx->size == 1);

delete %dirx{'X'};

ok(!(-f 'X'));
