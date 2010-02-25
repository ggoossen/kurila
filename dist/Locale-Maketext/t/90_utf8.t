
use Test::More
BEGIN { (plan: tests => 4); }
use Locale::Maketext v1.01
print: $^STDOUT, "# Hi there...\n"
ok: 1


print: $^STDOUT, "# --- Making sure that get_handle works with utf8 ---\n"
use utf8

# declare some classes...
do
    package Woozle
    our @ISA = @: 'Locale::Maketext'
    sub dubbil   { return @_[1] * 2  .(chr: 2000)}
    sub numerate { return @_[2] . 'en'  }

do
    package Woozle::eu_mt
    our @ISA = @: 'Woozle'
    our %Lexicon = %:
        'd2' => (chr: 1000) . 'hum [dubbil,_1]'
        'd3' => (chr: 1000) . 'hoo [quant,_1,zaz]'
        'd4' => (chr: 1000) . 'hoo [*,_1,zaz]'
        
    keys %Lexicon # dodges the 'used only once' warning


my $lh
print: $^STDOUT, "# Basic sanity:\n"
ok: (defined: ( $lh = (Woozle->get_handle: 'eu-mt')) ) && ref: $lh
is: $lh && ($lh->maketext: 'd2', 7), (chr: 1000)."hum 14".chr: 2000   


print: $^STDOUT, "# Byebye!\n"
ok: 1

