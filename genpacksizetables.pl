#!/usr/bin/perl -w
# I'm assuming that you're running this on some kind of ASCII system, but
# it will generate EDCDIC too. (TODO)
use strict;
use Encode;

my @lines = grep {!/^#/} <DATA>;

sub addline {
  my ($arrays, $chrmap, $letter, $arrayname, $noone, $nocsum, $size) = @_;
  my $line = "/* $letter */ $size";
  $line .= " | PACK_SIZE_CANNOT_ONLY_ONE" if $noone;
  $line .= " | PACK_SIZE_CANNOT_CSUM" if $nocsum;
  $line .= ",";
  $arrays->{$arrayname}->[ord $chrmap->{$letter}] = $line;
  # print ord $chrmap->{$letter}, " $line\n";
}

sub output_tables {
  my %arrays;

  my $chrmap = shift;
  foreach (@_) {
    my ($letter, $shriek, $noone, $nocsum, $size)
      = /^([A-Za-z])(!?)\t(\S*)\t(\S*)\t(.*)/;
    die "Can't parse '$_'" unless $size;

    unless ($size =~ s/^=//) {
      $size = "sizeof($size)";
    }

    addline (\%arrays, $chrmap, $letter, $shriek ? 'shrieking' : 'normal',
	     $noone, $nocsum, $size);
  }

  my %earliest;
  foreach my $arrayname (sort keys %arrays) {
    my $array = $arrays{$arrayname};
    die "No defined entries in $arrayname" unless $array->[$#$array];
    # Find the first used entry
    my $earliest = 0;
    $earliest++ while (!$array->[$earliest]);
    # Remove all the empty elements.
    splice @$array, 0, $earliest;
    print "unsigned char size_${arrayname}[", scalar @$array, "] = {\n";
    my @lines = map {$_ || "0,"} @$array;
    # remove the last, annoying, comma
    chop $lines[$#lines];
    print "  $_\n" foreach @lines;
    print "};\n";
    $earliest{$arrayname} = $earliest;
  }

  print "struct packsize_t packsize[2] = {\n";

  my @lines;
  foreach (qw(normal shrieking)) {
    my $array = $arrays{$_};
    push @lines, "  {size_$_, $earliest{$_}, " . (scalar @$array) . "},";
  }
  # remove the last, annoying, comma
  chop $lines[$#lines];
  print "$_\n" foreach @lines;
  print "};\n";
}

my %asciimap = (map {chr $_, chr $_} 0..255);
my %ebcdicmap = (map {chr $_, Encode::encode ("posix-bc", chr $_)} 0..255);

print <<'EOC';
#if 'J'-'I' == 1
/* ASCII */
EOC
output_tables (\%asciimap, @lines);
print <<'EOC';
#else
/* EBCDIC (or bust) */
EOC
output_tables (\%ebcdicmap, @lines);
print "#endif\n";

__DATA__
#Symbol	nooone	nocsum	size
c			char
C			unsigned char
U			char
s!			short
s			=SIZE16
S!			unsigned short
v			=SIZE16
n			=SIZE16
S			=SIZE16
v!			=SIZE16
n!			=SIZE16
i			int
i!			int
I			unsigned int
I!			unsigned int
j			=IVSIZE
J			=UVSIZE
l!			long
l			=SIZE32
L!			unsigned long
V			=SIZE32
N			=SIZE32
V!			=SIZE32
N!			=SIZE32
L			=SIZE32
p	*	*	char *
w		*	char
q			Quad_t
Q			Uquad_t
f			float
d			double
F			=NVSIZE
D			=LONG_DOUBLESIZE
