
use Test::More
BEGIN { (plan: tests => 11); }
use Locale::Maketext v1.01
print: $^STDOUT, "# Hi there...\n"
ok: 1

print: $^STDOUT, "# --- Making sure that get_handle works ---\n"

# declare some classes...
do
    package Woozle
    our @ISA = @: 'Locale::Maketext'
    sub dubbil   { return @_[1] * 2 }
    sub numerate { return @_[2] . 'en' }

do
    package Woozle::eu_mt
    our @ISA = @: 'Woozle'
    our %Lexicon = %:
        'd2' => 'hum [dubbil,_1]'
        'd3' => 'hoo [quant,_1,zaz]'
        'd4' => 'hoo [*,_1,zaz]'
        
    keys %Lexicon # dodges the 'used only once' warning


my $lh
print: $^STDOUT, "# Basic sanity:\n"
ok: (defined: ( $lh = (Woozle->get_handle: 'eu-mt')) ) && ref: $lh
is: $lh && ($lh->maketext: 'd2', 7), "hum 14"      



print: $^STDOUT, "# Make sure we can assign to ENV entries\n"
       "# (Otherwise we can't run the subsequent tests)...\n"
(env::var: 'MYORP'   ) = 'Zing'
is: (env::var: 'MYORP'), 'Zing'
(env::var: 'SWUZ'   ) = 'KLORTHO HOOBOY'
is: (env::var: 'SWUZ'), 'KLORTHO HOOBOY'

(env::var: 'MYORP') = undef
(env::var: 'SWUZ') = undef


print: $^STDOUT, "# Test LANG...\n"
(env::var: 'LC_ALL' ) = ''
(env::var: 'LC_MESSAGES' ) = ''
(env::var: 'REQUEST_METHOD' ) = ''
(env::var: 'LANG'     ) = 'Eu_MT'
(env::var: 'LANGUAGE' ) = ''
ok: (defined: ( $lh = Woozle->get_handle) ) && ref: $lh

print: $^STDOUT, "# Test LANGUAGE...\n"
(env::var: 'LANG'     ) = ''
(env::var: 'LANGUAGE' ) = 'Eu-MT'
ok: (defined: ( $lh = Woozle->get_handle) ) && ref: $lh

print: $^STDOUT, "# Test HTTP_ACCEPT_LANGUAGE...\n"
(env::var: 'REQUEST_METHOD'       ) = 'GET'
(env::var: 'HTTP_ACCEPT_LANGUAGE' ) = 'eu-MT'
ok: (defined: ( $lh = Woozle->get_handle) ) && ref: $lh
(env::var: 'HTTP_ACCEPT_LANGUAGE' ) = 'x-plorp, zaz, eu-MT, i-klung'
ok: (defined: ( $lh = Woozle->get_handle) ) && ref: $lh
(env::var: 'HTTP_ACCEPT_LANGUAGE' ) = 'x-plorp, zaz, eU-Mt, i-klung'
ok: (defined: ( $lh = Woozle->get_handle) ) && ref: $lh


print: $^STDOUT, "# Byebye!\n"
ok: 1

