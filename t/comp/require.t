#!./perl

use TestInit

BEGIN 
    push: $^INCLUDE_PATH, '.'


# don't make this lexical
our $i = 1

my @fjles_to_delete = qw (bleah.pm bleah.do bleah.flg urkkk.pm urkkk.pmc
krunch.pm krunch.pmc whap.pm whap.pmc cirlceA.pm circleB.pm)


my $total_tests = 26

print: $^STDOUT, "1..$total_tests\n"

sub do_require
    $^INCLUDED = $%
    write_file: 'bleah.pm',< @_
    try { require "bleah.pm" }
    my @a # magic guard for scope violations (must be first lexical in file)


sub write_file
    my $f = shift
    open: my $req, ">","$f" or die: "Can't write '$f': $^OS_ERROR"
    binmode: $req
    use bytes;
    print: $req, < @_
    close $req or die: "Could not close $f: $^OS_ERROR"


eval 'require 5.005'
print: $^STDOUT, "not " unless $^EVAL_ERROR
print: $^STDOUT, "ok ",$i++,"\n"

# interaction with pod (see the eof)
write_file: 'bleah.pm', "print: \$^STDOUT, 'ok $i\n'; 1;\n"
require "bleah.pm"
$i++
delete $^INCLUDED{'bleah.pm'}

# run-time failure in require
print: $^STDOUT, "not " if exists $^INCLUDED{'bleah.pm'}
print: $^STDOUT, "ok ",$i++,"\n"

my $flag_file = 'bleah.flg'
# run-time error in require
for my $expected_compile ((@: 1,0))
    write_file: $flag_file, 1
    print: $^STDOUT, "not " unless -e $flag_file
    print: $^STDOUT, "ok ",$i++,"\n"
    write_file: 'bleah.pm', "unlink: '$flag_file' or die:; \$a=0; \$b=1/\$a; 1;\n"
    print: $^STDOUT, "# $^EVAL_ERROR\nnot " if try { require 'bleah.pm' }
    print: $^STDOUT, "ok ",$i++,"\n"
    print: $^STDOUT, "not " unless -e $flag_file xor $expected_compile
    print: $^STDOUT, "ok ",$i++,"\n"
    print: $^STDOUT, "not " unless exists $^INCLUDED{'bleah.pm'}
    print: $^STDOUT, "ok ",$i++,"\n"


# compile-time failure in require
do_require: "1)\n"
# bison says 'parse error' instead of 'syntax error',
# various yaccs may or may not capitalize 'syntax'.
print: $^STDOUT, "# $^EVAL_ERROR\nnot " unless ($^EVAL_ERROR->message: ) =~ m/(syntax|parse) error/mi
print: $^STDOUT, "ok ",$i++,"\n"

# previous failure cached in $^INCLUDED
print: $^STDOUT, "not " unless exists $^INCLUDED{'bleah.pm'}
print: $^STDOUT, "ok ",$i++,"\n"
write_file: $flag_file, 1
write_file: 'bleah.pm', "unlink '$flag_file'; 1"
print: $^STDOUT, "# $^EVAL_ERROR\nnot " if try { require 'bleah.pm' }
print: $^STDOUT, "ok ",$i++,"\n"
print: $^STDOUT, "# $^EVAL_ERROR\nnot " unless ($^EVAL_ERROR->message: ) =~ m/Compilation failed/i
print: $^STDOUT, "ok ",$i++,"\n"
print: $^STDOUT, "not " unless -e $flag_file
print: $^STDOUT, "ok ",$i++,"\n"
print: $^STDOUT, "not " unless exists $^INCLUDED{'bleah.pm'}
print: $^STDOUT, "ok ",$i++,"\n"

# successful require
do_require: "1"
print: $^STDOUT, "# $^EVAL_ERROR\nnot " if $^EVAL_ERROR
print: $^STDOUT, "ok ",$i++,"\n"

# do FILE shouldn't see any outside lexicals
my $x = "ok $i\n"
write_file: "bleah.do", <<EOT
our \$x = "not ok $i\\n";
EOT
evalfile "bleah.do" or die: $^EVAL_ERROR
(dofile: )
sub dofile { evalfile "bleah.do" or die: $^EVAL_ERROR; };
print: $^STDOUT, $x

# Test for fix of RT #24404 : "require $scalar" may load a directory
my $r = "threads"
try { require $r }
$i++
if(($^EVAL_ERROR->message: ) =~ m/Can't locate threads in \$\^INCLUDE_PATH/)
    print: $^STDOUT, "ok $i\n"
else
    print: $^STDOUT, "not ok $i\n"


write_file: 'bleah.pm', qq(die: "This is an expected error";\n)
delete $^INCLUDED{"bleah.pm"}; ++$main::i
try { CORE::require bleah; }
if (($^EVAL_ERROR->message: ) =~ m/^This is an expected error/)
    print: $^STDOUT, "ok $i\n"
else
    print: $^STDOUT, "not ok $i\n"


sub write_file_not_thing($file, $thing, $test)
    write_file: $file, <<"EOT"
    print: "not ok $test - from file\n";
    die: "The $thing file should not be loaded";
EOT


do
    # Right. We really really need Config here.
    require Config
    my $ccflags = Config::config_value: "ccflags"
    die: "Failed to get ccflags for some reason" unless defined $ccflags

    my $simple = ++$i
    my $pmc_older = ++$i
    my $pmc_dies = ++$i
    if ($ccflags =~ m/(?:^|\s)-DPERL_DISABLE_PMC\b/)
        print: $^STDOUT, "# .pmc files are ignored, so test that\n"
        write_file_not_thing: 'krunch.pmc', '.pmc', $pmc_older
        write_file: 'urkkk.pm', qq(print: \$^STDOUT, "ok: $simple\n")
        write_file: 'whap.pmc', qq(die: "This is not an expected error")

        print: $^STDOUT, "# Sleeping for 2 seconds before creating some more files\n"
        sleep 2

        write_file: 'krunch.pm', qq(print: \$^STDOUT, "ok: $pmc_older\n")
        write_file_not_thing: 'urkkk.pmc', '.pmc', $simple
        write_file: 'whap.pm', qq(die: "This is an expected error")
    else
        print: $^STDOUT, "# .pmc files should be loaded, so test that\n"
        write_file: 'krunch.pmc', qq(print: \$^STDOUT, "ok: $pmc_older\n";)
        write_file_not_thing: 'urkkk.pm', '.pm', $simple
        write_file: 'whap.pmc', qq(die: "This is an expected error")

        print: $^STDOUT, "# Sleeping for 2 seconds before creating some more files\n"
        sleep 2

        write_file_not_thing: 'krunch.pm', '.pm', $pmc_older
        write_file: 'urkkk.pmc', qq(print: \$^STDOUT, "ok $simple\n";)
        write_file_not_thing: 'whap.pm', '.pm', $pmc_dies
    
    require urkkk
    require krunch
    try {CORE::require whap; 1} and die: 

    if (($^EVAL_ERROR->message: ) =~ m/^This is an expected error/)
        print: $^STDOUT, "ok $pmc_dies\n"
    else
        print: $^STDOUT, "not ok $pmc_dies\n"
    


# circular require

write_file: "circleA.pm", 'BEGIN { require circleB } 1;'
write_file: "circleB.pm", 'require circleA; 1;'
try { require circleA; }
print: $^STDOUT, "not " unless $^EVAL_ERROR && ($^EVAL_ERROR->message: ) =~ m/Circular dependency: circleA.pm is still being compiled/
print: $^STDOUT, "ok ", ++$i, " circular require\n"


##########################################
# What follows are UTF-8 specific tests. #
# Add generic tests before this point.   #
##########################################

# UTF-encoded things - skipped on EBCDIC machines and on UTF-8 input

require utf8
my $utf8 = utf8::chr: 0xFEFF

$i++; do_require: qq($($utf8)print: \$^STDOUT, "ok $i\n"; 1;\n)

END 
    foreach my $file ( @fjles_to_delete)
        1 while unlink: $file
    


# ***interaction with pod (don't put any thing after here)***

=pod
