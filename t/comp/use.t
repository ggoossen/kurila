#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    $INC{"feature.pm"} = 1; # so we don't attempt to load feature.pm
}

print "1..26\n";

# Can't require test.pl, as we're testing the use/require mechanism here.

my $test = 1;

sub _ok {
    my ($type, $got, $expected, $name) = @_;

    my $result;
    if ($type eq 'is') {
	$result = $got eq $expected;
    } elsif ($type eq 'isnt') {
	$result = $got ne $expected;
    } elsif ($type eq 'like') {
	$result = $got =~ $expected;
    } else {
	die "Unexpected type '$type'$name";
    }
    if ($result) {
	if ($name) {
	    print "ok $test - $name\n";
	} else {
	    print "ok $test\n";
	}
    } else {
	if ($name) {
	    print "not ok $test - $name\n";
	} else {
	    print "not ok $test\n";
	}
	my @caller = caller(2);
	print "# Failed test at $caller[1] line $caller[2]\n";
	print "# Got      '$got'\n";
	if ($type eq 'is') {
	    print "# Expected '$expected'\n";
	} elsif ($type eq 'isnt') {
	    print "# Expected not '$expected'\n";
	} elsif ($type eq 'like') {
	    print "# Expected $expected\n";
	}
    }
    $test = $test + 1;
    $result;
}

sub like ($$;$) {
    _ok ('like', @_);
}
sub is ($$;$) {
    _ok ('is', @_);
}
sub isnt ($$;$) {
    _ok ('isnt', @_);
}

eval "use 5.000";	# implicit semicolon
like ($@->message, qr/use VERSION is not valid in Perl Kurila/);

eval "use 5.000;";
like ($@->message, qr/use VERSION is not valid in Perl Kurila/);

eval "use 6.000;";
like ($@->message, qr/use VERSION is not valid in Perl Kurila/);

# fake package 'testuse'
our $testimport;
our $version_check;
$INC{'testuse.pm'} = 1;
*testuse::import = sub { $testimport = [@_] };
*testuse::VERSION = sub { $version_check = $_[1] };

# test calling of 'VERSION' and 'import' with correct arguments
eval "use testuse v0.9";
is ($@, '');
is $version_check->{'original'}, "v0.9";
is @{$testimport}, 1, "import called with only packagename";

# test the default VERSION check.
undef *testuse::VERSION;
$testuse::VERSION = 1.0;

eval "use testuse v0.9";
is ($@, '');

eval "use testuse v1.0";
is ($@, '');

eval "use testuse v1.01";
like ($@->message, qr/testuse version v1.1.0 required--this is only version v1.0.0/);

eval "use testuse v0.9 qw(fred)";
is ($@, '');
is $testimport->[1], "fred";

eval "use testuse v1.0 qw(joe)";
is ($@, '');
is $testimport->[1], "joe";

eval "use testuse v1.01 qw(freda)";
isnt($@, '');
is $testimport->[1], "joe", "testimport is still 'joe'";

{
    local $testuse::VERSION = 35.36;
    eval "use testuse v33.55";
    is ($@, '');

    eval "use testuse v100.105";
    like ($@->message, qr/testuse version v100.105.0 required--this is only version v35\.360\.0/);

    eval "use testuse v33.55";
    is ($@, '');

    local $testuse::VERSION = '35.36';
    eval "use testuse v33.55";
    like ($@ && $@->{description}, '');

    eval "use testuse v100.105";
    like ($@->message, qr/testuse version v100.105.0 required--this is only version v35\.360\.0/);

    eval "use testuse v33.55";
    is ($@, '');

    eval "use testuse v100.105";
    like ($@->message, qr/testuse version v100.105.0 required--this is only version v35.360.0/);

    local $testuse::VERSION = v35.36;
    eval "use testuse v33.55";
    is ($@, '');

    eval "use testuse v100.105";
    like ($@->message, qr/testuse version v100.105.0 required--this is only version v35\.36\.0/);

    eval "use testuse v33.55";
    is ($@, '');
}


{
    # Regression test for patch 14937: 
    #   Check that a .pm file with no package or VERSION doesn't core.
    open F, ">", "xxx.pm" or die "Cannot open xxx.pm: $!\n";
    print F "1;\n";
    close F;
    eval "use lib '.'; use xxx v3;";
    like ($@->message, qr/^xxx defines neither package nor VERSION--version check failed at/);
    unlink 'xxx.pm';
}
