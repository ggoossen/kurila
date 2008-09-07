#!./perl

BEGIN {
    require './test.pl';
}

plan tests => 15;

dies_like(sub { my $x = \2; $$x = ~< *FH; },
          qr/^Modification of a read-only value attempted$/, '[perl #19566]');

{
  open A,"+>", "a"; $a = 3;
  is($a .= (~< *A), 3, '#21628 - $a .= ~< *A , A eof');
  close A; $a = 4;
  is($a .= (~< *A), 4, '#21628 - $a .= ~< *A , A closed');
  unlink "a";
}

# 82 is chosen to exceed the length for sv_grow in do_readline (80)
foreach my $k (@(1, 82)) {
  my $result
    = runperl (stdin => '', stderr => 1,
              prog => "our (\$x, \%a); \$x = q(k) x $k; \%a\{\$x\} = q(v); \$_ = ~< *ARGV foreach keys \%a; print q(end)",
	      );
  $result =~ s/\n\z// if $^O eq 'VMS';
  is ($result, "end", '[perl #21614] for length ' . length('k' x $k));
}


foreach my $k (@(1, 21)) {
  my $result
    = runperl (stdin => ' rules', stderr => 1,
              prog => "our (\$x, \%a); \$x = q(perl) x $k; \%a\{\$x\} = q(v); foreach (keys \%a) \{\$_ .= ~< *ARGV; print\}",
	      );
  $result =~ s/\n\z// if $^O eq 'VMS';
  is ($result, ('perl' x $k) . " rules", 'rcatline to shared sv for length ' . length('perl' x $k));
}

foreach my $l (@(1, 82)) {
  my $k = $l;
  $k = 'k' x $k;
  my $copy = $k;
  $k = ~< *DATA;
  is ($k, "moo\n", 'catline to COW sv for length ' . length $copy);
}


foreach my $l (@(1, 21)) {
  my $k = $l;
  $k = 'perl' x $k;
  my $perl = $k;
  $k .= ~< *DATA;
  is ($k, "$perl rules\n", 'rcatline to COW sv for length ' . length $perl);
}

use strict;
use File::Spec;

open F, '<', 'File::Spec'->curdir and sysread F, $_, 1;
my $err = $! + 0;
close F;

SKIP: {
  skip "you can read directories as plain files", 2 unless( $err );

  $!=0;
  open F, "<", 'File::Spec'->curdir and $_= ~< *F;
  ok( $!==$err && !defined($_) => 'readline( DIRECTORY )' );
  close F;

  $!=0;
  { local $/;
    open F, "<", 'File::Spec'->curdir and $_= ~< *F;
    ok( $!==$err && !defined($_) => 'readline( DIRECTORY ) slurp mode' );
    close F;
  }
}

fresh_perl_is('BEGIN{~< *ARGV}', '',
              \%( switches => \@('-w'), stdin => '', stderr => 1 ),
              'No ARGVOUT used only once warning');

my $obj = bless \@();
dies_like( sub { $obj .= ~< *DATA; }, qr/reference as string/, 'rcatline and refs');

__DATA__
moo
moo
 rules
 rules
world
