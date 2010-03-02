
use Test::More
BEGIN { (plan: tests => 4); }
use Locale::Maketext
print: $^STDOUT, "# Hi there...\n"
ok: 1

print: $^STDOUT, "# --- Making sure that Perl globals are localized ---\n"

# declare a class...
do
    package Woozle
    our @ISA = @: 'Locale::Maketext'
    our %Lexicon = %:
        _AUTO => 1
        
    keys %Lexicon # dodges the 'used only once' warning


my $lh
print: $^STDOUT, "# Basic sanity:\n"
ok: (defined: ( $lh = (Woozle->new: )) ) && ref: $lh

print: $^STDOUT, "# Make sure \$@ is localized...\n"
$^EVAL_ERROR = 'foo'
is: $lh && ($lh->maketext: 'Eval error: [_1]', $^EVAL_ERROR), "Eval error: foo"

print: $^STDOUT, "# Byebye!\n"
ok: 1
