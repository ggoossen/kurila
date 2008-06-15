
use Test::More;
BEGIN { plan tests => 37 };

use strict;
use warnings;
use Unicode::Collate;

ok(1);

#########################

sub _pack_U   { Unicode::Collate::pack_U(< @_) }
sub _unpack_U { Unicode::Collate::unpack_U(< @_) }

my $A_acute = _pack_U(0xC1);
my $acute   = _pack_U(0x0301);

my $Collator = Unicode::Collate->new(
  table => 'keys.txt',
  normalization => undef,
);

my %origAlt = %( < $Collator->change(alternate => 'Blanked') );

is($Collator->cmp("death", "de luge"), -1);
is($Collator->cmp("de luge", "de-luge"), -1);
is($Collator->cmp("de-luge", "deluge"), -1);
is($Collator->cmp("deluge", "de\x{2010}luge"), -1);
is($Collator->cmp("deluge", "de Luge"), -1);

$Collator->change(alternate => 'Non-ignorable');

is($Collator->cmp("de luge", "de Luge"), -1);
is($Collator->cmp("de Luge", "de-luge"), -1);
is($Collator->cmp("de-Luge", "de\x{2010}luge"), -1);
is($Collator->cmp("de-luge", "death"), -1);
is($Collator->cmp("death", "deluge"), -1);

$Collator->change(alternate => 'Shifted');

is($Collator->cmp("death", "de luge"), -1);
is($Collator->cmp("de luge", "de-luge"), -1);
is($Collator->cmp("de-luge", "deluge"), -1);
is($Collator->cmp("deluge", "de Luge"), -1);
is($Collator->cmp("de Luge", "deLuge"), -1);

$Collator->change(alternate => 'Shift-Trimmed');

is($Collator->cmp("death", "deluge"), -1);
is($Collator->cmp("deluge", "de luge"), -1);
is($Collator->cmp("de luge", "de-luge"), -1);
is($Collator->cmp("de-luge", "deLuge"), -1);
is($Collator->cmp("deLuge", "de Luge"), -1);

$Collator->change(< %origAlt);

is($Collator->{alternate}, 'shifted');

##############

# ignorable after alternate

# Shifted;
ok($Collator->eq("?\x{300}!\x{301}\x{315}", "?!"));
ok($Collator->eq("?\x{300}A\x{301}", "?$A_acute"));
ok($Collator->eq("?\x{300}", "?"));
ok($Collator->eq("?\x{344}", "?")); # U+0344 has two CEs.

$Collator->change(level => 3);
ok($Collator->eq("\cA", "?"));

$Collator->change(alternate => 'blanked', level => 4);
ok($Collator->eq("?\x{300}!\x{301}\x{315}", "?!"));
ok($Collator->eq("?\x{300}A\x{301}", "?$A_acute"));
ok($Collator->eq("?\x{300}", "?"));
ok($Collator->eq("?\x{344}", "?")); # U+0344 has two CEs.

$Collator->change(level => 3);
ok($Collator->eq("\cA", "?"));

$Collator->change(alternate => 'Non-ignorable', level => 4);

is($Collator->cmp("?\x{300}", "?!"), -1);
is($Collator->cmp("?\x{300}A$acute", "?$A_acute"), 1);
is($Collator->cmp("?\x{300}", "?"), 1);
is($Collator->cmp("?\x{344}", "?"), 1);

$Collator->change(level => 3);
is($Collator->cmp("\cA", "?"), -1);

$Collator->change(alternate => 'Shifted', level => 4);

