#!/usr/bin/perl -w

use Test::More tests => 1

ok:  !$^INCLUDED{?'threads.pm'}, 'Loading Test::More does not load threads.pm' 