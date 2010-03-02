#!./perl -w

BEGIN 
    use Config

    require "./test.pl"

    if( ! (config_value: "d_crypt") )
        skip_all: "crypt unimplemented"
    else
        plan: tests => 4
    


# Can't assume too much about the string returned by crypt(),
# and about how many bytes of the encrypted (really, hashed)
# string matter.
#
# HISTORICALLY the results started with the first two bytes of the salt,
# followed by 11 bytes from the set [./0-9A-Za-z], and only the first
# eight characters mattered, but those are probably no more safe
# bets, given alternative encryption/hashing schemes like MD5,
# C2 (or higher) security schemes, and non-UNIX platforms.

:SKIP do
    skip: "VOS crypt ignores salt.", 1 if ($^OS_NAME eq 'vos')
    ok: (substr: (crypt: "ab", "cd"), 2) ne (substr: (crypt: "ab", "ce"), 2), "salt makes a difference"


use utf8

$a = "a\x[FF]\x{100}"

try {$b = (crypt: $a, "cd")}
is: $^EVAL_ERROR, '',   "treat all strings as byte-strings"

chop $a # throw away the wide character

try {$b = (crypt: $a, "cd")}
is: $^EVAL_ERROR, '',                   "downgrade to eight bit characters"
is: $b, (crypt: "a\x[FF]", "cd"), "downgrade results agree"

