#!perl -w


BEGIN {
    try {
	require warnings;
    };
    if ($@) {
	print "1..0\n";
	print $@;
	exit;
    }
}

use strict;
use MIME::Base64 < qw(decode_base64);

print "1..1\n";

use warnings;

my @warn;
$^WARN_HOOK = sub { push(@warn, @_[0]->{description} . "\n") };

warn;
my $a;
$a = decode_base64("aa");
$a = decode_base64("a===");
warn;
$a = do {
    no warnings;
    decode_base64("aa");
};
$a = do {
    no warnings;
    decode_base64("a===");
};
warn;
$a = do {
    local $^W;
    decode_base64("aa");
};
$a = do {
    local $^W;
    decode_base64("a===");
};
warn;

for ( @warn) {
    print "# $_";
}

print "not " unless join("", @warn) eq <<"EOT"; print "ok 1\n";
Warning: something's wrong
Premature end of base64 data
Premature padding of base64 data
Warning: something's wrong
Premature end of base64 data
Premature padding of base64 data
Warning: something's wrong
Warning: something's wrong
EOT
