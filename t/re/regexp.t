#!./perl

# The tests are in a separate file 't/re/re_tests'.
# Each line in that file is a separate test.
# There are five columns, separated by tabs.
#
# Column 1 contains the pattern, optionally enclosed in C<''>.
# Modifiers can be put after the closing C<'>.
#
# Column 2 contains the string to be matched.
#
# Column 3 contains the expected result:
# 	y	expect a match
# 	n	expect no match
# 	c	expect an error
#	T	the test is a TODO (can be combined with y/n/c)
#	B	test exposes a known bug in Perl, should be skipped
#	b	test exposes a known bug in Perl, should be skipped if noamp
#
# Columns 4 and 5 are used only if column 3 contains C<y> or C<c>.
#
# Column 4 contains a string, usually C<$&>.
#
# Column 5 contains the expected result of double-quote
# interpolating that string after the match, or start of error message.
#
# Column 6, if present, contains a reason why the test is skipped.
# This is printed with "skipped", for harness to pick up.
#
# \n in the tests are interpolated, as are variables of the form ${\w+}.
#
# Blanks lines are treated as PASSING tests to keep the line numbers
# linked to the test number.
#
# If you want to add a regular expression test that can't be expressed
# in this format, don't add it here: put it in re/pat.t instead.
#
# Note that columns 2,3 and 5 are all enclosed in double quotes and then
# evalled; so something like a\"\x{100}$1 has length 3+length($1).

my $file

use warnings FATAL=>"all"
our ($iters, $numtests, $bang, $ffff, $nulnul, $OP, $utf8)
our ($qr, $skip_amp, $qr_embed) # set by our callers

my $tests_fh

BEGIN 
    $iters = (shift: @ARGV) || 1	# Poor man performance suite, 10000 is OK.

    # Do this open before any chdir
    $file = shift: @ARGV
    if (defined $file)
        open: $tests_fh, "<", $file or die: "Can't open $file"
    


use warnings FATAL=>"all"
our ($iters, $numtests, $bang, $ffff, $nulnul, $OP)
our ($qr, $skip_amp, $qr_embed) # set by our callers


if (!defined $file)
    (open: $tests_fh, "<",'re/re_tests') || open: $tests_fh, "<",'t/re/re_tests'
        || (open: $tests_fh, "<",':re:re_tests') || die: "Can't open re_tests"


my @tests = @:  ~< $tests_fh 

close $tests_fh

BEGIN 
    require utf8
    if (1)
        $utf8 = "use utf8;\n"
        utf8->import: 

$bang = sprintf: "\\\%03o", ord "!" # \41 would not be portable.
$ffff  = "\x[FF]\x[FF]"
$nulnul = "\0" x 2
$OP = $qr ?? 'qr' !! 'm'

$^OUTPUT_AUTOFLUSH = 1
printf: $^STDOUT, "1..\%d\n# $iters iterations\n", nelems @tests

my $test
:TEST
    foreach ( @tests)
    $test++
    if (!m/\S/ || m/^\s*#/ || m/^__END__$/)
        print: $^STDOUT, "ok $test # (Blank line or comment)\n"
        if (m/#/) { (print: $^STDOUT, $_) };
        next
    
    chomp
    s/\\n/\n/g
    my (@: $pat, $subject, $result, $repl, $expect, ?$reason) =  split: m/\t/,$_,6
    if ($result =~ m/c/ and env::var: 'PERL_VALGRIND')
        print: $^STDOUT, "ok $test # TODO fix memory leak with compilation error\n"
        next
    
    $reason = '' unless defined $reason
    my $input = join: ':', (@: $pat,$subject,$result,$repl,$expect)
    $pat = "'$pat'" unless $pat =~ m/^[:'\/]/
    $pat =~ s/\$\{(\w+)\}/$(eval '$'.$1)/g
    $pat =~ s/\\n/\n/g
    my $keep = ($repl =~ m/\$\^MATCH/) ?? 'p' !! ''
    $subject = eval qq("$subject"); die: "error in '$subject': $(($^EVAL_ERROR->message: ))" if $^EVAL_ERROR
    $expect  = eval qq("$expect"); die: "error in '$expect': $(($^EVAL_ERROR->message: ))" if $^EVAL_ERROR
    my $skip = ($skip_amp ?? ($result =~ s/B//i) !! ($result =~ s/B//))
    $reason = 'skipping $&' if $reason eq  '' && $skip_amp
    $result =~ s/B//i unless $skip

    for my $study ((@: '', 'study $subject'))
        # Need to make a copy, else the utf8::upgrade of an alreay studied
        # scalar confuses things.
        my $subject = $subject
        my $c = $iters
        my ($code, $match, $got)
        if ($repl eq 'pos')
            $code= <<EOFCODE
                $utf8;
                $study;
                pos(\$subject, 0);
                \$match = ( \$subject =~ m$($pat)$($keep)g );
                \$got = pos(\$subject);
EOFCODE
        elsif ($qr_embed)
            $code= <<EOFCODE
                $utf8;
                my \$RE = qr$pat;
                $study;
                \$match = (\$subject =~ m/(?:)\$RE(?:)/$($keep)) while \$c--;
                \$got = "$repl";
EOFCODE
        else
            $code= <<EOFCODE
                $utf8;
                $study;
                \$match = (\$subject =~ $OP$pat$keep) while \$c--;
                \$got = "$repl";
EOFCODE
        
        #$code.=qq[\n\$expect="$expect";\n];
        #use Devel::Peek;
        #die Dump($code) if $pat=~/\\h/ and $subject=~/\x{A0}/;
        do
            # Probably we should annotate specific tests with which warnings
            # categories they're known to trigger, and hence should be
            # disabled just for that test
            no warnings < qw(uninitialized regexp)
            eval $code
        
        my $err = $^EVAL_ERROR
        if ($result eq 'c')
            if ($err->{?description} !~ m!^\Q$expect!) { print: $^STDOUT, "not ok $test (compile) $input => `$err'\n"; next TEST }
            last  # no need to study a syntax error
        elsif ( $skip )
            print: $^STDOUT, "ok $test # skipped", (length: $reason) ?? " $reason" !! '', "\n"
            next TEST
        elsif ($err)
            (print: $^STDOUT, "not ok $test $input => error: '$(($^EVAL_ERROR->message: ))'\n$((dump::view: $code))\n"); next TEST
        elsif ($result =~ m/^n/)
            if ($match) { print: $^STDOUT, "not ok $test ($study) $input => false positive\n"; next TEST }
        else
            if (!$match || $got ne $expect)
                try { require Data::Dumper }
                if ($^EVAL_ERROR)
                    print: $^STDOUT, "not ok $test ($study) $input => `$got', match=$match\n$code\n"
                else # better diagnostics
                    my $s =( ('Data::Dumper'->new: \(@: $subject),\(@: 'subject'))->Useqq: 1)->Dump: 
                    my $g =( ('Data::Dumper'->new: \(@: $got),\(@: 'got'))->Useqq: 1)->Dump: 
                    print: $^STDOUT, "not ok $test ($study) $input => `$got', match=$match\n$s\n$g\n$code\n"
                
                next TEST
    
    print: $^STDOUT, "ok $test\n"

1
