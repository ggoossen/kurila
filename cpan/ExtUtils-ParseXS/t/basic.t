#!/usr/bin/perl

use Test::More
BEGIN { (plan: tests => 9) };
use DynaLoader
use ExtUtils::ParseXS < qw(process_file)
use ExtUtils::CBuilder
ok: 1 # If we made it this far, we're loaded.

chdir 't' or die: "Can't chdir to t/, $^OS_ERROR"

#########################

# Try sending to filehandle
my $out = ""
open: my $fh, '>', \$out or die: 
process_file:  filename => 'XSTest.xs', output => $fh, prototypes => 1 
like: $out, '/is_even/', "Test that output contains some text"

my $source_file = 'XSTest.c'

# Try sending to file
process_file: filename => 'XSTest.xs', output => $source_file, prototypes => 0
is: -e $source_file, 1, "Create an output file"

# TEST doesn't like extraneous output
my $quiet = (env::var: 'PERL_CORE') && !env::var: 'HARNESS_ACTIVE'

# Try to compile the file!  Don't get too fancy, though.
my $b = ExtUtils::CBuilder->new: quiet => $quiet
if ($b->have_compiler)
    my $module = 'XSTest'

    my $obj_file = $b->compile:  source => $source_file 
    ok: $obj_file
    is: -e $obj_file, 1, "Make sure $obj_file exists"

    my (@: $lib_file) = $b->link:  objects => $obj_file, module_name => $module 
    ok: $lib_file
    is: -e $lib_file, 1, "Make sure $lib_file exists"

    require XSTest
    ok: XSTest::is_even: 8
    ok: !XSTest::is_even: 9

    # Win32 needs to close the DLL before it can unlink it, but unfortunately
    # dl_unload_file was missing on Win32 prior to perl change #24679!
    if ($^OS_NAME eq 'MSWin32' and exists &DynaLoader::dl_unload_file)
        for my $i (0 .. (nelems: @DynaLoader::dl_modules) -1)
            if (@DynaLoader::dl_modules[$i] eq $module)
                DynaLoader::dl_unload_file: @DynaLoader::dl_librefs[$i]
                last
    
    1 while unlink: $obj_file
    1 while unlink: $lib_file
else 
    skip: "Skipped can't find a C compiler & linker", 7


1 while unlink: $source_file

