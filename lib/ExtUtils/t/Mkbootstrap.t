#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib/'
    else
        unshift: $^INCLUDE_PATH, 't/lib/'
    

chdir 't'

our ($required)
use Test::More tests => 18

BEGIN { (use_ok:  'ExtUtils::Mkbootstrap' ) }

# Mkbootstrap makes a backup copy of "$_[0].bs" if it exists and is non-zero
my $file_is_ready
my $outfh
my $in
if ((open: $outfh, ">", 'mkboot.bs'))
    $file_is_ready = 1
    print: $outfh, 'meaningless text'
    close $outfh


:SKIP do
    skip: "could not make dummy .bs file: $^OS_ERROR", 2 unless $file_is_ready

    Mkbootstrap: 'mkboot'
    ok:  -s 'mkboot.bso', 'Mkbootstrap should backup the .bs file' 
    if ((open: my $infh, "<", 'mkboot.bso'))
        chomp: ($file_is_ready = ~< $infh->*)
        close $infh
    

    is:  $file_is_ready, 'meaningless text', 'backup should be a perfect copy' 



# if it doesn't exist or is zero bytes in size, it won't be backed up
Mkbootstrap: 'fakeboot'
ok:  !( -f 'fakeboot.bso' ), 'Mkbootstrap should not backup an empty file' 

my $out = ''
close $^STDOUT
open: $^STDOUT, '>>', \$out or die: 

# with $Verbose set, it should print status messages about libraries
$ExtUtils::Mkbootstrap::Verbose = 1
Mkbootstrap: ''
is:  $out, "\tbsloadlibs=\n", 'should report libraries in Verbose mode' 

$out = ''
Mkbootstrap: '', 'foo'
like:  $out, qr/bsloadlibs=foo/, 'should still report libraries' 


# if ${_[0]}_BS exists, require it
$file_is_ready = open: $outfh, ">", 'boot_BS'

:SKIP do
    skip: "cannot open boot_BS for writing: $^OS_ERROR", 1 unless $file_is_ready

    print: $outfh, '$main::required = 1'
    close $outfh
    Mkbootstrap: 'boot'

    ok:  $required, 'baseext_BS file should be require()d' 



# if there are any arguments, open a file named baseext.bs
$file_is_ready = open: $outfh, ">", 'dasboot.bs'

:SKIP do
    skip: "cannot make dasboot.bs: $^OS_ERROR", 5 unless $file_is_ready

    # if it can't be opened for writing, we want to prove that it'll die
    close $outfh
    chmod: 0444, 'dasboot.bs'

    :SKIP do
        skip: "cannot write readonly files", 1 if -w 'dasboot.bs'

        try{ (Mkbootstrap: 'dasboot', 1) }
        like:  $^EVAL_ERROR->{?description}, qr/Unable to open dasboot\.bs/, 'should die given bad filename' 
    

    # now put it back like it was
    $out = ''
    chmod: 0777, 'dasboot.bs'
    try{ (Mkbootstrap: 'dasboot', 'myarg') }
    is:  $^EVAL_ERROR, '', 'should not die, given good filename' 

    # red and reed (a visual pun makes tests worth reading)
    like:  $out, qr/Writing dasboot.bs/, 'should print status' 
    like:  $out, qr/containing: my/, 'should print verbose status on request' 

    # now be tricky, and set the status for the next skip block
    $file_is_ready = open: $in, "<", 'dasboot.bs'
    ok:  $file_is_ready, 'should have written a new .bs file' 



:SKIP do
    skip: "cannot read .bs file: $^OS_ERROR", 2 unless $file_is_ready

    my $file = do { local $^INPUT_RECORD_SEPARATOR = undef; ~< $in->* }

    # filename should be in header
    like:  $file, qr/# dasboot DynaLoader/, 'file should have boilerplate' 

    # should print arguments within this array
    like:  $file, qr/qw\(myarg\);/, 'should have written array to file' 



# overwrite this file (may whack portability, but the name's too good to waste)
$file_is_ready = open: $outfh, ">", 'dasboot.bs'
$out = ''

:SKIP do
    skip: "cannot make dasboot.bs again: $^OS_ERROR", 1 unless $file_is_ready
    close $outfh

    # if $DynaLoader::bscode is set, write its contents to the file
    local $DynaLoader::bscode = undef
    $DynaLoader::bscode = 'Wall'
    $ExtUtils::Mkbootstrap::Verbose = 0

    # if arguments contain '-l' or '-L' or '-R' print dl_findfile message
    try{ (Mkbootstrap: 'dasboot', '-Larry') }
    is:  $^EVAL_ERROR, '', 'should be able to open a file again'

    $file_is_ready = open: $in, "<", 'dasboot.bs'


:SKIP do
    skip: "cannot open dasboot.bs for reading: $^OS_ERROR", 3 unless $file_is_ready

    my $file = do { local $^INPUT_RECORD_SEPARATOR = undef; ~< $in->* }
    is:  $out, "Writing dasboot.bs\n", 'should hush without Verbose set' 

    # and find our hidden tribute to a fine example
    like:  $file, qr/dl_findfile.+Larry/s, 'should load libraries if needed' 
    like:  $file, qr/Wall\n1;\n/ms, 'should write $DynaLoader::bscode if set' 


close $in
close $outfh

END 
    # clean things up, even on VMS
    1 while unlink:  <qw( mkboot.bso boot_BS dasboot.bs .bs )

