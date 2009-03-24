#!./perl -w
#
#  Copyright 2004, Larry Wall.
#
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

use Config;

BEGIN {
  if (env::var('PERL_CORE')){
    chdir('t') if -d 't';
    $^INCLUDE_PATH = @('.', '../lib', '../ext/Storable/t');
  } else {
    # This lets us distribute Test::More in t/
    unshift $^INCLUDE_PATH, 't';
  }
}

use Scalar::Util < qw(weaken isweak);

use Test::More 'no_plan';
use Storable < qw(store retrieve freeze thaw nstore nfreeze);
require 'testlib.pl';
our $file;


sub tester {
  my @($contents, $sub, $testersub, $what) = @_;
  # Test that if we re-write it, everything still works:
  my $clone = &$sub ($contents);
  is ($^EVAL_ERROR, "", "There should be no error extracting for $what");
  &$testersub ($clone, $what);
}

my $r = \%();
my $s1 = \@($r, $r);
weaken $s1->[1];
ok (isweak($s1->[1]), "element 1 is a weak reference");

my $s0 = \@($r, $r);
weaken $s0->[0];
ok (isweak($s0->[0]), "element 0 is a weak reference");

my $w = \@($r);
weaken $w->[0];
ok (isweak($w->[0]), "element 0 is a weak reference");

package main;

my @tests = @(
\@($s1,
 sub  {
  my @($clone, $what) = @_;
  isa_ok($clone,'ARRAY');
  isa_ok($clone->[0],'HASH');
  isa_ok($clone->[1],'HASH');
  ok(!isweak($clone->[0]), "Element 0 isn't weak");
  ok(isweak($clone->[1]), "Element 1 is weak");
}
),
# The weak reference needs to hang around long enough for other stuff to
# be able to make references to it. So try it second.
\@($s0,
 sub  {
  my @($clone, $what) = @_;
  isa_ok($clone,'ARRAY');
  isa_ok($clone->[0],'HASH');
  isa_ok($clone->[1],'HASH');
  ok(isweak($clone->[0]), "Element 0 is weak");
  ok(!isweak($clone->[1]), "Element 1 isn't weak");
}
),
\@($w,
 sub  {
  my @($clone, $what) = @_;
  isa_ok($clone,'ARRAY');
  if ($what eq 'nothing') {
    # We're the original, so we're still a weakref to a hash
    isa_ok($clone->[0],'HASH');
    ok(isweak($clone->[0]), "Element 0 is weak");
  } else {
    is($clone->[0],undef);
  }
}
),
);

foreach (@tests) {
  my @($input, $testsub) = @$_;

  tester($input, sub {return shift}, $testsub, 'nothing');

  ok (defined store($input, $file));

  # Read the contents into memory:
  my $contents = slurp ($file);

  tester($contents, \&store_and_retrieve, $testsub, 'file');

  # And now try almost everything again with a Storable string
  my $stored = freeze $input;
  tester($stored, \&freeze_and_thaw, $testsub, 'string');

  ok (defined nstore($input, $file));

  tester($contents, \&store_and_retrieve, $testsub, 'network file');

  $stored = nfreeze $input;
  tester($stored, \&freeze_and_thaw, $testsub, 'network string');
}
