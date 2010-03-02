#!./perl

use Test::More

BEGIN 
    our $hasgr
    try { my @n = (@:  getgrgid 0 ) }
    $hasgr = 1 unless $^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/unimplemented/
    unless ($hasgr) { plan: skip_all => "no getgrgid"; }
    use Config
    $hasgr = 0 unless (config_value: 'i_grp') eq 'define'
    unless ($hasgr) { plan: skip_all => "no grp.h"; }


our ($gid, @grent)
BEGIN 
    $gid = $^OS_NAME ne 'cygwin' ?? 0 !! 18
    @grent = @:  getgrgid $gid  # This is the function getgrgid.
    unless (@grent) { plan: skip_all => "no gid 0"; }


BEGIN 
    plan: tests => 4


use User::grent

can_ok: __PACKAGE__, 'getgrgid'

my $grent = getgrgid: $gid

is:  $grent->name, @grent[0],    'name matches core getgrgid' 

is:  $grent->passwd, @grent[1],  '   passwd' 

is:  $grent->gid, @grent[2],     '   gid' 


# Testing pretty much anything else is unportable.

