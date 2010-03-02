#!./perl

BEGIN 
    our $hasne
    try { my @n = (@:  getnetbyname "loopback" ) }
    $hasne = 1 unless $^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/unimplemented|unsupported/i
    unless ($hasne) { print: $^STDOUT, "1..0 # Skip: no getnetbyname\n"; exit 0 }
    use Config
    $hasne = 0 unless (config_value: 'i_netdb') eq 'define'
    unless ($hasne) { print: $^STDOUT, "1..0 # Skip: no netdb.h\n"; exit 0 }


our @netent

BEGIN 
    @netent = @:  getnetbyname "loopback"  # This is the function getnetbyname.
    unless (nelems @netent) { print: $^STDOUT, "1..0 # Skip: no loopback net\n"; exit 0 }


print: $^STDOUT, "1..2\n"

use Net::netent

print: $^STDOUT, "ok 1\n"

my $netent = getnetbyname: "loopback" # This is the OO getnetbyname.

print: $^STDOUT, "not " unless $netent->name   eq @netent[0]
print: $^STDOUT, "ok 2\n"

# Testing pretty much anything else is unportable;
# e.g. the canonical name of the "loopback" net may be "loop".

