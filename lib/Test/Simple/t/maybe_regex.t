#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use Test::More tests => 16

use Test::Builder
my $Test = Test::Builder->new

my $r = $Test->maybe_regex: qr/^FOO$/i
ok: defined $r, 'qr// detected'
ok: ('foo' =~ m/$r/), 'qr// good match'
ok: ('bar' !~ m/$r/), 'qr// bad match'

:SKIP do
    my $obj = bless: qr/foo/, 'Wibble'
    my $re = $Test->maybe_regex: $obj
    ok:  defined $re, "blessed regex detected" 
    ok:  ('foo' =~ m/$re/), 'blessed qr/foo/ good match' 
    ok:  ('bar' !~ m/$re/), 'blessed qr/foo/ bad math' 


do
    my $r = $Test->maybe_regex: '/^BAR$/i'
    ok: defined $r, '"//" detected'
    ok: ('bar' =~ m/$r/), '"//" good match'
    ok: ('foo' !~ m/$r/), '"//" bad match'


do
    my $r = $Test->maybe_regex: 'not a regex'
    ok: !defined $r, 'non-regex detected'



do
    my $r = $Test->maybe_regex: '/0/'
    ok: defined $r, 'non-regex detected'
    ok: ('f00' =~ m/$r/), '"//" good match'
    ok: ('b4r' !~ m/$r/), '"//" bad match'



do
    my $r = $Test->maybe_regex: 'm,foo,i'
    ok: defined $r, 'm,, detected'
    ok: ('fOO' =~ m/$r/), '"//" good match'
    ok: ('bar' !~ m/$r/), '"//" bad match'

