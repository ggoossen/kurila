#!./perl

BEGIN 
    require "test.pl"
    skip_all: "No perlio" unless ((PerlIO::Layer->find:  'perlio'))
    plan: 15


use warnings 'layer'
my $warn
my $file = "fail$^PID"
$^WARN_HOOK = sub (@< @_) { $warn = shift->{?description} }

END { 1 while (unlink: $file) }

ok: (open: my $fh,">",$file),"Create works"
close: $fh
ok: (open: $fh,"<",$file),"Normal open works"

$warn = ''; $^OS_ERROR = 0
ok: !(binmode: $fh,":-)"),"All punctuation fails binmode"
print: $^STDOUT, "# $^OS_ERROR\n"
isnt: $^OS_ERROR,0,"Got errno"
like: $warn,qr/in PerlIO layer/,"Got warning"

$warn = ''; $^OS_ERROR = 0
ok: !(binmode: $fh,":nonesuch"),"Bad package fails binmode"
print: $^STDOUT, "# $^OS_ERROR\n"
isnt: $^OS_ERROR,0,"Got errno"
like: $warn,qr/nonesuch/,"Got warning"
close: $fh

$warn = ''; $^OS_ERROR = 0
ok: !(open: $fh,"<:-)",$file),"All punctuation fails open"
print: $^STDOUT, "# $^OS_ERROR\n"
isnt: $^OS_ERROR,"","Got errno"
like: $warn,qr/in PerlIO layer/,"Got warning"

$warn = ''; $^OS_ERROR = 0
ok: !(open: $fh,"<:nonesuch",$file),"Bad package fails open"
print: $^STDOUT, "# $^OS_ERROR\n"
isnt: $^OS_ERROR,0,"Got errno"
like: $warn,qr/nonesuch/,"Got warning"

ok: (open: $fh,"<",$file),"Normal open (still) works"
close: $fh
