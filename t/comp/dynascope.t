
BEGIN 
    require "./test.pl"


plan: tests => 10

do
    ## test basic dynascope scope

    my $mainscope = dynascope
    is:  $mainscope, dynascope 
    do
        isnt:  $mainscope, dynascope 
        is:  $mainscope, dynascope->{parent} 
    
    is:  $mainscope, dynascope 


do
    ## test leave hook

    my $leave = 0
    do
        push: dynascope->{onleave}, sub (@< @_) { $leave++ }
        is:  $leave, 0
    
    is:  $leave, 1


do
    ## test leave hook with "die"

    my $leave = 0
    try {
        push: dynascope->{onleave}, sub (@< @_) { $leave++ };
        (is:  $leave, 0);
        die: "xx";
    }
    is:  $leave, 1
    is:  $^EVAL_ERROR->description, "xx" 


do
    ## test 'die' inside 'onleave'

    try {
        push: dynascope->{onleave}, sub (@< @_) { (die: "inside onleave") };
    }
    is:  $^EVAL_ERROR->description, "inside onleave" 

