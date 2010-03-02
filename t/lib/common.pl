# This code is used by lib/warnings.t and lib/feature.t

BEGIN 
    require './test.pl'


use Config
use File::Path
use File::Spec::Functions

use warnings
our $pragma_name

our $got_files = 0 # set to 1 to generate output files.

$^OUTPUT_AUTOFLUSH = 1

my $Is_MacOS = $^OS_NAME eq 'MacOS'
my $tmpfile = (tempfile: )

my @prgs = $@ 
my @w_files = $@ 

if ((nelems @ARGV))
    print: $^STDOUT, "ARGV = [$((join: ' ',@ARGV))]\n"
    if ($Is_MacOS)
        @w_files = map: { s#^#:lib:$pragma_name:#; $_ }, @ARGV
    else
        @w_files = map: { s#^#./lib/$pragma_name/#; $_ }, @ARGV
else
    @w_files = sort: glob: (catfile: (curdir: ), "lib", $pragma_name, "*")

my $files = 0
foreach my $file ( @w_files)

    next if $file =~ m/(~|\.orig|\.got|,v)$/
    next if $file =~ m/perlio$/ && !(('PerlIO::Layer'->find:  'perlio'))
    next if -d $file

    open: my $f, "<", "$file" or die: "Cannot open $file: $^OS_ERROR\n" 
    my $line = 0
    open: my $got_file, ">", "$file.got" or die: if $got_files
    while ( ~< $f)
        print: $got_file, $_ if $got_files
        $line++
        last if m/^__END__/ 
    
    close $got_file if $got_files

    do
        local $^INPUT_RECORD_SEPARATOR = undef
        $files++
        @prgs = @: < @prgs, $file, < split: "\n########\n", ~< $f 
    
    close $f 


undef $^INPUT_RECORD_SEPARATOR

plan: tests => ((scalar: nelems @prgs)-$files)

my $out_file
my $file
for ( @prgs)
    unless (m/\n/)
        print: $^STDOUT, "# From $_\n"
        $file = $_

        if ($got_files)
            close $out_file if $out_file
            open: $out_file, ">>", "$file.got" or die: 
        
        next
    
    my $src = $_
    my $switch = ""
    my @temps = $@ 
    my @temp_path = $@ 
    if (s/^(\s*-\w+)//)
        $switch = $1
    
    my(@: $prog,$expected) =  split: m/\nEXPECT(?:\n|$)/, $_, 2

    my %reason;
    foreach my $what (qw(skip todo))
        $prog =~ s/^#\s*\U$what\E\s*(.*)\n//m and %reason{+$what} = $1
        # If the SKIP reason starts ? then it's taken as a code snippet to
        # evaluate. This provides the flexibility to have conditional SKIPs
        if (%reason{?$what} && %reason{$what} =~ s/^\?//)
            my $temp = eval %reason{$what}
            if ($^EVAL_ERROR)
                die: "# In \U$what\E code reason:\n# %reason{$what}\n$(($^EVAL_ERROR->message: ))"
            %reason{$what} = $temp
    
    if ( $prog =~ m/--FILE--/)
        my @files = split: m/\n--FILE--\s*([^\s\n]*)\s*\n/, $prog 
        shift @files 
        die: "Internal error: test $_ didn't split into pairs, got " .
                 (scalar: nelems @files) . "[" . (join: "\%\%\%\%", @files) ."]\n"
            if (nelems @files) % 2 
        while ((nelems @files) +> 2)
            my $filename = shift @files 
            my $code = shift @files 
            push: @temps, $filename 
            if ($filename =~ m#(.*)/#)
                mkpath: $1
                push: @temp_path, $1
            
            open: my $f, ">", "$filename" or die: "Cannot open $filename: $^OS_ERROR\n" 
            print: $f ,$code 
            close $f or die: "Cannot close $filename: $^OS_ERROR\n"
        
        shift @files 
        $prog = shift @files 
    
    # fix up some paths
    if ($Is_MacOS)
        $prog =~ s|require "./abc(d)?";|require ":abc$1";|g
        $prog =~ s|"\."|":"|g
    

    my $prog_header = q[
        BEGIN {
            open: $^STDERR, ">&", $^STDOUT
              or die: "Can't dup STDOUT->STDERR: $^OS_ERROR;";
        }
    ] . "\n#line 1\n"
    my $real_prog = $prog
    $real_prog =~ s/^((?:#!.*)?)/$1$($prog_header)/
    open: my $test, ">", "$tmpfile" or die: "Cannot open >$tmpfile: $^OS_ERROR"
    print: $test, $real_prog, "\n"
    close $test or die: "Cannot close $tmpfile: $^OS_ERROR"
    my $results = runperl:  switches => \(@: $switch), stderr => 1, progfile => $tmpfile 
    my $status = $^CHILD_ERROR
    $results =~ s/\n+$//
    # allow expected output to be written as if $prog is on STDIN
    $results =~ s/$::tempfile_regexp/-/g
    $results =~ s[at \.\./lib/warnings\.pm line \d+ character \d+\.][at .../warnings.pm line xxx.]g
    if ($^OS_NAME eq 'VMS')
        # some tests will trigger VMS messages that won't be expected
        $results =~ s/\n?%[A-Z]+-[SIWEF]-[A-Z]+,.*//

        # pipes double these sometimes
        $results =~ s/\n\n/\n/g
    
    # bison says 'parse error' instead of 'syntax error',
    # various yaccs may or may not capitalize 'syntax'.
    $results =~ s/^(syntax|parse) error/syntax error/mig
    # allow all tests to run when there are leaks
    $results =~ s/Scalars leaked: \d+\n//g

    # fix up some paths
    if ($Is_MacOS)
        $results =~ s|:abc\.pm\b|abc.pm|g
        $results =~ s|:abc(d)?\b|./abc$1|g
    

    $expected =~ s/\n+$//
    my $prefix = ($results =~ s#^PREFIX(\n|$)##) 
    # any special options? (OPTIONS foo bar zap)
    my $option_regex = 0
    my $option_random = 0
    if ($expected =~ s/^OPTIONS? (.+)\n//)
        foreach my $option ((split: ' ', $1))
            if ($option eq 'regex') # allow regular expressions
                $option_regex = 1
            elsif ($option eq 'random') # all lines match, but in any order
                $option_random = 1
            else
                die: "$^PROGRAM_NAME: Unknown OPTION '$option'\n"
        
    
    die: "$^PROGRAM_NAME: can't have OPTION regex and random\n"
        if $option_regex + $option_random +> 1
    my $ok = 0
    if ($results =~ s/^SKIPPED\n//)
        print: $^STDOUT, "$results\n" 
        $ok = 1
    elsif ($option_random)
        $ok = randomMatch: $results, $expected
    elsif ($option_regex)
        $ok = $results =~ m/^$expected/
    elsif ($prefix)
        $ok = $results =~ m/^\Q$expected/
    else
        $ok = $results eq $expected

    $src =~ s/\nEXPECT(?:\n|$)(.|\n)*/\nEXPECT\n$results/
    
    print: $out_file, $src, "\n########\n" if $got_files

    local our $TODO = %reason{?'todo'}
    print_err_line:  $switch, $prog, $expected, $results, $TODO, $file  unless $ok or $TODO

    ok: $ok

    foreach ( @temps)
        unlink: $_ if $_
    foreach ( @temp_path)
        rmtree: $_ if -d $_


sub randomMatch
    my $got = shift 
    my $expected = shift

    my @got = sort: split: "\n", $got 
    my @expected = sort: split: "\n", $expected 

    return "$((join: ' ',@got))" eq "$((join: ' ',@expected))"



sub print_err_line
    my (@: $switch, $prog, $expected, $results, $todo, $file) =  @_
    my $err_line = "FILE: $file\n" .
        "PROG: $switch\n$prog\n" .
        "EXPECTED:\n$expected\n" .
        "GOT:\n$results\n"
    if ($todo)
        $err_line =~ s/^/# /mg
        print: $^STDOUT, $err_line  # Harness can't filter it out from STDERR.
    else
        print: $^STDERR, $err_line
    

    return 1


1
