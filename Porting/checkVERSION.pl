#!/usr/bin/perl -w

#
# Check the tree against missing VERSIONs.
#
# Originally by Larry Shatzer
#


use File::Find;

find(
     sub {
	 return unless -f;
	 if (m/\.pm$/ && $File::Find::name !~ m:/t/:) { # pm but not in a test
	     unless (parse_file($_)) {
		 print "$File::Find::name\n";
	     }
	 }
     }, (nelems @ARGV) ?? shift !! ".");

sub parse_file {
    my $parsefile = shift;

    my $result;

    open(FH, "<",$parsefile) or warn "Could not open '$parsefile': $^OS_ERROR";

    my $inpod = 0;
    while ( ~< *FH) {
	$inpod = m/^=(?!cut)/ ?? 1 !! m/^=cut/ ?? 0 !! $inpod;
	next if $inpod || m/^\s*\#/;
	chomp;
	next unless m/([\$*])(([\w\:\']*)\bVERSION)\b.*\=/;
	my $eval = qq{
	    package ExtUtils::MakeMaker::_version;
	    local $1$2;
	    \$$2=undef; do \{
		$_
	    \}; \$$2
	};
	no warnings;
	$result = eval($eval);
	warn "Could not eval '$eval' in $parsefile: $^EVAL_ERROR" if $^EVAL_ERROR;
	$result = "undef" unless defined $result;
	last;
    }
    close FH;
    return $result;
}

