#!./perl

print "1..3\n";

my ($err, $x);

$err = "#[\000]\nok 1\n";
eval {
    die $err;
};

print "not " unless $@->{description} eq $err;
print "ok 1\n";

eval {
    local $SIG{__DIE__} = sub { print "ok ", $_[0]->{description}, "\n" } ;

    die 2;

    print "not ";
};

print "ok 3\n";
