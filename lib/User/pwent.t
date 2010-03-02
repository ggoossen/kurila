#!./perl

BEGIN 
    our $haspw
    try { my @n = (@:  getpwuid 0 ) }
    $haspw = 1 unless $^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/unimplemented/
    unless ($haspw) { print: $^STDOUT, "1..0 # Skip: no getpwuid\n"; exit 0 }
    use Config
    # VMS's pwd.h struct passwd conflicts with the one in vmsish.h
    $haspw = 0 unless ( (config_value: 'i_pwd') eq 'define' || $^OS_NAME eq 'VMS' )
    unless ($haspw) { print: $^STDOUT, "1..0 # Skip: no pwd.h\n"; exit 0 }


our ($uid, @pwent)

BEGIN 
    $uid = 0
    # On VMS getpwuid(0) may return [$gid,0] UIC info (which may not exist).
    # It is better to use the $< uid for testing on VMS instead.
    if ( $^OS_NAME eq 'VMS' ) { $uid = $^UID ; }
    if ( $^OS_NAME eq 'cygwin' ) { $uid = 500 ; }
    our @pwent = @:  getpwuid $uid  # This is the function getpwuid.
    unless (@pwent) { print: $^STDOUT, "1..0 # Skip: no uid $uid\n"; exit 0 }


print: $^STDOUT, "1..9\n"

use User::pwent

print: $^STDOUT, "ok 1\n"

my $pwent = getpwuid: $uid # This is the OO getpwuid.

my $uid_expect = $uid
if ( $^OS_NAME eq 'cygwin' )
    print: $^STDOUT, "not " unless (   $pwent->uid == $uid_expect
                                      || $pwent->uid == 500         )  # go figure
else
    print: $^STDOUT, "not " unless $pwent->uid    == $uid_expect 

print: $^STDOUT, "ok 2\n"

print: $^STDOUT, "not " unless $pwent->name   eq @pwent[0]
print: $^STDOUT, "ok 3\n"

if ($^OS_NAME eq 'os390')
    print: $^STDOUT, "not "
        unless not defined $pwent->passwd &&
        @pwent[1] eq '0' # go figure
else
    print: $^STDOUT, "not " unless $pwent->passwd eq @pwent[1]

print: $^STDOUT, "ok 4\n"

print: $^STDOUT, "not " unless $pwent->uid    == @pwent[2]
print: $^STDOUT, "ok 5\n"

print: $^STDOUT, "not " unless $pwent->gid    == @pwent[3]
print: $^STDOUT, "ok 6\n"

# The quota and comment fields are unportable.

print: $^STDOUT, "not " unless $pwent->gecos  eq @pwent[6]
print: $^STDOUT, "ok 7\n"

print: $^STDOUT, "not " unless $pwent->dir    eq @pwent[7]
print: $^STDOUT, "ok 8\n"

print: $^STDOUT, "not " unless $pwent->shell  eq @pwent[8]
print: $^STDOUT, "ok 9\n"

# The expire field is unportable.

# Testing pretty much anything else is unportable:
# there maybe more than one username with uid 0;
# uid 0's home directory may be "/" or "/root' or something else,
# and so on.

