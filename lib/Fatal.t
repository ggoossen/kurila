#!./perl -w

BEGIN {
   chdir 't' if -d 't';
   @INC = @( '../lib' );
   print "1..8\n";
}

use strict;
use Fatal qw(open close);

my $i = 1;
try { open *FOO, '<', 'lkjqweriuapofukndajsdlfjnvcvn' };
print "not " unless $@->{description} =~ m/^Can't open/;
print "ok $i\n"; ++$i;

my $foo = 'FOO';
for ("*$foo", "\\*$foo") {
    eval qq{ open $_, '<', '$0' };
    print "not " if $@;
    print "ok $i\n"; ++$i;

    print "not " if $@ or scalar( ~< *FOO ) !~ m|^#!./perl|;
    print "ok $i\n"; ++$i;
    eval qq{ close *FOO };
    print "not " if $@;
    print "ok $i\n"; ++$i;
}

try { Fatal->import(qw(print)) };
if ($@->message !~ m{Cannot make the non-overridable builtin print fatal}) {
    print "not ";
}
print "ok $i\n"; ++$i;
