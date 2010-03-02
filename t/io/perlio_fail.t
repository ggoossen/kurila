#!./perl

BEGIN
    require "../t/test.pl"
    skip_all: "No perlio" unless ((PerlIO::Layer->find: 'perlio'))
    plan: 15

use warnings 'layer'
my $warn
my $file = "fail$^PID"
$^WARN_HOOK = sub { $warn = shift->message }

END 
    1 while unlink: $file

(ok: (open: my $fh,">",$file),"Create works")
(close: $fh)
(ok: (open: $fh,"<",$file),"Normal open works")

$warn = ''; $^OS_ERROR = 0
(ok: !(binmode: $fh,":-)"),"All punctuation fails binmode")
info: $^OS_ERROR
(isnt: $^OS_ERROR,0,"Got errno")
(like: $warn,qr/in PerlIO layer/,"Got warning")

$warn = ''; $^OS_ERROR = 0
(ok: !(binmode: $fh,":nonesuch"),"Bad package fails binmode")
info: $^OS_ERROR
(isnt: $^OS_ERROR,0,"Got errno")
(like: $warn,qr/nonesuch/,"Got warning")
(close: $fh)

$warn = ''; $^OS_ERROR = 0
(ok: !(open: $fh,"<:-)",$file),"All punctuation fails open")
info: $^OS_ERROR
(isnt: $^OS_ERROR,"","Got errno")
(like: $warn,qr/in PerlIO layer/,"Got warning")

$warn = ''; $^OS_ERROR = 0
(ok: !(open: $fh,"<:nonesuch",$file),"Bad package fails open")
info: $^OS_ERROR
(isnt: $^OS_ERROR,0,"Got errno")
(like: $warn,qr/nonesuch/,"Got warning")

(ok: (open: $fh,"<",$file),"Normal open (still) works")
(close: $fh)
