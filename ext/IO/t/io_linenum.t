#!./perl

# test added 29th April 1999 by Paul Johnson (pjcj@transeda.com)
# updated    28th May   1999 by Paul Johnson

my $File;

BEGIN {
    $File = __FILE__;
}

use Test;

BEGIN { plan tests => 12 }

use IO::File;

sub lineno($f)
{
  my $l;
  $l .= $f->input_line_number;
  $l;
}

my $t;

open (my $fh, "<", $File) or die $^OS_ERROR;
my $io = IO::File->new($File) or die $^OS_ERROR;

~< *$fh for @( ( <1 .. 10));
ok(lineno($io), "0");

$io->getline for @( ( <1 .. 5));
ok(lineno($io), "5");

~< *$fh;
ok(lineno($io), "5");

$io->getline;
ok(lineno($io), "6");

$t = tell $fh;                                        # tell $fh; provokes a warning
ok(lineno($io), "6");

~< *$fh;
ok(lineno($io), "6");

ok(lineno($io), "6");

~< *$fh for 1 .. 10;
ok(lineno($io), "6");

$io->getline for @( ( <1 .. 5));
ok(lineno($io), "11");

$t = tell $fh;
# We used to have problems here before local $. worked.
# input_line_number() used to use select and tell.  When we did the
# same, that mechanism broke.  It should work now.
ok(lineno($io), "11");

do {
  $io->getline for @( ( <1 .. 5));
  ok(lineno($io), "16");
};

ok(lineno($io), "16");
