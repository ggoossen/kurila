#!perl -w


BEGIN 
    try {
        require warnings;
    }
    if ($^EVAL_ERROR)
        print: $^STDOUT, "1..0\n"
        print: $^STDOUT, $^EVAL_ERROR
        exit
    


use Test::More tests => 1
use MIME::Base64 < qw(decode_base64)

use warnings

my @warn
$^WARN_HOOK = sub (@< @_) { (push: @warn, @_[0]->{?description} . "\n") }

warn: 
my $a
$a = decode_base64: "aa"
$a = decode_base64: "a==="
warn: 
$a = do
    no warnings
    decode_base64: "aa"

$a = do
    no warnings
    decode_base64: "a==="

warn: 
$a = do
    local $^WARNING = 0
    decode_base64: "aa"

$a = do
    local $^WARNING = 0
    decode_base64: "a==="

warn: 

for ( @warn)
    print: $^STDOUT, "# $_"


is: (join: "", @warn), <<"EOT"
Warning: something's wrong
Premature end of base64 data
Premature padding of base64 data
Warning: something's wrong
Premature end of base64 data
Premature padding of base64 data
Warning: something's wrong
Warning: something's wrong
EOT
