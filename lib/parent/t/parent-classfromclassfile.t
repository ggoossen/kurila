#!/usr/bin/perl -w

use Test::More tests => 2
use lib '../lib/parent/t/lib'

use_ok: 'parent'

# Tests that a bare (non-double-colon) class still loads
# and does not get treated as a file:
eval q{package Test1; require Dummy; use parent '-norequire', 'Dummy::InlineChild'; }
die: if $^EVAL_ERROR
isnt: $^INCLUDED{"Dummy.pm"}, undef, 'We loaded Dummy.pm'
