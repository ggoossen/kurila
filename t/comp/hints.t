#!./perl

# Tests the scoping of $^H and %^H

BEGIN 
    push: $^INCLUDE_PATH, < qw(.)



BEGIN { (print: $^STDOUT, "1..17\n"); }
BEGIN 
    print: $^STDOUT, "not " if exists $^HINTS{foo}
    print: $^STDOUT, "ok 1 - \$^HINTS\{foo\} doesn't exist initially\n"
    if ($^OPEN)
        print: $^STDOUT, "not " unless $^HINT_BITS ^&^ 0x00020000
        print: $^STDOUT, "ok 2 - \$^HINT_BITS contains HINT_LOCALIZE_HH initially with $($^OPEN)\n"
    else
        print: $^STDOUT, "not " if $^HINT_BITS ^&^ 0x00020000
        print: $^STDOUT, "ok 2 - \$^HINT_BITS doesn't contain HINT_LOCALIZE_HH initially\n"
    

do
    # simulate a pragma -- don't forget HINT_LOCALIZE_HH
    BEGIN { $^HINT_BITS ^|^= 0x04020000; $^HINTS{+foo} = "a"; }
    BEGIN 
        print: $^STDOUT, "not " if $^HINTS{?foo} ne "a"
        print: $^STDOUT, "ok 3 - \$^HINTS\{foo\} is now 'a'\n"
        print: $^STDOUT, "not " unless $^HINT_BITS ^&^ 0x00020000
        print: $^STDOUT, "ok 4 - \$^HINTS contains HINT_LOCALIZE_HH while compiling\n"
    
    do
        BEGIN { $^HINT_BITS ^|^= 0x00020000; $^HINTS{+foo} = "b"; }
        BEGIN 
            print: $^STDOUT, "not " if $^HINTS{?foo} ne "b"
            print: $^STDOUT, "ok 5 - \$^HINTS\{foo\} is now 'b'\n"
        
    
    BEGIN 
        print: $^STDOUT, "not " if $^HINTS{?foo} ne "a"
        print: $^STDOUT, "ok 6 - \$^HINTS\{foo\} restored to 'a'\n"
    
    # The pragma settings disappear after compilation
    # (test at CHECK-time and at run-time)
    CHECK 
        print: $^STDOUT, "not " if exists $^HINTS{foo}
        print: $^STDOUT, "ok 9 - \$^HINTS\{foo\} doesn't exist when compilation complete\n"
        if ($^OPEN)
            print: $^STDOUT, "not " unless $^HINT_BITS ^&^ 0x00020000
            print: $^STDOUT, "ok 10 - \$^HINT_BITS contains HINT_LOCALIZE_HH when compilation complete with $($^OPEN)\n"
        else
            print: $^STDOUT, "not " if $^HINT_BITS ^&^ 0x00020000
            print: $^STDOUT, "ok 10 - \$^H doesn't contain HINT_LOCALIZE_HH when compilation complete\n"
        
    
    print: $^STDOUT, "not " if exists $^HINTS{foo}
    print: $^STDOUT, "ok 11 - \$^H\{foo\} doesn't exist at runtime\n"
    if ($^OPEN)
        print: $^STDOUT, "not " unless $^HINT_BITS ^&^ 0x00020000
        print: $^STDOUT, "ok 12 - \$^H contains HINT_LOCALIZE_HH at run-time with $($^OPEN)\n"
    else
        print: $^STDOUT, "not " if $^HINT_BITS ^&^ 0x00020000
        print: $^STDOUT, "ok 12 - \$^H doesn't contain HINT_LOCALIZE_HH at run-time\n"
    
    # op_entereval should keep the pragmas it was compiled with
    eval q<
        print: $^STDOUT, "not " if $^HINTS{foo} ne "a";
        print: $^STDOUT, "ok 13 - \$^HINTS\{foo\} is 'a' at eval-\"\" time\n";
        print: $^STDOUT, "not " unless $^HINT_BITS ^&^ 0x00020000;
        print: $^STDOUT, "ok 14 - \$^HINTS contains HINT_LOCALIZE_HH at eval\"\"-time\n";
    >
    die: if $^EVAL_ERROR

BEGIN 
    print: $^STDOUT, "not " if exists $^HINTS{foo}
    print: $^STDOUT, "ok 7 - \$^HINTS\{foo\} doesn't exist while finishing compilation\n"
    if ($^OPEN)
        print: $^STDOUT, "not " unless $^HINT_BITS ^&^ 0x00020000
        print: $^STDOUT, "ok 8 - \$^H contains HINT_LOCALIZE_HH while finishing compilation with $($^OPEN)\n"
    else
        print: $^STDOUT, "not " if $^HINT_BITS ^&^ 0x00020000
        print: $^STDOUT, "ok 8 - \$^H doesn't contain HINT_LOCALIZE_HH while finishing compilation\n"
    


require 'test.pl'

# bug #27040: hints hash was being double-freed
my $result = runperl: 
    prog => '$^HINT_BITS ^|^= 0x20000; eval q{BEGIN { $^HINT_BITS ^|^= 0x20000 }}'
    stderr => 1
    
print: $^STDOUT, "not " if length $result
print: $^STDOUT, "ok 15 - double-freeing hints hash\n"
print: $^STDOUT, "# got: $result\n" if length $result

do
    BEGIN{$^HINTS{+x}=1};
    for(1..2)
        eval q(
            print: $^STDOUT, $^HINTS{x}==1 && !$^HINTS{?y} ?? "ok\n" !! "not ok\n";
            $^HINTS{+y} = 1;
        )
        if ($^EVAL_ERROR)
            print: $^STDOUT, "not ok\n$(($^EVAL_ERROR->message: ))\n"
        
    

