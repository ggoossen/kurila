#!./perl -w

BEGIN 
    require './test.pl'


use Config
BEGIN 
    try {require Errno; (Errno->import: );}

plan: tests => 9

ok:  (binmode: $^STDERR),            'STDERR made binary' 
if (('PerlIO::Layer'->find:  'perlio'))
    ok:  (binmode: $^STDERR, ":unix"),   '  with unix discipline' 
else
    ok: 1,   '  skip unix discipline without PerlIO layers' 

ok:  (binmode: $^STDERR, ":raw"),    '  raw' 
ok:  (binmode: $^STDERR, ":crlf"),   '  and crlf' 

# If this one fails, we're in trouble.  So we just bail out.
(ok:  (binmode: $^STDOUT),            'STDOUT made binary' )      || exit: 1
if (('PerlIO::Layer'->find:  'perlio'))
    ok:  (binmode: $^STDOUT, ":unix"),   '  with unix discipline' 
else
    ok: 1,   '  skip unix discipline without PerlIO layers' 

ok:  (binmode: $^STDOUT, ":raw"),    '  raw' 
ok:  (binmode: $^STDOUT, ":crlf"),   '  and crlf' 

:SKIP do
    skip: "minitest", 1 if env::var: 'PERL_CORE_MINITEST'
    skip: "no EBADF", 1 if (!exists &Errno::EBADF)

    no warnings 'io', 'once';
    $^OS_ERROR = 0
    binmode: \*B
    ok: $^OS_ERROR == (Errno::EBADF:  < @_ )

