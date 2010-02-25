#!./perl

BEGIN 
    print: $^STDOUT, "1..7\n"

use File::Glob < qw(:glob csh_glob)
print: $^STDOUT, "ok 1\n"

my $pat = $^OS_NAME eq "MacOS" ?? ":op:G*.t" !! "op/G*.t"

# Test the actual use of the case sensitivity tags, via csh_glob()
File::Glob->import: ':nocase'
my @a = csh_glob: $pat
print: $^STDOUT, "not " unless (nelems @a) +>= 5
print: $^STDOUT, "ok 2\n"

# This may fail on systems which are not case-PRESERVING
File::Glob->import: ':case'
@a = csh_glob: $pat # None should be uppercase
print: $^STDOUT, "not " unless (nelems @a) == 0
print: $^STDOUT, "ok 3\n"

# Test the explicit use of the GLOB_NOCASE flag
@a = bsd_glob: $pat, GLOB_NOCASE
print: $^STDOUT, "not " unless (nelems @a) +>= 3
print: $^STDOUT, "ok 4\n"

# Test Win32 backslash nastiness...
if ($^OS_NAME ne 'MSWin32' && $^OS_NAME ne 'NetWare')
    print: $^STDOUT, "ok 5\nok 6\nok 7\n"
else
    @a = File::Glob::glob: "op\\g*.t"
    print: $^STDOUT, "not " unless (nelems @a) +>= 8
    print: $^STDOUT, "ok 5\n"
    mkdir: "[]", 0
    @a = File::Glob::glob: "\\[\\]", GLOB_QUOTE
    rmdir "[]"
    print: $^STDOUT, "# returned $((join: ' ',@a))\nnot " unless (nelems @a) == 1
    print: $^STDOUT, "ok 6\n"
    @a = bsd_glob: "op\\*", GLOB_QUOTE
    print: $^STDOUT, "not " if (nelems @a) == 0
    print: $^STDOUT, "ok 7\n"

