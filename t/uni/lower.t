BEGIN 
    push: $^INCLUDE_PATH, < qw(uni .)
    require "case.pl"


use utf8

casetest: "Lower", \%utf8::ToSpecLower
         sub (@< @_) { lc @_[0] }, sub (@< @_) { my $a = ""; (lc: @_[0] . $a) }
         sub (@< @_) { lcfirst @_[0] }, sub (@< @_) { my $a = ""; (lcfirst: @_[0] . $a) }
