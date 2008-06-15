BEGIN {
    push @INC, 'uni';
    require "case.pl";
}

use utf8;

casetest("Title", \%utf8::ToSpecTitle, sub { ucfirst @_[0] },
	 sub { my $a = ""; ucfirst (@_[0] . $a) });
