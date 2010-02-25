#!./perl

BEGIN 
    unless ((PerlIO::Layer->find:  'perlio'))
        print: $^STDOUT, "1..0 # Skip: not perlio\n"
        exit 0
    
    require Config


use warnings

my $tmp = "via$^PID"

use Test::More tests => 18
use bytes

my $fh
my $a = (join: "", (map: { chr }, 0..255)) x 10
my $b

BEGIN { (use_ok: 'PerlIO::via::QuotedPrint'); }

ok:  !(open: $fh,"<via(PerlIO::via::QuotedPrint)", $tmp), 'open QuotedPrint for input fails'
ok:   (open: $fh,">via(PerlIO::via::QuotedPrint)", $tmp), 'open QuotedPrint for output'
ok:  ((print: $fh, $a)), "print to output file"
ok:  (close: $fh), 'close output file'

ok:  (open: $fh,"<via(PerlIO::via::QuotedPrint)", $tmp), 'open QuotedPrint for input'
do { local $^INPUT_RECORD_SEPARATOR = undef; $b = ~< $fh }
ok:  (close: $fh), "close input file"

is: $a, $b, 'compare original data with filtered version'


do
    my $warnings = ''
    local $^WARN_HOOK = sub (@< @_) { $warnings = @_[0]->{?description} }

    use warnings 'layer';

    # Find fd number we should be using
    my $fd = (open: $fh, ">","$tmp") && fileno: $fh
    print: $fh, "Hello\n"
    close: $fh

    ok:  ! (open: $fh,">via(Unknown::Module)", $tmp), 'open via Unknown::Module will fail'
    like:  $warnings, qr/^Cannot find package 'Unknown::Module'/,  'warn about unknown package' 

    # Now open normally again to see if we get right fileno
    my $fd2 = (open: $fh, "<","$tmp") && fileno: $fh
    is: $fd2,$fd,"Wrong fd number after failed open"

    my $data = ~< $fh

    is: $data,"Hello\n","File clobbered by failed open"

    close: $fh

    do
        package Incomplete::Module
    

    $warnings = ''
    no warnings 'layer';
    ok:  ! (open: $fh,">via(Incomplete::Module)", $tmp), 'open via Incomplete::Module will fail'
    is:  $warnings, "",  "don't warn about unknown package" 

    $warnings = ''
    no warnings 'layer';
    ok:  ! (open: $fh,">via(Unknown::Module)", $tmp), 'open via Unknown::Module will fail'
    is:  $warnings, "",  "don't warn about unknown package" 


my $obj = ''
sub Foo::PUSHED                 { $obj = shift; -1; }
sub PerlIO::via::Bar::PUSHED    { $obj = shift; -1; }
open: $fh, '<:via(Foo)', "foo"
is:  $obj, 'Foo', 'search for package Foo' 
open: $fh, '<:via(Bar)', "bar"
is:  $obj, 'PerlIO::via::Bar', 'search for package PerlIO::via::Bar' 

END 
    1 while unlink: $tmp


