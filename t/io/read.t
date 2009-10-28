#!./perl

BEGIN 
    require './test.pl'


eval 'use Errno'
die: $^EVAL_ERROR if $^EVAL_ERROR and !env::var: 'PERL_CORE_MINITEST'

plan: tests => 2

open: my $a, "+>","a"
print: $a, "_"
seek: $a,0,0

my $b = "abcd"
$b = ""

read: $a,$b,1,4

close: $a

unlink: "a"

is: $b,"\000\000\000\000_" # otherwise probably "\000bcd_"

unlink: 'a'

:SKIP do
    skip: "no EBADF", 1 if (!exists &Errno::EBADF)

    $^OS_ERROR = 0
    no warnings 'unopened';
    read: \*B,$b,1
    ok: $^OS_ERROR ==( Errno::EBADF:  < @_ )

