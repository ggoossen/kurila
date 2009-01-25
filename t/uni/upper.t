BEGIN {
    push $^INCLUDE_PATH, 'uni';
    require "case.pl";
}

use utf8;

casetest("Upper", \%utf8::ToSpecUpper, sub { uc @_[0] },
	 sub { my $a = ""; uc (@_[0] . $a) });
