#!./perl

#
# Ensure that syntax using colons (:) is parsed correctly.
# The tests are done on the following tokens (by default):
# ABC LABEL XYZZY m q qq qw qx s tr y AUTOLOAD and alarm
#	-- Robin Barker <rmb@cise.npl.co.uk>
#



$_ = ''	# to avoid undef warning on m// etc.

sub ok($test,$ok)
    print: $^STDOUT, "not " unless $ok
    print: $^STDOUT, "ok $test\n"


$^WARN_HOOK = sub (@< @_) { 1; } # avoid some spurious warnings

print: $^STDOUT, "1..9\n"

ok: 1, (eval "package ABC; sub zyx \{1\}; 1;" and
       eval "ABC::zyx" and
       not eval "ABC:: eq ABC||" and
       not eval "ABC::: +>= 0")

ok: 2, (eval "package LABEL; sub zyx \{1\}; 1;" and
       eval "LABEL::zyx" and
       not eval "LABEL:: eq LABEL||" and
       not eval "LABEL::: +>= 0")

ok: 3, (eval "package XYZZY; sub zyx \{1\}; 1;" and
       eval "XYZZY::zyx" and
       not eval "XYZZY:: eq XYZZY||" and
       not eval "XYZZY::: +>= 0")

ok: 4, (eval "package m; sub zyx \{1\}; 1;" and
       not eval "m::zyx" and
       eval "m:: eq m||" and
       not eval "m::: +>= 0")

ok: 5, (eval "package q; sub zyx \{1\}; 1;" and
       not eval "q::zyx" and
       eval "q:: eq q||" and
       not eval "q::: +>= 0")

ok: 6, (eval "package qq; sub zyx \{1\}; 1;" and
       not eval "qq::zyx" and
       eval "qq:: eq qq||" and
       not eval "qq::: +>= 0")

ok: 7, (eval "package qw; sub zyx \{1\}; 1;" and
       not eval "qw::zyx" and
       eval "nelems(qw::) == nelems(qw||)" and
       not eval "qw::: +>= 0")

ok: 8, (eval "package qx; sub zyx \{1\}; 1;" and
       not eval "qx::zyx" and
       eval "qx:: eq qx||" and
       not eval "qx::: +>= 0")

ok: 9, (eval "package s; sub zyx \{1\}; 1;" and
       not eval "s::zyx" and
       not eval "s:: eq s||" and
       eval "s::: +>= 0")
