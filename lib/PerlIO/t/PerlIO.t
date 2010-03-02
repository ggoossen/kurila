BEGIN 
    require Config; Config->import
    unless ((PerlIO::Layer->find:  'perlio'))
        print: $^STDOUT, "1..0 # Skip: PerlIO not used\n"
        exit 0
    


use Test::More tests => 37

use_ok: 'PerlIO'

my $txt = "txt$^PID"
my $bin = "bin$^PID"
my $utf = "utf$^PID"

my $txtfh
my $binfh
my $utffh

ok: (open: $txtfh, ">:crlf", $txt)

ok: (open: $binfh, ">:raw",  $bin)

ok: (open: $utffh, ">:utf8", $utf)

print: $txtfh, "foo\n"
print: $txtfh, "bar\n"

ok: (close: $txtfh)

print: $binfh, "foo\n"
print: $binfh, "bar\n"

ok: (close: $binfh)

print: $utffh, "foo\x{ff}\n"
print: $utffh, "bar\x{abcd}\n"

ok: (close: $utffh)

ok: (open: $txtfh, "<:crlf", $txt)

ok: (open: $binfh, "<:raw",  $bin)


ok: (open: $utffh, "<:utf8", $utf)

is: scalar ~< $txtfh, "foo\n"
is: scalar ~< $txtfh, "bar\n"

is: scalar ~< $binfh, "foo\n"
is: scalar ~< $binfh, "bar\n"

is: scalar ~< $utffh,  "foo\x{ff}\n"
is: scalar ~< $utffh, "bar\x{abcd}\n"

ok: (eof: $txtfh)

ok: (eof: $binfh)

ok: (eof: $utffh)

ok: (close: $txtfh)

ok: (close: $binfh)

ok: (close: $utffh)

# magic temporary file via 3 arg open with undef
do
    ok:  (open: my $x,"+<",undef), 'magic temp file via 3 arg open with undef'
    ok:  defined (fileno: $x),     '       fileno' 
    ok:  ((print: $x, "ok\n")),         '       print' 
    ok:  (seek: $x,0,0),           '       seek' 
    is:  scalar ~< $x, "ok\n",    '       readline' 
    ok:  (tell: $x) +>= 3,          '       tell' 

    # test magic temp file over STDOUT
    open: my $oldout, ">&", $^STDOUT or die: "cannot dup STDOUT: $^OS_ERROR"
    my $status = open: $^STDOUT,"+<",undef
    open: $^STDOUT, ">&",  \$oldout->* or die: "cannot dup OLDOUT: $^OS_ERROR"
    # report after STDOUT is restored
    ok: $status, '       re-open STDOUT'
    close $oldout


# in-memory open
do
    my $var
    ok:  (open: my $x,"+<",\$var), 'magic in-memory file via 3 arg open with \$var'
    ok:  defined (fileno: $x),     '       fileno' 
    ok:  ((print: $x, "ok\n")),         '       print' 
    ok:  (seek: $x,0,0),           '       seek' 
    is:  scalar ~< $x, "ok\n",    '       readline' 
    ok:  (tell: $x) +>= 3,          '       tell' 

    :TODO do
        local $TODO = "broken"

        # test in-memory open over STDOUT
        open: my $oldout, ">&", $^STDOUT or die: "cannot dup STDOUT: $^OS_ERROR"
        #close STDOUT;
        my $status = open: $^STDOUT,">",\$var
        my $error = "$^OS_ERROR" unless $status # remember the error
        close $^STDOUT unless $status
        open: $^STDOUT, ">&",  \$oldout->* or die: "cannot dup OLDOUT: $^OS_ERROR"
        print: $^STDOUT, "# $error\n" unless $status
        # report after STDOUT is restored
        ok: $status, '       open STDOUT into in-memory var'

        # test in-memory open over STDERR
        open: my $olderr, ">&", $^STDERR or die: "cannot dup STDERR: $^OS_ERROR"
        #close STDERR;
        ok:  (open: $^STDERR,">",\$var), '       open STDERR into in-memory var'
        open: $^STDERR, ">&",  \$olderr->* or die: "cannot dup OLDERR: $^OS_ERROR"
    



END 
    1 while unlink: $txt
    1 while unlink: $bin
    1 while unlink: $utf


