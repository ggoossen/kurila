#!./perl
#
# check if builtins behave as prototyped
#

print: $^STDOUT, "1..7\n"

my $i = 1

sub foo {}
my $bar = "bar"

sub test_too_many
    eval @_[0]
    print: $^STDOUT, "not " unless $^EVAL_ERROR->{?description} =~ m/^Too many arguments/
    printf: $^STDOUT, "ok \%d\n",$i++


sub test_no_error
    eval @_[0]
    print: $^STDOUT, "not " if $^EVAL_ERROR
    printf: $^STDOUT, "ok \%d\n",$i++


for (split: m/\n/
            q[	defined(&foo, $bar);
	undef(&foo, $bar);
	uc($bar,$bar);
])
    test_too_many: $_

for (split: m/\n/
            q[ defined &foo, &foo, &foo;
   undef &foo, $bar;
	uc $bar,$bar;
	grep( { not($bar) }, @: $bar);
])
    test_no_error: $_
