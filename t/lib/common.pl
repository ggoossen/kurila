# This code is used by lib/warnings.t and lib/feature.t

BEGIN {
    require './test.pl';
}

use Config;
use File::Path;
use File::Spec::Functions;

use strict;
use warnings;
our $pragma_name;

our $got_files = 0; # set to 1 to generate output files.

$| = 1;

my $Is_MacOS = $^O eq 'MacOS';
my $tmpfile = "tmp0000";
1 while -e ++$tmpfile;
END { 1 while unlink $tmpfile }

my @prgs = () ;
my @w_files = () ;

if (@ARGV)
  { print "ARGV = [@ARGV]\n" ;
    if ($Is_MacOS) {
      @w_files = map { s#^#:lib:$pragma_name:#; $_ } @ARGV
    } else {
      @w_files = map { s#^#./lib/$pragma_name/#; $_ } @ARGV
    }
  }
else
  { @w_files = sort glob(catfile(curdir(), "lib", $pragma_name, "*")) }

my $files = 0;
foreach my $file (@w_files) {

    next if $file =~ m/(~|\.orig|\.got|,v)$/;
    next if $file =~ m/perlio$/ && !('PerlIO::Layer'->find( 'perlio'));
    next if -d $file;

    open F, "<", "$file" or die "Cannot open $file: $!\n" ;
    my $line = 0;
    open my $got_file, ">", "$file.got" or die if $got_files;
    while ( ~< *F) {
        print $got_file $_ if $got_files;
        $line++;
	last if m/^__END__/ ;
    }
    close $got_file if $got_files;

    {
        local $/ = undef;
        $files++;
        @prgs = (@prgs, $file, split "\n########\n", ~< *F) ;
    }
    close F ;
}

undef $/;

plan tests => (scalar(@prgs)-$files);

my $out_file;
my $file;
for (@prgs){
    unless (m/\n/)
     {
      print "# From $_\n";
      $file = $_;

      if ($got_files) {
          close $out_file if $out_file;
          open $out_file, ">>", "$file.got" or die;
      }
      next;
     }
    my $src = $_;
    my $switch = "";
    my @temps = () ;
    my @temp_path = () ;
    if (s/^\s*-\w+//){
        $switch = $&;
    }
    my($prog,$expected) = split(m/\nEXPECT(?:\n|$)/, $_, 2);

    my ($todo, $todo_reason);
    $todo = $prog =~ s/^#\s*TODO\s*(.*)\n//m and $todo_reason = $1;
    # If the TODO reason starts ? then it's taken as a code snippet to evaluate
    # This provides the flexibility to have conditional TODOs
    if ($todo_reason && $todo_reason =~ s/^\?//) {
	my $temp = eval $todo_reason;
	if ($@) {
	    die "# In TODO code reason:\n# $todo_reason\n$@";
	}
	$todo_reason = $temp;
    }
    if ( $prog =~ m/--FILE--/) {
        my(@files) = split(m/\n--FILE--\s*([^\s\n]*)\s*\n/, $prog) ;
	shift @files ;
	die "Internal error: test $_ didn't split into pairs, got " .
		scalar(@files) . "[" . join("%%%%", @files) ."]\n"
	    if @files % 2 ;
	while (@files +> 2) {
	    my $filename = shift @files ;
	    my $code = shift @files ;
    	    push @temps, $filename ;
    	    if ($filename =~ m#(.*)/#) {
                mkpath($1);
                push(@temp_path, $1);
    	    }
	    open F, ">", "$filename" or die "Cannot open $filename: $!\n" ;
	    print F $code ;
	    close F or die "Cannot close $filename: $!\n";
	}
	shift @files ;
	$prog = shift @files ;
    }

    # fix up some paths
    if ($Is_MacOS) {
	$prog =~ s|require "./abc(d)?";|require ":abc$1";|g;
	$prog =~ s|"\."|":"|g;
    }

    open TEST, ">", "$tmpfile" or die "Cannot open >$tmpfile: $!";
    print TEST q{
        BEGIN {
            open(STDERR, ">&", "STDOUT")
              or die "Can't dup STDOUT->STDERR: $!;";
        }
    };
    print TEST "\n#line 1\n";  # So the line numbers don't get messed up.
    print TEST $prog,"\n";
    close TEST or die "Cannot close $tmpfile: $!";
    my $results = runperl( switches => [$switch], stderr => 1, progfile => $tmpfile );
    my $status = $?;
    $results =~ s/\n+$//;
    # allow expected output to be written as if $prog is on STDIN
    $results =~ s/tmp\d+/-/g;
    $results =~ s|at \.\./lib/warnings\.pm line \d*\.|at .../warnings.pm line xxx.|g;
    if ($^O eq 'VMS') {
        # some tests will trigger VMS messages that won't be expected
        $results =~ s/\n?%[A-Z]+-[SIWEF]-[A-Z]+,.*//;

        # pipes double these sometimes
        $results =~ s/\n\n/\n/g;
    }
# bison says 'parse error' instead of 'syntax error',
# various yaccs may or may not capitalize 'syntax'.
    $results =~ s/^(syntax|parse) error/syntax error/mig;
    # allow all tests to run when there are leaks
    $results =~ s/Scalars leaked: \d+\n//g;

    # fix up some paths
    if ($Is_MacOS) {
	$results =~ s|:abc\.pm\b|abc.pm|g;
	$results =~ s|:abc(d)?\b|./abc$1|g;
    }

    $expected =~ s/\n+$//;
    my $prefix = ($results =~ s#^PREFIX(\n|$)##) ;
    # any special options? (OPTIONS foo bar zap)
    my $option_regex = 0;
    my $option_random = 0;
    if ($expected =~ s/^OPTIONS? (.+)\n//) {
	foreach my $option (split(' ', $1)) {
	    if ($option eq 'regex') { # allow regular expressions
		$option_regex = 1;
	    }
	    elsif ($option eq 'random') { # all lines match, but in any order
		$option_random = 1;
	    }
	    else {
		die "$0: Unknown OPTION '$option'\n";
	    }
	}
    }
    die "$0: can't have OPTION regex and random\n"
        if $option_regex + $option_random +> 1;
    my $ok = 0;
    if ($results =~ s/^SKIPPED\n//) {
	print "$results\n" ;
	$ok = 1;
    }
    elsif ($option_random) {
        $ok = randomMatch($results, $expected);
    }
    elsif ($option_regex) {
	$ok = $results =~ m/^$expected/;
    }
    elsif ($prefix) {
	$ok = $results =~ m/^\Q$expected/;
    }
    else {
	$ok = $results eq $expected;

        $src =~ s/\nEXPECT(?:\n|$)(.|\n)*/\nEXPECT\n$results/;
    }
    print $out_file $src, "\n########\n" if $got_files;
 
    print_err_line( $switch, $prog, $expected, $results, $todo, $file ) unless $ok;

    our $TODO = $todo ? $todo_reason : 0;
    ok($ok);

    foreach (@temps)
	{ unlink $_ if $_ }
    foreach (@temp_path)
	{ rmtree $_ if -d $_ }
}

sub randomMatch
{
    my $got = shift ;
    my $expected = shift;

    my @got = sort split "\n", $got ;
    my @expected = sort split "\n", $expected ;

   return "@got" eq "@expected";

}

sub print_err_line {
    my($switch, $prog, $expected, $results, $todo) = @_;
    my $err_line = "FILE: $file\n" .
                   "PROG: $switch\n$prog\n" .
		   "EXPECTED:\n$expected\n" .
		   "GOT:\n$results\n";
    if ($todo) {
	$err_line =~ s/^/# /mg;
	print $err_line;  # Harness can't filter it out from STDERR.
    }
    else {
	print STDERR $err_line;
    }

    return 1;
}

1;
