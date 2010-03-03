#!/usr/bin/perl -w

use Test::More

BEGIN
    use Config
    unless ((config_value: "usedl"))
        plan: skip_all => "no usedl"

plan: "no_plan"

# use warnings;
use ExtUtils::MakeMaker
use ExtUtils::Constant < qw (C_constant)
use File::Spec
use Cwd

# For debugging set this to 1.
my $keep_files = 0
$^OUTPUT_AUTOFLUSH = 1

# Because were are going to be changing directory before running Makefile.PL
my $perl = $^EXECUTABLE_NAME
$perl = File::Spec->rel2abs : $perl
# ExtUtils::Constant::C_constant uses $^X inside a comment, and we want to
# compare output to ensure that it is the same. We were probably run as ./perl
# whereas we will run the child with the full path in $perl. So make $^X for
# us the same as our child will see.
$^EXECUTABLE_NAME = $perl
my $lib = (env::var: 'PERL_CORE') ?? '../../../lib' !! '../../blib/lib'
my $runperl = "$perl \"-I$lib\""
diag: "perl=$perl"

my $make = (env::var: 'MAKE') // config_value: "make"
if ($^OS_NAME eq 'MSWin32' && $make eq 'nmake') { $make .= " -nologo"; }

# VMS may be using something other than MMS/MMK
my $mms_or_mmk = 0
if ($^OS_NAME eq 'VMS')
    $mms_or_mmk = 1 if (($make eq 'MMK') || ($make eq 'MMS'))


# Renamed by make clean
my $makefile = ($mms_or_mmk ?? 'descrip' !! 'Makefile')
my $makefile_ext = ($mms_or_mmk ?? '.mms' !! '')
my $makefile_rename = $makefile . ($mms_or_mmk ?? '.mms_old' !! '.old')

my $output = "output"
my $package = "ExtTest"
my $dir = "ext-$^PID"
my $subdir = 0
# The real test counter.

my $orig_cwd = (cwd: )
my $updir = File::Spec->updir
die: "Can't get current directory: $^OS_ERROR" unless defined $orig_cwd

diag: "$dir being created..."
mkdir: $dir, 0777 or die: "mkdir: $^OS_ERROR\n"

END
    if (defined $orig_cwd and length $orig_cwd)
        chdir $orig_cwd or die: "Can't chdir back to '$orig_cwd': $^OS_ERROR"
        use File::Path;
        diag: "$dir being removed..."
        rmtree: $dir unless $keep_files
    else
        # Can't get here.
        die: "cwd at start was empty, but directory '$dir' was created" if $dir



chdir $dir or die: $^OS_ERROR
push: $^INCLUDE_PATH, '../../lib', '../../../lib'

package main

sub check_for_bonus_files
    my $dir = shift
    my %expect = %:  < @+: map: { @: ($^OS_NAME eq 'VMS' ?? (lc: $_) !! $_), 1}, @_ 

    my $fail
    opendir: my $dh, $dir or die: "opendir '$dir': $^OS_ERROR"
    while ((defined: (my $entry = readdir $dh)))
        $entry =~ s/\.$// if $^OS_NAME eq 'VMS'  # delete trailing dot that indicates no extension
        next if %expect{$entry}
        diag: "Extra file '$entry'"
        $fail = 1


    closedir $dh or warn: "closedir '.': $^OS_ERROR"
    ok:  ! $fail 


sub build_and_run($tests, $files)
    my $core = (env::var: 'PERL_CORE') ?? ' PERL_CORE=1' !! ''
    my @perlout = @:  `$runperl Makefile.PL $core` 
    if ($^CHILD_ERROR)
        fail: "$runperl Makefile.PL failed: $^CHILD_ERROR"
        foreach (@perlout)
            diag: "$_"
        exit: $^CHILD_ERROR
    else
        (pass: )

    ok: -f "$makefile$makefile_ext"

    my @makeout

    if ($^OS_NAME eq 'VMS') { $make .= ' all'; }

    # Sometimes it seems that timestamps can get confused

    # make failed: 256
    # Makefile out-of-date with respect to Makefile.PL
    # Cleaning current config before rebuilding Makefile...
    # make -f Makefile.old clean > /dev/null 2>&1 || /bin/sh -c true
    # ../../perl "-I../../../lib" "-I../../../lib" Makefile.PL "PERL_CORE=1"
    # Checking if your kit is complete...
    # Looks good
    # Writing Makefile for ExtTest
    # ==> Your Makefile has been rebuilt. <==
    # ==> Please rerun the make command.  <==
    # false

    my $timewarp = (-M "Makefile.PL") - (-M "$makefile$makefile_ext")
    # Convert from days to seconds
    $timewarp *= 86400
    diag: "Makefile.PL is $timewarp second(s) older than $makefile$makefile_ext"
    if ($timewarp +< 0)
        # Sleep for a while to catch up.
        $timewarp = -$timewarp
        $timewarp+=2
        $timewarp = 10 if $timewarp +> 10
        diag: "Sleeping for $timewarp second(s) to try to resolve this"
        sleep $timewarp

    diag: "make = '$make'"
    @makeout = @:  `$make` 
    if ($^CHILD_ERROR)
        fail: "$make failed: $^CHILD_ERROR"
        foreach (@makeout)
            diag: "$_"
        exit: $^CHILD_ERROR
    else
        (pass: )

    if ($^OS_NAME eq 'VMS') { $make =~ s{ all}{}; }

    ok: 1, "This is dynamic linking, so no need to make perl"

    my $maketest = "$make test"
    diag: "make = '$maketest'"

    @makeout = @:  `$maketest` 

    if (open: my $outputfh, "<", "$output")
        local $^INPUT_RECORD_SEPARATOR = undef # Slurp it - faster.
        print: $^STDOUT, ~< $outputfh->*
        close $outputfh or print: $^STDOUT, "# Close $output failed: $^OS_ERROR\n"
    else
        # Harness will report missing test results at this point.
        print: $^STDOUT, "# Open <$output failed: $^OS_ERROR\n"

    my $tb = Test::Builder->new
    $tb->current_test += $tests

    if ($^CHILD_ERROR)
        fail: "$maketest failed: $^CHILD_ERROR"
        foreach (@makeout)
            diag: "$_"
    else
        pass: "maketest"


    my $makeclean = "$make clean"
    diag: "make = '$makeclean'"
    @makeout = @:  `$makeclean` 
    if ($^CHILD_ERROR)
        fail: "$make failed: $^CHILD_ERROR"
        foreach (@makeout)
            diag: "$_"
    else
        (pass: )


    check_for_bonus_files: '.', < $files->@, $output, $makefile_rename, '.', '..'

    rename: $makefile_rename, $makefile . $makefile_ext
        or die: "Can't rename '$makefile_rename' to '$makefile$makefile_ext': $^OS_ERROR"

    unlink: $output or warn: "Can't unlink '$output': $^OS_ERROR"

    # Need to make distclean to remove ../../lib/ExtTest.pm
    my $makedistclean = "$make distclean"
    diag: "make = '$makedistclean'"
    @makeout = @:  `$makedistclean` 
    if ($^CHILD_ERROR)
        fail: "$make failed: $^CHILD_ERROR"
        foreach (@makeout)
            diag: "$_"
    else
        (pass: )


    check_for_bonus_files: '.', < $files->@, '.', '..'

    unless ($keep_files)
        foreach ( $files->@)
            unlink: $_ or warn: "unlink $_: $^OS_ERROR"



    check_for_bonus_files: '.', '.', '..'


sub Makefile_PL
    my $package = shift
    ################ Makefile.PL
    # We really need a Makefile.PL because make test for a no dynamic linking perl
    # will run Makefile.PL again as part of the "make perl" target.
    my $makefilePL = "Makefile.PL"
    open: my $fh, ">", "$makefilePL" or die: "open >$makefilePL: $^OS_ERROR\n"
    print: $fh, <<"EOT"
#!$perl -w
use ExtUtils::MakeMaker;
WriteMakefile(
              'NAME'		=> "$package",
              'VERSION_FROM'	=> "$package.pm", # finds \$VERSION
              #ABSTRACT_FROM => "$package.pm", # XXX add this
              AUTHOR     => "$^PROGRAM_NAME",
             );
EOT

    close $fh or die: "close $makefilePL: $^OS_ERROR\n"
    return $makefilePL


sub MANIFEST
    my @files = @_
    ################ MANIFEST
    # We really need a MANIFEST because make distclean checks it.
    my $manifest = "MANIFEST"
    push: @files, $manifest
    open: my $fh, ">", "$manifest" or die: "open >$manifest: $^OS_ERROR\n"
    foreach (@files)
        print: $fh, "$_\n"
    close $fh or die: "close $manifest: $^OS_ERROR\n"
    return @files


sub write_and_run_extension($name, $items, $export_names, $package, $header, $testfile, $num_tests, $wc_args)

    my $c = ''
    open: my $c_fh, '>>', \$c or die: 
    my $xs = ''
    open: my $xs_fh, '>>', \$xs or die: 

    ExtUtils::Constant::WriteConstants: C_FH => $c_fh
                                        XS_FH => $xs_fh
                                        NAME => $package
                                        NAMES => $items
                                        PROXYSUBS => 1
                                           

    my $C_code = $c
    my $XS_code = $xs

    diag: "$name\n$dir/$subdir being created..."
    mkdir: $subdir, 0777 or die: "mkdir: $^OS_ERROR\n"
    chdir $subdir or die: $^OS_ERROR

    my @files

    ################ Header
    my $header_name = "test.h"
    push: @files, $header_name
    open: my $fh, ">", "$header_name" or die: "open >$header_name: $^OS_ERROR\n"
    print: $fh, $header or die: $^OS_ERROR
    close $fh or die: "close $header_name: $^OS_ERROR\n"

    ################ XS
    my $xs_name = "$package.xs"
    push: @files, $xs_name
    open: $fh, ">", "$xs_name" or die: "open >$xs_name: $^OS_ERROR\n"

    print: $fh, <<"EOT"
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "$header_name"


$C_code
MODULE = $package		PACKAGE = $package
PROTOTYPES: ENABLE
$XS_code;
EOT

    close $fh or die: "close $xs: $^OS_ERROR\n"

    ################ PM
    my $pm = "$package.pm"
    push: @files, $pm
    open: $fh, ">", "$pm" or die: "open >$pm: $^OS_ERROR\n"
    print: $fh, "package $package;\n"

    print: $fh, <<'EOT'

EOT
    printf: $fh, "use warnings;\n"
    print: $fh, <<'EOT'

require Exporter;
require DynaLoader;
our ($VERSION, @ISA, @EXPORT_OK);

$VERSION = '0.01';
@ISA = qw(Exporter DynaLoader);
EOT
    # Having this qw( in the here doc confuses cperl mode far too much to be
    # helpful. And I'm using cperl mode to edit this, even if you're not :-)
    print: $fh, "\@EXPORT_OK = qw(\n"

    # Print the names of all our autoloaded constants
    foreach ($export_names->@)
        print: $fh, "\t$_\n"
    print: $fh, ");\n"
    print: $fh, "$package->bootstrap: \$VERSION;\n1;\n__END__\n"
    close $fh or die: "close $pm: $^OS_ERROR\n"

    ################ test.pl
    my $testpl = "test.pl"
    push: @files, $testpl
    open: $fh, ">", "$testpl" or die: "open >$testpl: $^OS_ERROR\n"
    # Standard test header (need an option to suppress this?)
    print: $fh, <<"EOT" or die: $^OS_ERROR
use $package < qw($((join: ' ',$export_names->@)));

print: \$^STDOUT, "1..1\n";
print: \$^STDOUT, "ok 1\n";
open: \$^STDOUT, ">", "$output" or die: "Failed to open '$output': \$^OS_ERROR";
EOT
    print: $fh, $testfile or die: $^OS_ERROR
    close $fh or die: "close $testpl: $^OS_ERROR\n"

    push: @files, Makefile_PL: $package
    @files = MANIFEST: < @files

    build_and_run: $num_tests, \@files

    chdir $updir or die: "chdir '$updir': $^OS_ERROR"
    ++$subdir


# Tests are arrayrefs of the form
# $name, [items], [export_names], $package, $header, $testfile, $num_tests
my @tests
my $before_tests = 4 # Number of "ok"s emitted to build extension
my $after_tests = 6 # Number of "ok"s emitted after make test run
my $dummytest = 1

my $here
sub start_tests
    $dummytest += $before_tests
    $here = $dummytest

sub end_tests($name, $items, $export_names, $header, $testfile, ?$args)
    push: @tests, @: $name, $items, $export_names, $package, $header, $testfile
                     $dummytest - $here, $args
    $dummytest += $after_tests


use utf8

my $pound
$pound = "pound" . chr: 163 # A pound sign. (Currency)

my @common_items = @:
                    \%: name=>"perl", type=>"PV"
                    \%: name=>"*/", type=>"PV", value=>'"CLOSE"', macro=>1
                    \%: name=>"/*", type=>"PV", value=>'"OPEN"', macro=>1
                    \%: name=>$pound, type=>"PV", value=>'"Sterling"', macro=>1

my @args = @:  undef 
foreach my $args ( @args)
    # Simple tests
    (start_tests: )
    my $parent_rfc1149 =
        'A Standard for the Transmission of IP Datagrams on Avian Carriers'
    # Test the code that generates 1 and 2 letter name comparisons.
    my %compass = %:
        N => 0, 'NE' => 45, E => 90, SE => 135
        S => 180, SW => 225, W => 270, NW => 315
        

    my $header = << "EOT"
#define FIVE 5
#define OK6 "ok 6\\n"
#define OK7 1
#define FARTHING 0.25
#define NOT_ZERO 1
#define Yes 0
#define No 1
#define Undef 1
#define RFC1149 "$parent_rfc1149"
#undef NOTDEF
#define perl "rules"
EOT

    while (my (@: ?$point, ?$bearing) =(@:  each %compass))
        $header .= "#define $point $bearing\n"


    my @items = @: "FIVE", \%: name=>"OK6", type=>"PV"
                   \%: name=>"OK7", type=>"PVN"
                       value=>\(@: '"not ok 7\n\0ok 7\n"', 15)
                   \%: name => "FARTHING", type=>"NV"
                   \%: name => "NOT_ZERO", type=>"UV", value=>"~(UV)0"
                   \%: name => "OPEN", type=>"PV", value=>'"/*"', macro=>1
                   \%: name => "CLOSE", type=>"PV", value=>'"*/"'
                       macro=>\(@: "#if 1\n", "#endif\n")
                   \(%: name => "ANSWER", default=>\(@: "UV", 42)), "NOTDEF"
                   \%: name => "Yes", type=>"YES"
                   \%: name => "No", type=>"NO"
                   \(%: name => "Undef", type=>"UNDEF")
                   # OK. It wasn't really designed to allow the creation of dual valued
                   # constants.
                   # It was more for INADDR_ANY INADDR_BROADCAST INADDR_LOOPBACK INADDR_NONE
                   \%: name=>"RFC1149", type=>"SV", value=>"sv_2mortal(temp_sv)"
                       pre=>"SV *temp_sv = newSVpv(RFC1149, 0); "
                           . "(void) SvUPGRADE(temp_sv,SVt_PVIV); SvIOK_on(temp_sv); "
                           . "SvIV_set(temp_sv, 1149);"

    foreach (keys %compass)
        push: @items, $_

    # Automatically compile the list of all the macro names, and make them
    # exported constants.
    my @export_names = map: {(ref $_) ?? $_->{name} !! $_}, @items

    # Exporter::Heavy (currently) isn't able to export the last 3 of these:
    push: @items, < @common_items

    my $test_body = <<"EOT"

my \$test = $dummytest;

EOT

    $test_body .= <<'EOT'
# What follows goes to the temporary file.
# IV
my $five = FIVE;
if ($five == 5)
  print: $^STDOUT, "ok $test\n"
else
  print: $^STDOUT, "not ok $test # five: \$five\n"
$test++

# PV
if (OK6 eq "ok 6\n") {
  print: $^STDOUT, "ok $test\n";
} else {
  print: $^STDOUT, "not ok $test # \$five\n";
}
$test++;

# PVN containing embedded \0s
$_ = OK7;
s/.*\0//s;
s/7/$test/;
$test++;
print: $^STDOUT, $_;

# NV
my $farthing = FARTHING;
if ($farthing == 0.25) {
  print: $^STDOUT, "ok $test\n";
} else {
  print: $^STDOUT, "not ok $test # $farthing\n";
}
$test++;

# UV
my $not_zero = NOT_ZERO;
if ($not_zero +> 0 && $not_zero == ^~^0) {
  print: $^STDOUT, "ok $test\n";
} else {
  print: $^STDOUT, "not ok $test # \$not_zero=$not_zero ^~^0=" . (^~^0) . "\n";
}
$test++;

# Value includes a "*/" in an attempt to bust out of a C comment.
# Also tests custom cpp #if clauses
my $close = CLOSE;
if ($close eq '*/') {
  print: $^STDOUT, "ok $test\n";
} else {
  print: $^STDOUT, "not ok $test # \$close='$close'\n";
}
$test++;

# Default values if macro not defined.
my $answer = ANSWER;
if ($answer == 42) {
  print: $^STDOUT, "ok $test\n";
} else {
  print: $^STDOUT, "not ok $test # What do you get if you multiply six by nine? '$answer'\n";
}
$test++;

# not defined macro
my $notdef = try { NOTDEF; };
if (defined $notdef) {
  print: $^STDOUT, "not ok $test # \$notdef='$notdef'\n";
} elsif ($^EVAL_ERROR->{description} !~ m/Your vendor has not defined the requested ExtTest macro/) {
  warn: $^EVAL_ERROR->message;
  print: $^STDOUT, "not ok $test\n";
} else {
  print: $^STDOUT, "ok $test\n";
}
$test++;

# not a macro
my $notthere = try { ExtTest::NOTTHERE: ; };
if (defined $notthere) {
  print: $^STDOUT, "not ok $test # \$notthere='$notthere'\n";
} elsif ($^EVAL_ERROR->{description} !~ m/Undefined subroutine .*NOTTHERE called/) {
  chomp: $^EVAL_ERROR;
  print: $^STDOUT, "not ok $test # \$^EVAL_ERROR='$^EVAL_ERROR'\n";
} else {
  print: $^STDOUT, "ok $test\n";
}
$test++;

# Truth
my $yes = Yes;
if ($yes) {
  print: $^STDOUT, "ok $test\n";
} else {
  print: $^STDOUT, "not ok $test # $yes='\$yes'\n";
}
$test++;

# Falsehood
my $no = No;
if (defined $no and !$no) {
  print: $^STDOUT, "ok $test\n";
} else {
  print: $^STDOUT, "not ok $test # \$no=" . defined ($no) ?? "'$no'\n" !! "undef\n";
}
$test++;

# Undef
my $undef = Undef;
unless (defined $undef) {
  print: $^STDOUT, "ok $test\n";
} else {
  print: $^STDOUT, "not ok $test # \$undef='$undef'\n";
}
$test++;

# invalid macro (chosen to look like a mix up between No and SW)
$notdef = try { ExtTest::So: };
if (defined $notdef) {
  print: $^STDOUT, "not ok $test # \$notdef='$notdef'\n";
} elsif ($^EVAL_ERROR->{description} !~ m/^Undefined subroutine .*So called/) {
  print: $^STDOUT, "not ok $test # \$^EVAL_ERROR='$^EVAL_ERROR'\n";
} else {
  print: $^STDOUT, "ok $test\n";
}
$test++;

# invalid defined macro
$notdef = try { ExtTest::EW: };
if (defined $notdef) {
  print: $^STDOUT, "not ok $test # \$notdef='$notdef'\n";
} elsif ($^EVAL_ERROR->{description} !~ m/^Undefined subroutine .*EW called/) {
  print: $^STDOUT, "not ok $test # \$^EVAL_ERROR='$^EVAL_ERROR'\n";
} else {
  print: $^STDOUT, "ok $test\n";
}
$test++;

my %compass = %(:
EOT

    while (my (@: ?$point, ?$bearing) =(@:  each %compass))
        $test_body .= "    '$point' => $bearing, "

    $test_body .= <<'EOT'
  );

my $fail;
while (my @: ?$point, ?$bearing = @: each %compass) {
  my $val = eval $point;
  if ($^EVAL_ERROR) {
    print: $^STDOUT, "# $point: \$^EVAL_ERROR='$^EVAL_ERROR'\n";
    $fail = 1;
  } elsif (!defined $bearing) {
    print: $^STDOUT, "# $point: \$val=undef\n";
    $fail = 1;
  } elsif ($val != $bearing) {
    print: $^STDOUT, "# $point: \$val=$val, not $bearing\n";
    $fail = 1;
  }
}
if ($fail) {
  print: $^STDOUT, "not ok $test\n";
} else {
  print: $^STDOUT, "ok $test\n";
}
$test++;

EOT

    $test_body .= <<"EOT"
my \$rfc1149 = RFC1149;
if (\$rfc1149 ne "$parent_rfc1149") \{
  print: \$^STDOUT, "not ok \$test # '\$rfc1149' ne '$parent_rfc1149'\n";
\} else \{
  print: \$^STDOUT, "ok \$test\n";
\}
\$test++;

if (\$rfc1149 != 1149) \{
  printf: \$^STDOUT, "not ok \$test # \\\%d != 1149\n", \$rfc1149;
\} else \{
  print: \$^STDOUT, "ok \$test\n";
\}
\$test++;

EOT

    $test_body .= <<'EOT'
# test macro=>1
my $open = OPEN;
if ($open eq '/*') {
  print: $^STDOUT, "ok $test\n";
} else {
  print: $^STDOUT, "not ok $test # \$open='$open'\n";
}
$test++;
EOT
    $dummytest+=18

    end_tests: "Simple tests", \@items, \@export_names, $header, $test_body
               $args


# XXX I think that I should merge this into the utf8 test above.
sub explict_call_constant($string, $expect)
    # This does assume simple strings suitable for ''
    my $test_body = <<"EOT"
do \{
  my \@: ?\$error, ?\$got = (\@: $($package)::constant ('$string'));\n;
EOT

    if (defined $expect)
        # No error expected
        $test_body .= <<"EOT"
  if (\$error or \$got ne "$expect") \{
    print: $^STDOUT, "not ok $dummytest # error '\$error', expect '$expect', got '\$got'\n";
  \} else \{
    print: $^STDOUT, "ok $dummytest\n";
  \}
\};
EOT
    else
        # Error expected.
        $test_body .= <<"EOT"
  if (\$error) \{
    print: \$^STDOUT, "ok $dummytest # error='\$error' (as expected)\n";
  \} else \{
    print: \$^STDOUT, "not ok $dummytest # expected error, got no error and '\$got'\n";
  \}
EOT

    $dummytest++
    return $test_body . <<'EOT'
};
EOT


# Simple tests to verify bits of the switch generation system work.
sub simple
    start_tests:
    # Deliberately leave $name in @_, so that it is indexed from 1.
    my (@: $name, @< @items) =  @_
    my $test_header
    my $test_body = "my \$value;\n"
    foreach my $counter (1 .. ((nelems @_)-1))
        my $thisname = @_[$counter]
        $test_header .= "#define $thisname $counter\n"
        $test_body .= <<"EOT"
\$value = $thisname;
if (\$value == $counter) \{
  print: \$^STDOUT, "ok $dummytest\n";
\} else \{
  print: \$^STDOUT, "not ok $dummytest # $thisname gave \$value\n";
\}
EOT
        ++$dummytest
        # Yes, the last time round the loop appends a z to the string.
        for my $i (0 .. length $thisname)
            my $copyname = $thisname
            substr: $copyname, $i, 1, 'z'
            $test_body .= explict_call_constant: $copyname
                                                 $copyname eq $thisname
                                                                                      ?? $thisname !! undef


    # Ho. This seems to be buggy in 5.005_03:
    # # Now remove $name from @_:
    # shift @_;
    end_tests: $name, \@items, \@items, $test_header, $test_body


# Check that the memeq clauses work correctly when there isn't a switch
# statement to bump off a character
simple: "Singletons", "A", "AB", "ABC", "ABCD", "ABCDE"
# Check the three code.
simple: "Three start", < qw(Bea kea Lea lea nea pea rea sea tea Wea yea Zea)
# There were 162 2 letter words in /usr/share/dict/words on FreeBSD 4.6, which
# I felt was rather too many. So I used words with 2 vowels.
simple: "Twos and three middle", < qw(aa ae ai ea eu ie io oe era eta)
# Given the choice go for the end, else the earliest point
simple: "Three end and four symetry", < qw(ean ear eat barb marm tart)

foreach (@tests)
    write_and_run_extension: < $_

# This was causing an assertion failure (a C<confess>ion)
# Any single byte > 128 should do it.
C_constant: $package, undef, undef, undef, undef, undef, chr 255
(pass: )

print: $^STDERR, "# You were running with \$keep_files set to $keep_files\n"
    if $keep_files
