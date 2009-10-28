#!./perl

BEGIN 
    our $hasse
    try { my @n = (@:  (getservbyname: "echo", "tcp") ) }
    $hasse = 1 unless $^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/unimplemented|unsupported/i
    unless ($hasse) { print: $^STDOUT, "1..0 # Skip: no getservbyname\n"; exit 0 }
    use Config
    $hasse = 0 unless (config_value: 'i_netdb') eq 'define'
    unless ($hasse) { print: $^STDOUT, "1..0 # Skip: no netdb.h\n"; exit 0 }



our @servent

BEGIN 
    @servent = @:  getservbyname: "echo", "tcp"  # This is the function getservbyname.
    unless (nelems @servent) { print: $^STDOUT, "1..0 # Skip: no echo service\n"; exit 0 }


print: $^STDOUT, "1..3\n"

use Net::servent

print: $^STDOUT, "ok 1\n"

my $servent = getservbyname: "echo", "tcp" # This is the OO getservbyname.

print: $^STDOUT, "not " unless ($servent->name: )   eq @servent[0]
print: $^STDOUT, "ok 2\n"

print: $^STDOUT, "not " unless ($servent->port: )  == @servent[2]
print: $^STDOUT, "ok 3\n"

# Testing pretty much anything else is unportable.

