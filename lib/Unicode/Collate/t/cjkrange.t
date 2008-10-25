
use Test::More;
BEGIN { plan tests => 51 };

use warnings;
use Unicode::Collate;

ok(1);

my $Collator = Unicode::Collate->new(
  table => 'keys.txt',
  normalization => undef,
);

# U+9FA6..U+9FBB are CJK UI since Unicode 4.1.0.
# U+3400 is CJK UI ExtA, then greater than any CJK UI.

##### 2..11
is($Collator->cmp("\x{9FA5}", "\x{3400}"), -1); # UI < ExtA
is($Collator->cmp("\x{9FA6}", "\x{3400}"), -1); # new UI < ExtA
is($Collator->cmp("\x{9FBB}", "\x{3400}"), -1); # new UI < ExtA
is($Collator->cmp("\x{9FBC}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FFF}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FA6}", "\x{9FBB}"), -1); # new UI > new UI
is($Collator->cmp("\x{3400}","\x{20000}"), -1); # ExtA < ExtB
is($Collator->cmp("\x{3400}","\x{2A6D6}"), -1); # ExtA < ExtB
is($Collator->cmp("\x{9FFF}","\x{20000}"), 1); # Unassigned > ExtB
is($Collator->cmp("\x{9FFF}","\x{2A6D6}"), 1); # Unassigned > ExtB

##### 12..21
$Collator->change(UCA_Version => 11);
is($Collator->cmp("\x{9FA5}", "\x{3400}"), -1); # UI < ExtA
is($Collator->cmp("\x{9FA6}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FBB}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FBC}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FFF}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FA6}", "\x{9FBB}"), -1); # Unassigned > Unassigned
is($Collator->cmp("\x{3400}","\x{20000}"), -1); # ExtA < ExtB
is($Collator->cmp("\x{3400}","\x{2A6D6}"), -1); # ExtA < ExtB
is($Collator->cmp("\x{9FFF}","\x{20000}"), 1); # Unassigned > ExtB
is($Collator->cmp("\x{9FFF}","\x{2A6D6}"), 1); # Unassigned > ExtB

##### 22..31
$Collator->change(UCA_Version => 9);
is($Collator->cmp("\x{9FA5}", "\x{3400}"), -1); # UI < ExtA
is($Collator->cmp("\x{9FA6}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FBB}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FBC}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FFF}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FA6}", "\x{9FBB}"), -1); # Unassigned > Unassigned
is($Collator->cmp("\x{3400}","\x{20000}"), -1); # ExtA < ExtB
is($Collator->cmp("\x{3400}","\x{2A6D6}"), -1); # ExtA < ExtB
is($Collator->cmp("\x{9FFF}","\x{20000}"), 1); # Unassigned > ExtB
is($Collator->cmp("\x{9FFF}","\x{2A6D6}"), 1); # Unassigned > ExtB

##### 32..41
$Collator->change(UCA_Version => 8);
is($Collator->cmp("\x{9FA5}", "\x{3400}"), 1); # UI > ExtA
is($Collator->cmp("\x{9FA6}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FBB}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FBC}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FFF}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FA6}", "\x{9FBB}"), -1); # new UI > new UI
is($Collator->cmp("\x{3400}","\x{20000}"), -1); # ExtA < Unassigned(ExtB)
is($Collator->cmp("\x{3400}","\x{2A6D6}"), -1); # ExtA < Unassigned(ExtB)
is($Collator->cmp("\x{9FFF}","\x{20000}"), -1); # Unassigned < Unassigned(ExtB)
is($Collator->cmp("\x{9FFF}","\x{2A6D6}"), -1); # Unassigned < Unassigned(ExtB)

##### 42..51
$Collator->change(UCA_Version => 14);
is($Collator->cmp("\x{9FA5}", "\x{3400}"), -1); # UI < ExtA
is($Collator->cmp("\x{9FA6}", "\x{3400}"), -1); # new UI < ExtA
is($Collator->cmp("\x{9FBB}", "\x{3400}"), -1); # new UI < ExtA
is($Collator->cmp("\x{9FBC}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FFF}", "\x{3400}"), 1); # Unassigned > ExtA
is($Collator->cmp("\x{9FA6}", "\x{9FBB}"), -1); # new UI > new UI
is($Collator->cmp("\x{3400}","\x{20000}"), -1); # ExtA < ExtB
is($Collator->cmp("\x{3400}","\x{2A6D6}"), -1); # ExtA < ExtB
is($Collator->cmp("\x{9FFF}","\x{20000}"), 1); # Unassigned > ExtB
is($Collator->cmp("\x{9FFF}","\x{2A6D6}"), 1); # Unassigned > ExtB

