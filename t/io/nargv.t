#!./perl

print \*STDOUT, "1..5\n";

my $j = 1;
for my $i (@( 1,2,5,4,3) ) {
    my $file = mkfiles($i)[0];
    open(my $fh, ">", "$file") || die "can't create $file: $^OS_ERROR";
    print $fh, "not ok " . $j++ . "\n";
    close($fh) || die "Can't close $file: $^OS_ERROR";
}


do {
    local *ARGV;
    local $^INPLACE_EDIT = '.bak';
    @ARGV = mkfiles( <1..3);
    my $n = 0;
    while ( ~< *ARGV) {
	print \*STDOUT, "# initial \@ARGV: [$(join ' ',@ARGV)]\n";
	if ($n++ == 2) {
	    other();
	}
	show($_);
    }
};

$^INPLACE_EDIT = undef;
@ARGV = mkfiles( <1..3);
my $n = 0;
while ( ~< *ARGV) {
    print \*STDOUT, "#final \@ARGV: [$(join ' ',@ARGV)]\n";
    if ($n++ == 2) {
	other();
    }
    show($_);
}

sub show {
    my $_ = shift;
    #warn "$ARGV: $_";
    s/^not //;
    print \*STDOUT,;
}

sub other {
    no warnings 'once';
    print \*STDOUT, "# Calling other\n";
    local *ARGV;
    local *ARGVOUT;
    @ARGV = mkfiles(5, 4);
    while ( ~< *ARGV) {
	print \*STDOUT, "# inner \@ARGV: [$(join ' ',@ARGV)]\n";
	show($_);
    }
}

sub mkfiles {
    my @files = map { "scratch$_" } @_;
    return @files;
}

END { unlink < map { ($_, "$_.bak") } mkfiles( <1..5) }
