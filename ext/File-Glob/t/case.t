#!./perl

BEGIN {
    print "1..7\n";
}
use File::Glob < qw(:glob csh_glob);
print "ok 1\n";

my $pat = $^O eq "MacOS" ? ":op:G*.t" : "op/G*.t";

# Test the actual use of the case sensitivity tags, via csh_glob()
File::Glob->import(':nocase');
my @a = csh_glob($pat);
print "not " unless (nelems @a) +>= 8;
print "ok 2\n";

# This may fail on systems which are not case-PRESERVING
File::Glob->import(':case');
@a = csh_glob($pat); # None should be uppercase
print "not " unless (nelems @a) == 0;
print "ok 3\n";

# Test the explicit use of the GLOB_NOCASE flag
@a = bsd_glob($pat, GLOB_NOCASE);
print "not " unless (nelems @a) +>= 3;
print "ok 4\n";

# Test Win32 backslash nastiness...
if ($^O ne 'MSWin32' && $^O ne 'NetWare') {
    print "ok 5\nok 6\nok 7\n";
}
else {
    @a = File::Glob::glob("op\\g*.t");
    print "not " unless (nelems @a) +>= 8;
    print "ok 5\n";
    mkdir "[]", 0;
    @a = File::Glob::glob("\\[\\]", GLOB_QUOTE);
    rmdir "[]";
    print "# returned {join ' ',@a}\nnot " unless (nelems @a) == 1;
    print "ok 6\n";
    @a = bsd_glob("op\\*", GLOB_QUOTE);
    print "not " if (nelems @a) == 0;
    print "ok 7\n";
}
