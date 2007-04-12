#!/usr/bin/perl
#
# Make sure it works to open the file in read-only mode
#

my $file = "tf$$.txt";
$: = Tie::File::_default_recsep();

print "1..9\n";

my $N = 1;
use Tie::File;
use Fcntl 'O_RDONLY';
print "ok $N\n"; $N++;

my @items = qw(Gold Frankincense Myrrh Ivory Apes Peacocks);
init_file(join $:, @items, '');

my $o = tie @a, 'Tie::File', $file, mode => O_RDONLY, autochomp => 0;
print $o ? "ok $N\n" : "not ok $N\n";
$N++;

$#a == $#items ? print "ok $N\n" : print "not ok $N\n";
$N++;

for my $i (0..$#items) {
  ("$items[$i]$:" eq $a[$i]) ? print "ok $N\n" : print "not ok $N\n";
  $N++;
}

sub init_file {
  my $data = shift;
  open F, "> $file" or die $!;
  binmode F;
  print F $data;
  close F;
}


END {
  undef $o;
  untie @a;
  1 while unlink $file;
}

