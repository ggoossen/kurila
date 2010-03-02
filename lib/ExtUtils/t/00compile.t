#!/usr/bin/perl -w

use File::Find
use File::Spec
use Test::More

my $Has_Test_Pod
BEGIN 
    $Has_Test_Pod = eval 'use Test::Pod 0.95; 1'


chdir File::Spec->updir
my $manifest = File::Spec->catfile: 'MANIFEST'
open: my $manifestfh, "<", $manifest or die: "Can't open $manifest: $^OS_ERROR"
my @modules = map: { m{^lib/(\S+)}; $1 },
                       grep: { m{^lib/ExtUtils/\S*\.pm} },
                                 grep: { !m{/t/} }, @:  ~< $manifestfh->*
chomp @modules
close $manifestfh

chdir 'lib'
plan: tests => (nelems @modules) * 2
foreach my $file (@modules)
    # Make sure we look at the local files and do not reload them if
    # they're already loaded.  This avoids recompilation warnings.
    local $^INCLUDE_PATH = $^INCLUDE_PATH
    unshift: $^INCLUDE_PATH, "."
    ok: $: try { require($file); 1 } or diag: "require $file failed.\n$($^EVAL_ERROR->message)"

    :SKIP do
        skip: "Test::Pod not installed", 1 unless $Has_Test_Pod
        pod_file_ok: $file
    

