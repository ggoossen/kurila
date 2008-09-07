#!./perl

#
# test glob() in File::DosGlob
#

print "1..5\n";

# override it in main::
use File::DosGlob 'glob';

# test if $_ takes as the default
my $expected;
if ($^O eq 'MacOS') {
    $expected = $_ = ":op:a*.t";
} else {
    $expected = $_ = "op/a*.t";
}
my @r = glob;
print "not " if $_ ne $expected;
print "ok 1\n";
print "# |{join ' ',@r}|\nnot " if (nelems @r) +< 4;
print "ok 2\n";

# check if <*/*> works
if ($^O eq 'MacOS') {
    @r = glob(":*:a*.t");
} else {
    @r = glob("*/a*.t");
}
# atleast {argv,abbrev,anydbm,autoloader,append,arith,array,assignwarn,auto}.t
print "# |{join ' ',@r}|\nnot " if (nelems @r) +< 9;
print "ok 3\n";
my $r = scalar nelems @r;

print "ok 4\n";

# check if list context works
@r = @( () );
if ($^O eq 'MacOS') {
    for (glob(":*:a*.t")) {
    	print "# $_\n";
    	push @r, $_;
    }
} else {
    for (glob("*/a*.t")) {
    	print "# $_\n";
    	push @r, $_;
    }
}
print "not " if (nelems @r) != $r;
print "ok 5\n";
