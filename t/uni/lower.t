BEGIN {
    push $^INCLUDE_PATH, < qw(uni .);
    require "case.pl";
}

use utf8;

casetest("Lower", \%utf8::ToSpecLower,
	 sub { lc @_[0] }, sub { my $a = ""; lc (@_[0] . $a) },
	 sub { lcfirst @_[0] }, sub { my $a = ""; lcfirst (@_[0] . $a) });
