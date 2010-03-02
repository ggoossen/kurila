#!./perl

BEGIN { require "./test.pl"; }

plan: tests => 19

use File::Spec

my $devnull = 'File::Spec'->devnull

(open: my $try, ">", 'Io_argv1.tmp') || (die: "Can't open temp file: $^OS_ERROR")
print: $try, "a line\n"
close $try or die: "Could not close: $^OS_ERROR"

do
    my $x = runperl: 
        prog    => 'while (~< *ARGV) { print $^STDOUT, $_; }'
        stdin   => "foo\n"
        args    => \(@:  'Io_argv1.tmp', '-' )
        
    is: $x, "a line\nfoo\n", '   from a file and STDIN'

    $x = runperl: 
        prog    => 'while (~< *ARGV) { print $^STDOUT, $_; }'
        stdin   => "foo\n"
        
    is: $x, "foo\n", '   from just STDIN'


do
    # 5.10 stopped autovivifying scalars in globs leading to a
    # segfault when $ARGV is written to.
    runperl:  prog => 'eof()', stdin => "nothing\n" 
    is:  0+$^CHILD_ERROR, 0, q(eof() doesn't segfault) 


open: $try, "<", 'Io_argv1.tmp' or die: "Can't open temp file: $^OS_ERROR"
close $try or die: "Could not close: $^OS_ERROR"
open: $try, ">", 'Io_argv2.tmp' or die: "Can't open temp file: $^OS_ERROR"
close $try or die: "Could not close: $^OS_ERROR"
@ARGV = @: 'Io_argv1.tmp', 'Io_argv2.tmp'
$^INPUT_RECORD_SEPARATOR = undef
my $i = 4
while ( ~< *ARGV)
    s/^/ok $i - /
    ++$i
    print: $^STDOUT, $_
    (next_test: )

open: $try, "<", 'Io_argv1.tmp' or die: "Can't open temp file: $^OS_ERROR"
(print: $^STDOUT, $_) while ~< $try->*
open: $try, "<", 'Io_argv2.tmp' or die: "Can't open temp file: $^OS_ERROR"
(print: $^STDOUT, $_) while ~< $try->*
close $try or die: "Could not close: $^OS_ERROR"

ok:  eof $try 

do
    no warnings 'once'
    ok:  eof \*NEVEROPENED,    'eof() true on unopened filehandle' 


open: $^STDIN, "<", 'Io_argv1.tmp' or die: $^OS_ERROR
@ARGV = $@
ok:  !(eof: $^STDIN),     'STDIN has something' 

is:  $(~< *ARGV), "a line\n" 

open: $^STDIN, '<', $devnull or die: $^OS_ERROR
@ARGV = $@
ok:  (eof: ),      'eof() true with empty @ARGV' 

@ARGV = @: 'Io_argv1.tmp'
ok:  !(eof: ) 

@ARGV = @: $devnull, $devnull
ok:  !(eof: ) 

close \*ARGV or die: $^OS_ERROR
ok:  (eof: ),      'eof() true after closing ARGV' 

do
    local $^INPUT_RECORD_SEPARATOR = undef
    open: my $f, "<", 'Io_argv1.tmp' or die: "Could not open Io_argv1.tmp: $^OS_ERROR"
    ~< $f->*    # set $. = 1
    is:  ($: ~< $f->*), undef 

    open: $f, "<", $devnull or die: 
    ok:  (defined:  ~< $f->*) 

    is: ($: ~< $f->*), undef 
    is: ($: ~< $f->*), undef 

    open: $f, "<", $devnull or die: # restart cycle again
    ok:  (defined:  ~< $f->*) 
    is: ($: ~< $f->*), undef 
    close $f or die: "Could not close: $^OS_ERROR"


END 
    1 while unlink: 'Io_argv1.tmp'
                    'Io_argv2.tmp', 'Io_argv3.tmp'

