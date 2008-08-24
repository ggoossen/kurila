#!./perl
#
# check if builtins behave as prototyped
#

print "1..7\n";

my $i = 1;

sub foo {}
my $bar = "bar";

sub test_too_many {
    eval @_[0];
    print "not " unless $@->{description} =~ m/^Too many arguments/;
    printf "ok \%d\n",$i++;
}

sub test_no_error {
    eval @_[0];
    print "not " if $@;
    printf "ok \%d\n",$i++;
}

test_too_many($_) for split m/\n/,
q[	defined(&foo, $bar);
	undef(&foo, $bar);
	uc($bar,$bar);
];

test_no_error($_) for split m/\n/,
q[ defined &foo, &foo, &foo;
   undef &foo, $bar;
	uc $bar,$bar;
	grep(not($bar), @($bar));
];
