#!./perl

# test added 29th April 1999 by Paul Johnson (pjcj@transeda.com)
# updated    28th May   1999 by Paul Johnson

my $File;

BEGIN {
    $File = __FILE__;
    require strict; strict->import();
}

use Test;

BEGIN { plan tests => 12 }

use IO::File;

sub lineno
{
  my ($f) = < @_;
  my $l;
  $l .= $f->input_line_number;
  $l;
}

my $t;

open (F, "<", $File) or die $!;
my $io = IO::File->new($File) or die $!;

~< *F for @( ( <1 .. 10));
ok(lineno($io), "0");

$io->getline for @( ( <1 .. 5));
ok(lineno($io), "5");

~< *F;
ok(lineno($io), "5");

$io->getline;
ok(lineno($io), "6");

$t = tell F;                                        # tell F; provokes a warning
ok(lineno($io), "6");

~< *F;
ok(lineno($io), "6");

select F;
ok(lineno($io), "6");

~< *F for @( ( <1 .. 10));
ok(lineno($io), "6");

$io->getline for @( ( <1 .. 5));
ok(lineno($io), "11");

$t = tell F;
# We used to have problems here before local $. worked.
# input_line_number() used to use select and tell.  When we did the
# same, that mechanism broke.  It should work now.
ok(lineno($io), "11");

{
  $io->getline for @( ( <1 .. 5));
  ok(lineno($io), "16");
}

ok(lineno($io), "16");
