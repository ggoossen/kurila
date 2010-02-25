#!perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


use Test::More tests => 17

# If we skip with the same name, Test::Harness will report it back and
# we won't get lots of false bug reports.
my $Why = "Just testing the skip interface."

:SKIP do
    skip: $Why, 2
        unless Pigs->can: 'fly'

    my $pig = Pigs->new: 
    $pig->takeoff: 

    ok:  ($pig->altitude: ) +> 0,         'Pig is airborne' 
    ok:  ($pig->airspeed: ) +> 0,         '  and moving'    



:SKIP do
    (skip: "We're not skipping", 2) if 0

    pass: "Inside skip block"
    pass: "Another inside"



:SKIP do
    (skip: "Again, not skipping", 2) if 0

    my (@: ?$pack, ?$file, ?$line) =@:  caller
    is:  $pack || '', '',      'calling package not interfered with' 
    is:  $file || '', '',      '  or file' 
    is:  $line || '', '',      '  or line' 



:SKIP do
    (skip: $Why, 2) if 1

    die: "A horrible death"
    fail: "Deliberate failure"
    fail: "And again"



do
    my $warning
    local $^WARN_HOOK = sub (@< @_) { $warning = @_[0]->message: }
    :SKIP do
        # perl gets the line number a little wrong on the first
        # statement inside a block.
        1 == 1
        #line 56
        skip: $Why
        fail: "So very failed"
    
    like:  $warning, qr/skip\(\) needs to know \$how_many tests are in the block/ms
           'skip without $how_many warning' 



:SKIP do
    (skip: "Not skipping here.", 4) if 0

    pass: "This is supposed to run"

    # Testing out nested skips.
    :SKIP do
        skip: $Why, 2
        fail: "AHHH!"
        fail: "You're a failure"
    

    pass: "This is supposed to run, too"


do
    my $warning = ''
    local $^WARN_HOOK = sub (@< @_) { $warning .= @_[0]->message: }

    :SKIP do
        (skip: 1, "This is backwards") if 1

        pass: "This does not run"
    

    like: $warning, '/^skip\(\) was passed a non-numeric number of tests/'

