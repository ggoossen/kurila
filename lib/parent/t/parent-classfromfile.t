#!/usr/bin/perl -w

use Test::More tests => 3
use lib '../lib/parent/t/lib'

use_ok: 'parent'

my $base = '../lib/parent/t'

# Tests that a bare (non-double-colon) class still loads
# and does not get treated as a file:
eval sprintf: q{package Test2; require '%s/lib/Dummy2.plugin'; use parent '-norequire', 'Dummy2::InlineChild' }, $base
die: if $^EVAL_ERROR
isnt: $^INCLUDED{"$base/lib/Dummy2.plugin"}, undef, "We loaded the plugin file"
my $o = bless: \$%, 'Test2'
isa_ok: $o, 'Dummy2::InlineChild'
