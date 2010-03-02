#!/usr/bin/perl
$^OUTPUT_AUTOFLUSH = 1

# Note that because fork loses test count we do not use Test::More


use Config
BEGIN 
    my $can_fork = (config_value: 'd_fork') ||
        (($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare') and
         config_value: 'useithreads' and
         (config_value: 'ccflags') =~ m/-DPERL_IMPLICIT_SYS/
         )
    if ( $can_fork )
        print: $^STDOUT, "1..8\n"
    else
        print: $^STDOUT, "1..0 # Skip No fork available\n"
        exit
    


use File::Temp

# OO interface

my $file = File::Temp->new: CLEANUP=>1

myok:  1, -f ($file->filename: ), "OO File exists" 

my $children = 2
for my $i (1 .. $children)
    my $pid = fork
    die: "Can't fork: $^OS_ERROR" unless defined $pid
    if ($pid)
        # parent process
        next
    else
        # in a child we can't keep the count properly so we do it manually
        # make sure that child 1 dies first
        (srand: )
        my $time = (($i-1) * 5) +int: (rand: 5)
        print: $^STDOUT, "# child $i sleeping for $time seconds\n"
        sleep: $time
        my $count = $i + 1
        myok:  $count, -f ($file->filename: ), "OO file present in child $i" 
        print: $^STDOUT, "# child $i exiting\n"
        exit
    


while ($children)
    wait
    $children--




myok:  4, -f ($file->filename: ), "OO File exists in parent" 

# non-OO interface

my (@: $fh, $filename) =  (File::Temp::tempfile: )

myok:  5, -f $filename, "non-OO File exists" 

$children = 2
for my $i (1 .. $children)
    my $pid = fork
    die: "Can't fork: $^OS_ERROR" unless defined $pid
    if ($pid)
        # parent process
        next
    else
        (srand: )
        my $time = (($i-1) * 5) +int: (rand: 5)
        print: $^STDOUT, "# child $i sleeping for $time seconds\n"
        sleep: $time
        my $count = 5 + $i
        myok:  $count, -f $filename, "non-OO File present in child $i" 
        print: $^STDOUT, "# child $i exiting\n"
        exit
    


while ($children)
    wait
    $children--

myok: 8, -f $filename, "non-OO File exists in parent" 
unlink: $filename   # Cleanup


# Local ok sub handles explicit number
sub myok($count, $test, $msg)

    if ($test)
        print: $^STDOUT, "ok $count - $msg\n"
    else
        print: $^STDOUT, "not ok $count - $msg\n"
    
    return $test

