BEGIN 
    push: $^INCLUDE_PATH, 'uni'
    require "case.pl"


use utf8

casetest: "Title", \%utf8::ToSpecTitle, sub (@< @_) { ucfirst @_[0] }
         sub (@< @_) { my $a = ""; (ucfirst: @_[0] . $a) }
