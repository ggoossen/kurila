#!./perl

# Note : we're not using t/test.pl here, because we would need
# fresh_perl_is, and fresh_perl_is uses a closure -- a special
# case of what this program tests for.


BEGIN { require "./test.pl" }

my $Is_VMS = $^O eq 'VMS';
my $Is_MSWin32 = $^O eq 'MSWin32';
my $Is_MacOS = $^O eq 'MacOS';
my $Is_NetWare = $^O eq 'NetWare';
env::set_var('PERL5LIB' => "../lib") unless $Is_VMS;

our $i = 0;

$^OUTPUT_AUTOFLUSH=1;

undef $^INPUT_RECORD_SEPARATOR;
my @prgs = split "\n########\n", ~< *DATA;
plan(6 + scalar nelems @prgs);

my $tmpfile = "asubtmp000";
1 while -f ++$tmpfile;
END { if ($tmpfile) { 1 while unlink $tmpfile; } }

for ( @prgs){
    my $switch = "";
    if (s/^\s*(-\w+)//){
       $switch = $1;
    }
    my@($prog,$expected) =  split(m/\nEXPECT\n/, $_);
    open TEST, ">", "$tmpfile";
    print TEST "$prog\n";
    close TEST or die "Could not close: $^OS_ERROR";
    my $results = $Is_VMS ??
		`$^X "-I[-.lib]" $switch $tmpfile 2>&1` !!
		  $Is_MSWin32 ??
		    `.\\perl -I../lib $switch $tmpfile 2>&1` !!
		      $Is_MacOS ??  
			`$^X -I::lib $switch $tmpfile` !!
			    $Is_NetWare ??
				`perl -I../lib $switch $tmpfile 2>&1` !!
				    `./perl $switch $tmpfile 2>&1`;
    my $status = $^CHILD_ERROR;
    $results =~ s/\n+$//;
    # allow expected output to be written as if $prog is on STDIN
    $results =~ s/runltmp\d+/-/g;
    $results =~ s/\n%[A-Z]+-[SIWEF]-.*$// if $Is_VMS;  # clip off DCL status msg
    $expected =~ s/\n+$//;
    if ($results ne $expected) {
       print STDERR "PROG: $switch\n$prog\n";
    }
    is($results, $expected);
}

sub test_invalid_decl {
    my @($code,?$todo) =  @_;
    local our $TODO = $todo;
    eval_dies_like( $code,
                    qr/^Illegal declaration of anonymous subroutine/);
}

test_invalid_decl('sub;');
test_invalid_decl('sub ($) ;');
test_invalid_decl('do { my $x = sub }');
test_invalid_decl('sub ($) && 1');
test_invalid_decl('sub ($) : lvalue;',' # TODO');

eval "sub #foo\n\{print 1\}";
is $^EVAL_ERROR, '', "No error"

__END__
sub X {
    my $n = "ok 1\n";
    sub { print $n };
}
my $x = X();
undef &X;
$x->();
EXPECT
ok 1
########
sub X {
    my $n = "ok 1\n";
    sub {
        my $dummy = $n;	# eval can't close on $n without internal reference
	eval 'print $n';
	die $^EVALERROR if $^EVALERROR;
    };
}
my $x = X();
undef &X;
$x->();
EXPECT
ok 1
########
sub X {
    my $n = "ok 1\n";
    eval 'sub { print $n }';
}
my $x = X();
die $^EVALERROR if $^EVALERROR;
undef &X;
$x->();
EXPECT
ok 1
########
print sub { return "ok 1\n" } -> ();
EXPECT
ok 1
