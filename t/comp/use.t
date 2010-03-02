#!./perl

BEGIN 
    $^INCLUDED{+"feature.pm"} = 1 # so we don't attempt to load feature.pm


print: $^STDOUT, "1..26\n"

# Can't require test.pl, as we're testing the use/require mechanism here.

my $test = 1

sub _ok($type, $got, $expected, ?$name)

    my $result
    if ($type eq 'is')
        $result = $got eq $expected
    elsif ($type eq 'isnt')
        $result = $got ne $expected
    elsif ($type eq 'like')
        $result = $got =~ $expected
    else
        die: "Unexpected type '$type'$name"
    
    if ($result)
        if ($name)
            print: $^STDOUT, "ok $test - $name\n"
        else
            print: $^STDOUT, "ok $test\n"
        
    else
        if ($name)
            print: $^STDOUT, "not ok $test - $name\n"
        else
            print: $^STDOUT, "not ok $test\n"
        
        my @caller = @:  caller: 2 
        print: $^STDOUT, "# Failed test at @caller[1] line @caller[2]\n"
        print: $^STDOUT, "# Got      '$got'\n"
        if ($type eq 'is')
            print: $^STDOUT, "# Expected '$expected'\n"
        elsif ($type eq 'isnt')
            print: $^STDOUT, "# Expected not '$expected'\n"
        elsif ($type eq 'like')
            print: $^STDOUT, "# Expected $expected\n"
        
    
    $test = $test + 1
    $result


sub like
    _ok: 'like', < @_

sub is
    _ok: 'is', < @_

sub isnt
    _ok: 'isnt', < @_


eval "use 5.000"	# implicit semicolon
like: ($^EVAL_ERROR->message: ), qr/use VERSION is not valid in Perl Kurila/

eval "use 5.000;"
like: ($^EVAL_ERROR->message: ), qr/use VERSION is not valid in Perl Kurila/

eval "use 6.000;"
like: ($^EVAL_ERROR->message: ), qr/use VERSION is not valid in Perl Kurila/

# fake package 'testuse'
our $testimport
our $version_check
$^INCLUDED{+'testuse.pm'} = 1
*testuse::import = sub (@< @_) { $testimport = \ @_ }
*testuse::VERSION = sub (@< @_) { $version_check = @_[1] }

# test calling of 'VERSION' and 'import' with correct arguments
eval "use testuse v0.9"
is: $^EVAL_ERROR, ''
is: $version_check->{?'original'}, "v0.9"
is:  (nelems $testimport->@), 1, "import called with only packagename"

# test the default VERSION check.
undef *testuse::VERSION
$testuse::VERSION = 1.0

eval "use testuse v0.9"
is: $^EVAL_ERROR, ''

eval "use testuse v1.0"
is: $^EVAL_ERROR, ''

eval "use testuse v1.01"
like: ($^EVAL_ERROR->message: ), qr/testuse version v1.1.0 required--this is only version v1.0.0/

eval "use testuse v0.9 q(fred)"
is: $^EVAL_ERROR, ''
is: $testimport->[1], "fred"

eval "use testuse v1.0 q(joe)"
is: $^EVAL_ERROR, ''
is: $testimport->[1], "joe"

eval "use testuse v1.01 q(freda)"
isnt:  ref $^EVAL_ERROR, '' 
is: $testimport->[1], "joe", "testimport is still 'joe'"

do
    local $testuse::VERSION = 35.36
    eval "use testuse v33.55"
    is: $^EVAL_ERROR, ''

    eval "use testuse v100.105"
    like: ($^EVAL_ERROR->message: ), qr/testuse version v100.105.0 required--this is only version v35\.360\.0/

    eval "use testuse v33.55"
    is: $^EVAL_ERROR, ''

    local $testuse::VERSION = '35.36'
    eval "use testuse v33.55"
    like: $^EVAL_ERROR && $^EVAL_ERROR->{?description}, ''

    eval "use testuse v100.105"
    like: ($^EVAL_ERROR->message: ), qr/testuse version v100.105.0 required--this is only version v35\.360\.0/

    eval "use testuse v33.55"
    is: $^EVAL_ERROR, ''

    eval "use testuse v100.105"
    like: ($^EVAL_ERROR->message: ), qr/testuse version v100.105.0 required--this is only version v35.360.0/

    local $testuse::VERSION = v35.36
    eval "use testuse v33.55"
    is: $^EVAL_ERROR, ''

    eval "use testuse v100.105"
    like: ($^EVAL_ERROR->message: ), qr/testuse version v100.105.0 required--this is only version v35\.36\.0/

    eval "use testuse v33.55"
    is: $^EVAL_ERROR, ''



do
    # Regression test for patch 14937:
    #   Check that a .pm file with no package or VERSION doesn't core.
    open: my $f, ">", "xxx.pm" or die: "Cannot open xxx.pm: $^OS_ERROR\n"
    print: $f, "1;\n"
    close $f
    eval "use lib '.'; use xxx v3;"
    like: ($^EVAL_ERROR->message: ), qr/^xxx defines neither package nor VERSION--version check failed/
    unlink: 'xxx.pm'

