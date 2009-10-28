
use Test::More
BEGIN { (plan: tests => 6); }
use Locale::Maketext v1.01
print: $^STDOUT, "# Hi there...\n"
ok: 1

# declare some classes...
do
    package Woozle
    our @ISA = @: 'Locale::Maketext'
    sub dubbil   { return @_[1] * 2 }
    sub numerate { return @_[2] . 'en' }

do
    package Woozle::elx
    our @ISA = @: 'Woozle'
    our %Lexicon = %:
        'd2' => 'hum [dubbil,_1]'
        'd3' => 'hoo [quant,_1,zaz]'
        'd4' => 'hoo [*,_1,zaz]'
        
    keys %Lexicon # dodges the 'used only once' warning


our $lh
ok: (defined: ( $lh = (Woozle->get_handle: 'elx')) ) && ref: $lh
is: $lh && ($lh->maketext: 'd2', 7), "hum 14"      
is: $lh && ($lh->maketext: 'd3', 7), "hoo 7 zazen" 
is: $lh && ($lh->maketext: 'd4', 7), "hoo 7 zazen" 

print: $^STDOUT, "# Byebye!\n"
ok: 1

