#!./perl -w

BEGIN {
   chdir 't' if -d 't';
   @INC = '../lib';
   print "1..10\n";
}

use strict;
use Fatal qw(open close :void opendir sin);

my $i = 1;
eval { open *FOO, '<', 'lkjqweriuapofukndajsdlfjnvcvn' };
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

eval { opendir *FOO, 'lkjqweriuapofukndajsdlfjnvcvn' };
print "not " unless $@->{description} =~ m/^Can't open/;
print "ok $i\n"; ++$i;

eval { my $a = opendir *FOO, 'lkjqweriuapofukndajsdlfjnvcvn' };
print "not " if $@ && $@->{description} =~ m/^Can't open/;
print "ok $i\n"; ++$i;

eval { Fatal->import(qw(print)) };
if ($@->message !~ m{Cannot make the non-overridable builtin print fatal}) {
    print "not ";
}
print "ok $i\n"; ++$i;
