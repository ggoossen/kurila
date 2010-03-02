#!/usr/bin/perl -w

# Here we make sure File::Spec can properly deal with executables.
# VMS has some trouble with these.

use File::Spec
use lib File::Spec->catdir: 't', 'lib'

use Test::More (-x $^EXECUTABLE_NAME
                ?? (tests => 5)
                !! (skip_all => "Can't find an executable file")
                )

BEGIN                                 # Set up a tiny script file
    open: my $f, ">", "rel2abs2rel$^PID.pl"
        or die: "Can't open rel2abs2rel$^PID.pl file for script -- $^OS_ERROR\n"
    print: $f, qq(print \$^STDOUT, "ok\\n"\n)
    close: $f

END 
    1 while unlink: "rel2abs2rel$^PID.pl"
    1 while unlink: "rel2abs2rel$^PID.tmp"


use Config


# Change 'perl' to './perl' so the shell doesn't go looking through PATH.
sub safe_rel
    my(@: $perl) =@:  shift
    $perl = (File::Spec->catfile: File::Spec->curdir, $perl) unless
        File::Spec->file_name_is_absolute: $perl

    return $perl

# Make a putative perl binary say "ok\n". We have to do it this way
# because the filespec of the binary may contain characters that a
# command interpreter considers special, so we can't use the obvious
# `$perl -le "print 'ok'"`. And, for portability, we can't use fork().
sub sayok
    my $perl = shift
    open: my $stdoutdup, ">&", $^STDOUT
    open: $^STDOUT, ">", "rel2abs2rel$^PID.tmp"
        or die: "Can't open scratch file rel2abs2rel$^PID.tmp -- $^OS_ERROR\n"
    system: $perl, "rel2abs2rel$^PID.pl"
    open: $^STDOUT, ">&", \$stdoutdup->*
    close: $stdoutdup

    open: my $f, "<", "rel2abs2rel$^PID.tmp"
    local $^INPUT_RECORD_SEPARATOR = undef
    my $output = ~< $f->*
    close: $f
    return $output


print: $^STDOUT, "# Checking manipulations of \$^X=$^EXECUTABLE_NAME\n"

my $perl = safe_rel: $^EXECUTABLE_NAME
is:  (sayok: $perl), "ok\n",   "`$perl rel2abs2rel$^PID.pl` works" 

$perl = File::Spec->rel2abs: $^EXECUTABLE_NAME
is:  (sayok: $perl), "ok\n",   "`$perl rel2abs2rel$^PID.pl` works" 

$perl = File::Spec->canonpath: $perl
is:  (sayok: $perl), "ok\n",   "canonpath(rel2abs($^EXECUTABLE_NAME)) = $perl" 

$perl = safe_rel: (File::Spec->abs2rel: $perl)
is:  (sayok: $perl), "ok\n",   "safe_rel(abs2rel(canonpath(rel2abs($^EXECUTABLE_NAME)))) = $perl" 

$perl = safe_rel: (File::Spec->canonpath: $^EXECUTABLE_NAME)
is:  (sayok: $perl), "ok\n",   "safe_rel(canonpath($^EXECUTABLE_NAME)) = $perl" 
