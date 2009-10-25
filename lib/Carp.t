BEGIN 
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @:  '../lib' 
    require './test.pl'


my $Is_VMS = $^OS_NAME eq 'VMS'

use Carp < qw(carp cluck croak confess)

plan: tests => 5

our $TODO = "Figure out what to do with Carp"

ok: 1

do 
    local $^WARN_HOOK = sub (@< @_)
        like: (@_[0]->message: ), qr/ok (\d+)\n at.+\b(?i:carp\.t) line \d+/, 'ok 2\n'

    carp: "ok 2\n"

do 
    local $^WARN_HOOK = sub (@< @_)
        like: (@_[0]->message: ), qr/(\d+) at.+\b(?i:carp\.t) line \d+$/, 'carp 3' 

    carp: 3

sub sub_4

    local $^WARN_HOOK = sub (@< @_)
        like: (@_[0]->message: ), qr/^(\d+) at.+\b(?i:carp\.t) line \d+\n\tmain::sub_4\(\) called at.+\b(?i:carp\.t) line \d+$/, 'cluck 4' 

    cluck: 4



(sub_4: )

do 
    local $^DIE_HOOK = sub (@< @_)
        like: (@_[0]->message: ), qr/^(\d+) at.+\b(?i:carp\.t) line \d+\n\teval \Q{...}\E called at.+\b(?i:carp\.t) line \d+$/, 'croak 5'

    try { (croak: 5) }


sub sub_6
    local $^DIE_HOOK = sub (@< @_)
        like: (@_[0]->message: ), qr/^(\d+) at.+\b(?i:carp\.t) line \d+\n\teval \Q{...}\E called at.+\b(?i:carp\.t) line \d+\n\tmain::sub_6\(\) called at.+\b(?i:carp\.t) line \d+$/, 'confess 6' 

    try { (confess: 6) }


(sub_6: )

ok: 1
