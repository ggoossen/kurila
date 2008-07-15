#!./perl

BEGIN {
    print "1..10\n";
}

BEGIN {
    *CORE::GLOBAL::glob = sub { "Just another Perl hacker," };
}

BEGIN {
    if ("Just another Perl hacker," ne (glob( <"*"))[0]) {
        die <<EOMessage;
Your version of perl ($^V) doesn't seem to allow extensions to override
the core glob operator.
EOMessage
    }
}

use File::Glob ':globally';
print "ok 1\n";

$_ = $^O eq "MacOS" ? ":op:*.t" : "op/*.t";
my @r = @( glob < );
print "not " if $_ ne ($^O eq "MacOS" ? ":op:*.t" : "op/*.t");
print "ok 2\n";

print "# |{join ' ', <@r}|\nnot " if (nelems @r) +< 3;
print "ok 3\n";

# check if <*/*> works
if ($^O eq "MacOS") {
    @r = glob@( <":*:*.t");
} else {
    @r = glob@( <"*/*.t");
}
# at least t/global.t t/basic.t, t/taint.t
print "not " if (nelems @r) +< 3;
print "ok 4\n";
my $r = scalar nelems @r;

# check if scalar context works
@r = @( () );
if ($^O eq "MacOS") {
    while (defined($_ = glob(":*:*.t"))) {
	#print "# $_\n";
	push @r, $_;
    }
} else {
    while (defined($_ = glob("*/*.t"))) {
	#print "# $_\n";
	push @r, $_;
    }
}
print "not " if (nelems @r) != $r;
print "ok 5\n";

# check if list context works
@r = @( () );
if ($^O eq "MacOS") {
    for (glob( <":*:*.t")) {
	#print "# $_\n";
	push @r, $_;
    }
} else {
    for (glob( <"*/*.t")) {
	#print "# $_\n";
	push @r, $_;
    }
}
print "not " if (nelems @r) != $r;
print "ok 6\n";

# test if implicit assign to $_ in while() works
@r = @( () );
if ($^O eq "MacOS") {
    while (glob(":*:*.t")) {
	#print "# $_\n";
	push @r, $_;
    }
} else {
    while (glob("*/*.t")) {
	#print "# $_\n";
	push @r, $_;
    }
}
print "not " if (nelems @r) != $r;
print "ok 7\n";

# test if explicit glob() gets assign magic too
my @s = @( () );
while (glob($^O eq 'MacOS' ? ':*:*.t' : '*/*.t')) {
    #print "# $_\n";
    push @s, $_;
}
print "not " if "{join ' ', <@r}" ne "{join ' ', <@s}";
print "ok 8\n";

# how about in a different package, like?
package Foo;
use File::Glob ':globally';
@s = @( () );
while (glob($^O eq 'MacOS' ? ':*:*.t' : '*/*.t')) {
    #print "# $_\n";
    push @s, $_;
}
print "not " if "{join ' ', <@r}" ne "{join ' ', <@s}";
print "ok 9\n";

# test if different glob ops maintain independent contexts
@s = @( () );
my $i = 0;
if ($^O eq "MacOS") {
    while (glob(":*:*.t")) {
	#print "# $_ <";
	push @s, $_;
	while (glob(":bas*:*.t")) {
	    #print " $_";
	    $i++;
	}
	#print " >\n";
    }
} else {
    while (glob("*/*.t")) {
	#print "# $_ <";
	push @s, $_;
	while (glob("bas*/*.t")) {
	    #print " $_";
	    $i++;
	}
	#print " >\n";
    }
}
print "not " if "{join ' ', <@r}" ne "{join ' ', <@s}" or not $i;
print "ok 10\n";
