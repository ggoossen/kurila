#!./perl

BEGIN {
    our $haspe;
    try { my @n = @( getprotobyname "tcp" ) };
    $haspe = 1 unless $@ && $@->{description} =~ m/unimplemented|unsupported/i;
    unless ($haspe) { print "1..0 # Skip: no getprotobyname\n"; exit 0 }
    use Config;
    $haspe = 0 unless config_value('i_netdb') eq 'define';
    unless ($haspe) { print "1..0 # Skip: no netdb.h\n"; exit 0 }
}


our @protoent;

BEGIN {
    @protoent = @( getprotobyname "tcp" ); # This is the function getprotobyname.
    unless (nelems @protoent) { print "1..0 # Skip: no tcp protocol\n"; exit 0 }
}

print "1..3\n";

use Net::protoent;

print "ok 1\n";

my $protoent = getprotobyname "tcp"; # This is the OO getprotobyname.

print "not " unless $protoent->name   eq @protoent[0];
print "ok 2\n";

print "not " unless $protoent->proto  == @protoent[2];
print "ok 3\n";

# Testing pretty much anything else is unportable.

