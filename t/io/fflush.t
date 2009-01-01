#!./perl

BEGIN {
    require './test.pl';
}

# Script to test auto flush on fork/exec/system/qx.  The idea is to
# print "Pe" to a file from a parent process and "rl" to the same file
# from a child process.  If buffers are flushed appropriately, the
# file should contain "Perl".  We'll see...
use Config;
use warnings;

# This attempts to mirror the #ifdef forest found in perl.h so that we
# know when to run these tests.  If that forest ever changes, change
# it here too or expect test gratuitous test failures.
my $useperlio = defined config_value("useperlio") ?? config_value("useperlio") eq 'define' ?? 1 !! 0 !! 0;
my $fflushNULL = defined config_value("fflushNULL") ?? config_value("fflushNULL") eq 'define' ?? 1 !! 0 !! 0;
my $d_sfio = defined config_value("d_sfio") ?? config_value("d_sfio") eq 'define' ?? 1 !! 0 !! 0;
my $fflushall = defined config_value("fflushall") ?? config_value("fflushall") eq 'define' ?? 1 !! 0 !! 0;
my $d_fork = defined config_value("d_fork") ?? config_value("d_fork") eq 'define' ?? 1 !! 0 !! 0;

if ($useperlio || $fflushNULL || $d_sfio) {
    print "1..7\n";
} else {
    if ($fflushall) {
	print "1..7\n";
    } else {
	print "1..0 # Skip: fflush(NULL) or equivalent not available\n";
        exit;
    }
}

my $runperl = $^X =~ m/\s/ ?? qq{"$^X"} !! $^X;
$runperl .= qq{ "-I../lib"};

my @delete;

END {
    for ( @delete) {
	unlink $_ or warn "unlink $_: $^OS_ERROR";
    }
}

sub file_eq {
    my $f   = shift;
    my $val = shift;

    open IN, "<", $f or die "open $f: $^OS_ERROR";
    chomp(my $line = ~< *IN);
    close IN;

    print "# got $line\n";
    print "# expected $val\n";
    return $line eq $val;
}

# This script will be used as the command to execute from
# child processes
open PROG, ">", "ff-prog" or die "open ff-prog: $^OS_ERROR";
print PROG <<'EOF';
my $f = shift(@ARGV);
my $str = shift(@ARGV);
open OUT, ">>", "$f" or die "open $f: $^OS_ERROR";
print OUT $str;
close OUT;
EOF
    ;
close PROG or die "close ff-prog: $^OS_ERROR";;
push @delete, "ff-prog";

$^OUTPUT_AUTOFLUSH = 0; # we want buffered output

# Test flush on fork/exec
if (!$d_fork) {
    print "ok 1 # skipped: no fork\n";
} else {
    my $f = "ff-fork-$^PID";
    open OUT, ">", "$f" or die "open $f: $^OS_ERROR";
    print OUT "Pe";
    my $pid = fork;
    if ($pid) {
	# Parent
	wait;
	close OUT or die "close $f: $^OS_ERROR";
    } elsif (defined $pid) {
	# Kid
	print OUT "r";
	my $command = qq{$runperl "ff-prog" "$f" "l"};
	print "# $command\n";
	exec $command or die $^OS_ERROR;
	exit;
    } else {
	# Bang
	die "fork: $^OS_ERROR";
    }

    print file_eq($f, "Perl") ?? "ok 1\n" !! "not ok 1\n";
    push @delete, $f;
}

# Test flush on system/qx/pipe open
my %subs = %(
            "system" => sub {
                my $c = shift;
                system $c;
            },
            "qx"     => sub {
                my $c = shift;
                qx{$c};
            },
            "popen"  => sub {
                my $c = shift;
                open PIPE, "-|", "$c" or die "$c: $^OS_ERROR";
                close PIPE;
            },
            );
my $t = 2;
for (qw(system qx popen)) {
    my $code    = %subs{?$_};
    my $f       = "ff-$_-$^PID";
    my $command = qq{$runperl "ff-prog" "$f" "rl"};
    open OUT, ">", "$f" or die "open $f: $^OS_ERROR";
    print OUT "Pe";
    close OUT or die "close $f: $^OS_ERROR";;
    print "# $command\n";
    $code->($command);
    print file_eq($f, "Perl") ?? "ok $t\n" !! "not ok $t\n";
    push @delete, $f;
    ++$t;
}

my $cmd = _create_runperl(
			  switches => \@('-l'),
			  prog =>
			  sprintf('print qq[ok $_] for (%d..%d)', $t, $t+2));
print "# cmd = '$cmd'\n";
open my $CMD, '-|', "$cmd" or die "Can't open pipe to '$cmd': $^OS_ERROR";
while ( ~< $CMD) {
    system("$runperl -e 0");
    print;
}
close $CMD;
$t += 3;
