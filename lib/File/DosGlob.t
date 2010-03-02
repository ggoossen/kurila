#!./perl

#
# test glob() in File::DosGlob
#

print: $^STDOUT, "1..5\n"

# override it in main::
use File::DosGlob 'glob'

# test if $_ takes as the default
my $expected
if ($^OS_NAME eq 'MacOS')
    $expected = $_ = ":op:a*.t"
else
    $expected = $_ = "op/a*.t"

my @r = glob: 
print: $^STDOUT, "not " if $_ ne $expected
print: $^STDOUT, "ok 1\n"
print: $^STDOUT, "# |$((join: ' ',@r))|\nnot " if (nelems @r) +< 4
print: $^STDOUT, "ok 2\n"

# check if <*/*> works
if ($^OS_NAME eq 'MacOS')
    @r = glob: ":*:a*.t"
else
    @r = glob: "*/a*.t"

# atleast {argv,abbrev,anydbm,autoloader,append,arith,array,assignwarn,auto}.t
print: $^STDOUT, "# |$((join: ' ',@r))|\nnot " if (nelems @r) +< 9
print: $^STDOUT, "ok 3\n"
my $r = scalar nelems @r

print: $^STDOUT, "ok 4\n"

# check if list context works
@r = $@
if ($^OS_NAME eq 'MacOS')
    for ((glob: ":*:a*.t")
        print: $^STDOUT, "# $_\n"
        push: @r, $_
    
else
    for ((glob: "*/a*.t")
        print: $^STDOUT, "# $_\n"
        push: @r, $_
    

print: $^STDOUT, "not " if (nelems @r) != $r
print: $^STDOUT, "ok 5\n"
