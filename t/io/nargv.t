#!./perl

print "1..5\n";

my $j = 1;
for my $i (@( 1,2,5,4,3) ) {
    my $file = mkfiles($i)[0];
    open(FH, ">", "$file") || die "can't create $file: $!";
    print FH "not ok " . $j++ . "\n";
    close(FH) || die "Can't close $file: $!";
}


{
    local *ARGV;
    local $^I = '.bak';
    local $_;
    @ARGV = mkfiles( <1..3);
    my $n = 0;
    while ( ~< *ARGV) {
	print STDOUT "# initial \@ARGV: [{join ' ',@ARGV}]\n";
	if ($n++ == 2) {
	    other();
	}
	show();
    }
}

$^I = undef;
@ARGV = mkfiles( <1..3);
my $n = 0;
while ( ~< *ARGV) {
    print STDOUT "#final \@ARGV: [{join ' ',@ARGV}]\n";
    if ($n++ == 2) {
	other();
    }
    show();
}

sub show {
    #warn "$ARGV: $_";
    s/^not //;
    print;
}

sub other {
    no warnings 'once';
    print STDOUT "# Calling other\n";
    local *ARGV;
    local *ARGVOUT;
    local $_;
    @ARGV = mkfiles(5, 4);
    while ( ~< *ARGV) {
	print STDOUT "# inner \@ARGV: [{join ' ',@ARGV}]\n";
	show();
    }
}

sub mkfiles {
    my @files = map { "scratch$_" } @_;
    return @files;
}

END { unlink < map { ($_, "$_.bak") } mkfiles( <1..5) }
