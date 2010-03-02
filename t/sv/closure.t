#!./perl
#                              -*- Mode: Perl -*-
# closure.t:
#   Original written by Ulrich Pfeifer on 2 Jan 1997.
#   Greatly extended by Tom Phoenix <rootbeer@teleport.com> on 28 Jan 1997.
#
#   Run with -debug for debugging output.

use Config
require './test.pl' # for runperl()

print: $^STDOUT, "1..61\n"

my $test = 1
sub test($sub, @< @args)
    my $ok = $sub->& <:  < @args 
    print: $^STDOUT, $ok ?? "ok $test\n" !! "not ok $test\n"
    printf: $^STDOUT, "# Failed at line \%d\n", (@: caller)[2] unless $ok
    $test++


my $i = 1
sub foo { $i = shift if (nelems @_); $i }

# no closure
test: { (foo: )== 1 }
foo: 2
test: { (foo: )== 2 }

# closure: lexical outside sub
my $foo = sub (@< @_) {$i = shift if (nelems @_); $i }
my $bar = sub (@< @_) {$i = shift if (nelems @_); $i }
test: {($foo->& <: ) == 2 }
$foo->& <: 3
test: {($foo->& <: ) == 3 }
# did the lexical change?
test: { (foo: )== 3 and $i == 3}
# did the second closure notice?
test: {($bar->& <: ) == 3 }

# closure: lexical inside sub
sub bar
    my $i = shift
    sub (@< @_) { $i = shift if (nelems @_); $i }


$foo = bar: 4
$bar = bar: 5
test: {($foo->& <: ) == 4 }
$foo->& <: 6
test: {($foo->& <: ) == 6 }
test: {($bar->& <: ) == 5 }

# nested closures
sub bizz
    my $i = 7
    if ((nelems @_))
        my $i = shift
        sub (@< @_) {$i = shift if (nelems @_); $i }
    else
        my $i = $i
        sub (@< @_) {$i = shift if (nelems @_); $i }
    

$foo = (bizz: )
$bar = (bizz: )
test: {($foo->& <: ) == 7 }
$foo->& <: 8
test: {($foo->& <: ) == 8 }
test: {($bar->& <: ) == 7 }

$foo = bizz: 9
$bar = bizz: 10
test: {($foo->& <: 11)-1 ==( $bar->& <: )}

my @foo
for (qw(0 1 2 3 4))
    my $i = $_
    @foo[+$_] = sub (@< @_) {$i = shift if (nelems @_); $i }


test: {(
          @foo[0]->& <: ) == 0 and(
              @foo[1]->& <: ) == 1 and(
              @foo[2]->& <: ) == 2 and(
              @foo[3]->& <: ) == 3 and(
              @foo[4]->& <: ) == 4
          }

for (0 .. 4)
    @foo[$_]->& <: 4-$_


test: {(
          @foo[0]->& <: ) == 4 and(
              @foo[1]->& <: ) == 3 and(
              @foo[2]->& <: ) == 2 and(
              @foo[3]->& <: ) == 1 and(
              @foo[4]->& <: ) == 0
          }

sub barf
    my @foo
    for (qw(0 1 2 3 4))
        my $i = $_
        @foo[+$_] = sub (@< @_) {$i = shift if (nelems @_); $i }
    
    @foo


@foo = (barf: )
test: {(
          @foo[0]->& <: ) == 0 and(
              @foo[1]->& <: ) == 1 and(
              @foo[2]->& <: ) == 2 and(
              @foo[3]->& <: ) == 3 and(
              @foo[4]->& <: ) == 4
          }

for (0 .. 4)
    @foo[$_]->& <: 4-$_


test: {(
          @foo[0]->& <: ) == 4 and(
              @foo[1]->& <: ) == 3 and(
              @foo[2]->& <: ) == 2 and(
              @foo[3]->& <: ) == 1 and(
              @foo[4]->& <: ) == 0
          }

# test if closures get created in optimized for loops

my %foo
for my $n (qw[A B C D E])
    %foo{+$n} = sub (@< @_) { $n eq @_[0] }


test: {
          %foo{?A}->& <: 'A' and
              %foo{?B}->& <: 'B' and
              %foo{?C}->& <: 'C' and
              %foo{?D}->& <: 'D' and
              %foo{?E}->& <: 'E'
          }

for my $n (0..4)
    @foo[$n] = sub (@< @_) { $n == @_[0] }


test: {
          @foo[0]->& <: 0 and
              @foo[1]->& <: 1 and
              @foo[2]->& <: 2 and
              @foo[3]->& <: 3 and
              @foo[4]->& <: 4
          }

for my $n (0..4)
    @foo[$n] = sub (@< @_)
        # no intervening reference to $n here
        sub (@< @_) { $n == @_[0] }
    


test: {(
          @foo[0]->& <: )->& <: 0 and(
              @foo[1]->& <: )->& <: 1 and(
              @foo[2]->& <: )->& <: 2 and(
              @foo[3]->& <: )->& <: 3 and(
              @foo[4]->& <: )->& <: 4
          }

do
    my $w
    $w = sub (@< @_)
        my (@: $i) =  @_
        test: { $i == 10 }
        sub (@< @_) { $w }
    
    $w->& <: 10


# Additional tests by Tom Phoenix <rootbeer@teleport.com>.

do

    my($debugging, %expected)
    my($nc_attempt, $call_outer, $call_inner, $undef_outer)
    my($code, $expected, $errors, $output)
    my(@inners, $sub_test, $pid)
    $debugging = 1 if defined: @ARGV[?0] and @ARGV[0] eq '-debug'

    # The expected values for these tests
    %expected = %:
        'global_scalar'	=> 1001
        'global_array'	=> 2101
        'global_hash'	=> 3004
        'fs_scalar'	=> 4001
        'fs_array'	=> 5101
        'fs_hash'	=> 6004
        'sub_scalar'	=> 7001
        'sub_array'	=> 8101
        'sub_hash'	=> 9004

    # Our innermost sub is either named or anonymous
    for my $inner_type (qw!anon!)
        # And it may be declared at filescope, within a named
        # sub, or within an anon sub
        for my $where_declared (qw!filescope in_named in_anon!)

            # And that, in turn, may be within a foreach loop,
            # a naked block, or another named sub
            for my $within (qw!foreach!)

                # Here are a number of variables which show what's
                # going on, in a way.
                $nc_attempt = 0+ # Named closure attempted
                    ( ($inner_type eq 'named') ||
                      ($within eq 'other_sub') ) 
                $call_inner = 0+ # Need to call &inner
                    ( ($inner_type eq 'anon') &&
                      ($within eq 'other_sub') ) 
                $call_outer = 0+ # Need to call &outer or &$outer
                    ( ($inner_type eq 'anon') &&
                      ($within ne 'other_sub') ) 
                $undef_outer = 0+ # $outer is created but unused
                    ( ($where_declared eq 'in_anon') &&
                      (not $call_outer) ) 

                $code = "# This is a test script built by t/op/closure.t\n\n"

                print: $^STDOUT, <<"DEBUG_INFO" if $debugging
# inner_type:     $inner_type 
# where_declared: $where_declared 
# within:         $within
# nc_attempt:     $nc_attempt
# call_inner:     $call_inner
# call_outer:     $call_outer
# undef_outer:    $undef_outer
DEBUG_INFO

                $code .= <<"END_MARK_ONE"

BEGIN \{ \$^WARN_HOOK = sub \{ 
    my \$msg = \@_[0]->message;
END_MARK_ONE

                $code .=  <<"END_MARK_TWO" if $nc_attempt
    return if index(\$msg, 'will not stay shared') != -1;
    return if index(\$msg, 'is not available') != -1;
END_MARK_TWO

                $code .= <<"END_MARK_THREE" # Backwhack a lot!
    print: \$^STDOUT, "not ok: got unexpected warning \$msg\\n";
\} \}

do \{
    my \$test = $test;
    sub test (\$sub) \{
      my \$ok = \$sub->();
      print: \$^STDOUT, \$ok ?? "ok \$test\n" !! "not ok \$test\n";
      printf: \$^STDOUT, "# Failed at line \\\%d\n", (\@: caller)[2] unless \$ok;
      \$test++;
    \}
\};

# some of the variables which the closure will access
our \$global_scalar = 1000;
our \@global_array = \@: 2000, 2100, 2200, 2300;
our \%global_hash = \%: < 3000..3009;

my \$fs_scalar = 4000;
my \@fs_array = \@: 5000, 5100, 5200, 5300;
my \%fs_hash = \%: < 6000..6009;

END_MARK_THREE

                if ($where_declared eq 'filescope') {
                # Nothing here
                }elsif ($where_declared eq 'in_named')
                    $code .= <<'END'
sub outer {
  my $sub_scalar = 7000;
  my @sub_array = @: 8000, 8100, 8200, 8300;
  my %sub_hash = %:<9000..9009;
END
                # }
                elsif ($where_declared eq 'in_anon')
                    $code .= <<'END'
our $outer = sub {
  my $sub_scalar = 7000;
  my @sub_array = @: 8000, 8100, 8200, 8300;
  my %sub_hash = %:<9000..9009;
END
                # }
                else
                    die: "What was $where_declared?"
                

                if ($within eq 'foreach')
                    $code .= '
      my @list = @: 10000, 10010;
      foreach my $foreach (@list) {
    ' # }
                elsif ($within eq 'other_sub')
                    $code .= "  sub inner_sub \{\n" # }
                else
                    die: "What was $within?"
                

                $sub_test = $test
                @inners = @:  < qw!global_scalar global_array global_hash! , <
                                  qw!fs_scalar fs_array fs_hash! 
                if ($where_declared ne 'filescope')
                    push: @inners, < qw!sub_scalar sub_array sub_hash!
                
                for my $inner_sub_test ( @inners)

                    if ($inner_type eq 'named')
                        $code .= "    sub named_$sub_test "
                    elsif ($inner_type eq 'anon')
                        $code .= "    our \$anon_$sub_test = sub "
                    else
                        die: "What was $inner_type?"
                    

                    # Now to write the body of the test sub
                    if ($inner_sub_test eq 'global_scalar')
                        $code .= '{ ++$global_scalar }'
                    elsif ($inner_sub_test eq 'fs_scalar')
                        $code .= '{ ++$fs_scalar }'
                    elsif ($inner_sub_test eq 'sub_scalar')
                        $code .= '{ ++$sub_scalar }'
                    elsif ($inner_sub_test eq 'global_array')
                        $code .= '{ ++@global_array[1] }'
                    elsif ($inner_sub_test eq 'fs_array')
                        $code .= '{ ++@fs_array[1] }'
                    elsif ($inner_sub_test eq 'sub_array')
                        $code .= '{ ++@sub_array[1] }'
                    elsif ($inner_sub_test eq 'global_hash')
                        $code .= '{ ++%global_hash{3002} }'
                    elsif ($inner_sub_test eq 'fs_hash')
                        $code .= '{ ++%fs_hash{6002} }'
                    elsif ($inner_sub_test eq 'sub_hash')
                        $code .= '{ ++%sub_hash{9002} }'
                    else
                        die: "What was $inner_sub_test?"
                    

                    # Close up
                    if ($inner_type eq 'anon')
                        $code .= ';'
                    
                    $code .= "\n"
                    $sub_test++ # sub name sequence number

                               # End of foreach $inner_sub_test

                # Close up $within block		# {
                $code .= "  \}\n\n"

                # Close up $where_declared block
                if ($where_declared eq 'in_named') # {
                    $code .= "\}\n\n"
                elsif ($where_declared eq 'in_anon') # {
                    $code .= "\};\n\n"

                # We may need to do something with the sub we just made...
                $code .= "undef \$outer;\n" if $undef_outer
                $code .= "&inner_sub(< @_);\n" if $call_inner
                if ($call_outer)
                    if ($where_declared eq 'in_named')
                        $code .= "outer(< \@_);\n\n"
                    elsif ($where_declared eq 'in_anon')
                        $code .= "\$outer->(< \@_);\n\n"

                # Now, we can actually prep to run the tests.
                for my $inner_sub_test ( @inners)
                    $expected = %expected{?$inner_sub_test} or
                        die: "expected $inner_sub_test missing"

                    # Named closures won't access the expected vars
                    if ( $nc_attempt and
                        (substr: $inner_sub_test, 0, 4) eq "sub_" )
                        $expected = 1
                    

                    # If you make a sub within a foreach loop,
                    # what happens if it tries to access the
                    # foreach index variable? If it's a named
                    # sub, it gets the var from "outside" the loop,
                    # but if it's anon, it gets the value to which
                    # the index variable is aliased.
                    #
                    # Of course, if the value was set only
                    # within another sub which was never called,
                    # the value has not been set yet.
                    #
                    if ($inner_sub_test eq 'foreach')
                        if ($inner_type eq 'named')
                            if ($call_outer || ($where_declared eq 'filescope'))
                                $expected = 12001
                            else
                                $expected = 1

                    # Here's the test:
                    if ($inner_type eq 'anon')
                        $code .= "test \{ our \$anon_$test; \$anon_$test\->() == $expected \};\n"
                    else
                        $code .= "test \{ &named_$test() == $expected \};\n"
                    $test++

                if (config_value: 'd_fork' and $^OS_NAME ne 'VMS' and $^OS_NAME ne 'MSWin32' and $^OS_NAME ne 'NetWare')
                    # Fork off a new perl to run the tests.
                    # (This is so we can catch spurious warnings.)
                    $^OUTPUT_AUTOFLUSH = 1; (print: $^STDOUT, ""); $^OUTPUT_AUTOFLUSH = 0 # flush output before forking
                    pipe: my $read, my $write or die: "Can't make pipe: $^OS_ERROR"
                    pipe: my $read2, my $write2 or die: "Can't make second pipe: $^OS_ERROR"
                    die: "Can't fork: $^OS_ERROR" unless defined: ($pid = open: my $perl_fh, "|-", '-')
                    unless ($pid)
                        # Child process here. We're going to send errors back
                        # through the extra pipe.
                        close $read
                        close $read2
                        open: $^STDOUT, ">&", \$write->*  or die: "Can't redirect STDOUT: $^OS_ERROR"
                        open: $^STDERR, ">&", \$write2->* or die: "Can't redirect STDERR: $^OS_ERROR"
                        exec: (which_perl: ), '-w', '-I../lib', '-'
                            or die: "Can't exec perl: $^OS_ERROR"
                    else
                        # Parent process here.
                        close $write
                        close $write2
                        print: $perl_fh, $code
                        close $perl_fh
                        do { local $^INPUT_RECORD_SEPARATOR = undef;
                            $output = (join: '', (@:  ~< $read));
                            $errors = (join: '', (@:  ~< $read2)); }
                        close $read
                        close $read2
                    
                else
                    # No fork().  Do it the hard way.
                    my $cmdfile = "tcmd$^PID";  $cmdfile++ while -e $cmdfile
                    my $errfile = "terr$^PID";  $errfile++ while -e $errfile
                    my @tmpfiles = @: $cmdfile, $errfile
                    (open: my $cmd_fh, ">", "$cmdfile"); (print: $cmd_fh, $code); close $cmd_fh
                    my $cmd = (which_perl: )
                    $cmd .= " \"-I../lib\" -w $cmdfile 2>$errfile"
                    if ($^OS_NAME eq 'VMS' or $^OS_NAME eq 'MSWin32' or $^OS_NAME eq 'NetWare')
                        # Use pipe instead of system so we don't inherit STD* from
                        # this process, and then foul our pipe back to parent by
                        # redirecting output in the child.
                        open: my $perl_fh, "-", "$cmd" or die: "Can't open pipe: $^OS_ERROR\n"
                        do { local $^INPUT_RECORD_SEPARATOR = undef; $output = (join: '', (@:  ~< $perl_fh)) }
                        close $perl_fh
                    else
                        my $outfile = "tout$^PID";  $outfile++ while -e $outfile
                        push: @tmpfiles, $outfile
                        system: "$cmd >$outfile"
                        do { local $^INPUT_RECORD_SEPARATOR = undef; open: my $in_fh, "<", $outfile; $output = ~< $in_fh; close $in_fh }
                    
                    if ($^CHILD_ERROR)
                        printf: $^STDOUT, "not ok: exited with error code \%04X\n", $^CHILD_ERROR
                        $debugging or do { 1 while (unlink: < @tmpfiles) }
                        exit
                    
                    do { local $^INPUT_RECORD_SEPARATOR = undef; open: my $in_fh, "<", $errfile; $errors = ~< $in_fh; close $in_fh }
                    1 while unlink: < @tmpfiles
                
                print: $^STDOUT, $output
                print: $^STDERR, $errors
                if ($debugging && ($errors || $^CHILD_ERROR || ($output =~ m/not ok/)))
                    my $lnum = 0
                    for my $line ((split: '\n', $code))
                        printf: $^STDOUT, "\%3d:  \%s\n", ++$lnum, $line
                
                if ($^CHILD_ERROR)
                    printf: $^STDOUT, "not ok: exited with error code \%04X\n", $^CHILD_ERROR
                    diag: "command:\n$code"
                
                print: $^STDOUT, '#', "-" x 30, "\n" if $debugging

                               # End of foreach $within
                               # End of foreach $where_declared
                               # End of foreach $inner_type

do
    # The following dumps core with perl <= 5.8.0 (bugid 9535) ...
    our $some_var
    BEGIN { our $vanishing_pad = sub (@< @_) { eval @_[0] } }
    $some_var = 123
    test: {( our $vanishing_pad->& <:  '$some_var' ) == 123 }


our ($newvar, @a, $x)

# ... and here's another coredump variant - this time we explicitly
# delete the sub rather than using a BEGIN ...

sub deleteme { $a = sub (@< @_) { eval '$newvar' } }
(deleteme: )
*deleteme = sub {}             # delete the sub
$newvar = 123                  # realloc the SV of the freed CV
test: {( $a->& <: ) == 123 }

# ... and a further coredump variant - the fixup of the anon sub's
# CvOUTSIDE pointer when the middle eval is freed, wasn't good enough to
# survive the outer eval also being freed.

$x = 123
$a = eval q(
    eval q[
        sub { eval '$x' }
    ]
)
die: if $^EVAL_ERROR
@a = @:  ('\1\1\1\1\1\1\1') x 100  # realloc recently-freed CVs
test: {( $a->& <: ) == 123 }

# this coredumped on <= 5.8.0 because evaling the closure caused
# an SvFAKE to be added to the outer anon's pad, which was then grown.
my $outer
(sub (@< @_)
    my $x
    $x = eval 'sub { $outer }'
    ($x->& <: )
    $a = \@:  99
    ($x->& <: )
 ->& <: )
test: {1}

# [perl #17605] found that an empty block called in scalar context
# can lead to stack corruption
do
    my $x = "foooobar"
    $x =~ s/o/$('')/g
    test: { $x eq 'fbar' }


# DAPM 24-Nov-02
# SvFAKE lexicals should be visible thoughout a function.
# On <= 5.8.0, the third test failed,  eg bugid #18286

do
    my $x = 1
    sub fake
        test: {( sub (@< @_) {eval'$x'}->& <: ) == 1 }
        do { $x;	test: {( sub (@< @_) {eval'$x'}->& <: ) == 1 }, }
        test: {( sub (@< @_) {eval'$x'}->& <: ) == 1 }
    

(fake: )

# undefining a sub shouldn't alter visibility of outer lexicals

do
    $x = 1
    my $x = 2
    sub tmp { sub (@< @_) { eval '$x' } }
    my $a = (tmp: )
    undef &tmp
    test: {( $a->& <: ) == 2 }


# handy class: $x = Watch->new(\$foo,'bar')
# causes 'bar' to be appended to $foo when $x is destroyed
sub Watch::new { (bless: \(@:  @_[1], @_[2] ), @_[0]) }
sub Watch::DESTROY { @_[0]->[0]->$ .= @_[0]->[1] }


# bugid 1028:
# nested anon subs (and associated lexicals) not freed early enough

sub linger
    my $x = Watch->new: @_[0], '2'
    sub (@< @_)
        $x
        my $y
        sub (@< @_) { $y; }

do
    my $watch = '1'
    linger: \$watch
    test: { $watch eq '12' }


# bugid 10085
# obj not freed early enough

sub linger2
    my $obj = Watch->new: @_[0], '2'
    sub (@< @_) { sub (@< @_) { $obj } }

do
    my $watch = '1'
    linger2: \$watch
    test: { $watch eq '12' }


# bugid 16302 - named subs didn't capture lexicals on behalf of inner subs

do
    my $x = 1
    sub f16302()
        (sub (@< @_)
            test: { defined $x and $x == 1 }
         ->& <: )

(f16302: )

# The presence of an eval should turn cloneless anon subs into clonable
# subs - otherwise the CvOUTSIDE of that sub may be wrong

do
    my %a
    for my $x ((@: 7,11))
        %a{+$x} = sub (@< @_) { $x=$x; sub (@< @_) { eval '$x' } }
    
    test: {(( %a{?7}->& <: )->& <: ) +(( %a{?11}->& <: )->& <: ) == 18 }


do
    # bugid #23265 - this used to coredump during destruction of PL_maincv
    # and its children

    my $progfile = "b23265.pl"
    open: my $t, ">", "$progfile" or die: "$^PROGRAM_NAME: $^OS_ERROR\n"
    print: $t  ,<< '__EOF__'
        print:
            $^STDOUT
            sub {@_[0]->(<@_)} ->& <:
                sub {
                    @_[1]
                        ??  @_[0]->(@_[0], @_[1] - 1) .  sub {"x"}->()
                        !! "y"
                }
                2
            "\n"
        ;
__EOF__
    close $t
    my $got = runperl: progfile => $progfile
    test: { chomp $got; $got eq "yxx" }
    END { 1 while (unlink: $progfile) }


do
    # bugid #24914 = used to coredump restoring PL_comppad in the
    # savestack, due to the early freeing of the anon closure

    my $got = runperl: stderr => 1, prog =>
                       'sub d {die:} my $f; $f = sub {my $x=1; $f = 0; d}; try{ $f->& <: }; print: $^STDOUT, qq(ok\n)'

    test: { $got eq "ok\n" }


# After newsub is redefined outside the BEGIN, it's CvOUTSIDE should point
# to main rather than BEGIN, and BEGIN should be freed.

do
    my $flag = 0
    sub  X::DESTROY { $flag = 1 }
    do
        my $x
        sub newsub {};
        BEGIN {$x = \&newsub }
        $x = bless: \$%, 'X'
    
    # test { $flag == 1 };
    print: $^STDOUT, "not ok $test # TODO cleanup sub freeing\n"
    $test++
