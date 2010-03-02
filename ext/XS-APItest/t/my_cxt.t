#!perl -w

# test per-interpeter static data API (MY_CXT)
# DAPM Dec 2005

my $threads
use TestInit
use Config

use warnings

use Test::More tests => 16

BEGIN 
    use_ok: 'XS::APItest'
;

is: (my_cxt_getint: ), 99, "initial int value"
foreach (@: '', ' (context arg)')
    is: (my_cxt_getsv: $_),  "initial", "initial SV value$_"

my_cxt_setint: 1234
is: (my_cxt_getint: ), 1234, "new int value"

my_cxt_setsv: "abcd"
foreach (@: '', ' (context arg)')
    is: (my_cxt_getsv: $_),  "abcd", "new SV value$_"

sub do_thread
    is: (my_cxt_getint: ), 1234, "initial int value (child)"
    my_cxt_setint: 4321
    is: (my_cxt_getint: ), 4321, "new int value (child)"

    foreach (@: '', ' (context arg)')
        is: (my_cxt_getsv: $_), "initial_clone", "initial sv value (child)$_"
    my_cxt_setsv: "dcba"
    foreach (@: '', ' (context arg)')
        is: (my_cxt_getsv: $_),  "dcba", "new SV value (child)$_"


:SKIP do
    skip: "No threads", 6 unless $threads
    (threads->create: \&do_thread)->join


is: (my_cxt_getint: ), 1234,  "int value preserved after join"
foreach (@: '', ' (context arg)')
    is: (my_cxt_getsv: $_),  "abcd", "SV value preserved after join$_"
