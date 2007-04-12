$!  Test.Com - DCL driver for perl5 regression tests
$!
$!  Version 1.1   4-Dec-1995
$!  Charles Bailey  bailey@newman.upenn.edu
$!
$!  A little basic setup
$   On Error Then Goto wrapup
$   olddef = F$Environment("Default")
$   oldmsg = F$Environment("Message")
$   If F$Search("t.dir").nes.""
$   Then
$       Set Default [.t]
$   Else
$       If F$TrnLNm("Perl_Root").nes.""
$       Then 
$           Set Default Perl_Root:[t]
$       Else
$           Write Sys$Error "Can't find test directory"
$           Exit 44
$       EndIf
$   EndIf
$   Set Message /NoFacility/NoSeverity/NoIdentification/NoText
$!
$   exe = ".Exe"
$   If p1.nes."" Then exe = p1
$   If F$Extract(0,1,exe) .nes. "."
$   Then
$     Write Sys$Error ""
$     Write Sys$Error "The first parameter passed to Test.Com must be the file type used for the"
$     Write Sys$Error "images produced when you built Perl (i.e. "".Exe"", unless you edited"
$     Write Sys$Error "Descrip.MMS or used the AXE=1 macro in the MM[SK] command line."
$     Write Sys$Error ""
$     Exit 44
$   EndIf
$!
$!  "debug" perl if second parameter is nonblank
$!
$   dbg = ""
$   ndbg = ""
$   if p2.nes."" then dbg  = "dbg"
$   if p2.nes."" then ndbg = "ndbg"
$!
$!  Pick up a copy of perl to use for the tests
$   If F$Search("Perl.").nes."" Then Delete/Log/NoConfirm Perl.;*
$   Copy/Log/NoConfirm [-]'ndbg'Perl'exe' []Perl.
$!
$!  Pick up a copy of vmspipe.com to use for the tests
$   If F$Search("VMSPIPE.COM").nes."" then Delete/Log/Noconfirm VMSPIPE.COM;*
$   Copy/Log/NoConfirm [-]VMSPIPE.COM []
$!
$!  Make the environment look a little friendlier to tests which assume Unix
$   cat == "Type"
$   Macro/NoDebug/NoList/Object=Echo.Obj Sys$Input
		.title echo
		.psect data,wrt,noexe
	dsc:
		.word 0
		.byte 14 ; DSC$K_DTYPE_T
		.byte 2  ; DSC$K_CLASS_D
		.long 0
		.psect code,nowrt,exe
		.entry	echo,^m<r2,r3>
		movab	dsc,r2
		pushab	(r2)
		calls	#1,G^LIB$GET_FOREIGN
		movl	4(r2),r3
		movzwl	(r2),r0
		addl2	4(r2),r0
		cmpl	r3,r0
		bgtru	sym.3
		nop	
	sym.1:
		movb	(r3),r0
		cmpb	r0,#65
		blss	sym.2
		cmpb	r0,#90
		bgtr	sym.2
		cvtbl	r0,r0
		addl2	#32,r0
		cvtlb	r0,(r3)
	sym.2:
		incl	r3
		movzwl	(r2),r0
		addl2	4(r2),r0
		cmpl	r3,r0
		blequ	sym.1
	sym.3:
		pushab	(r2)
		calls	#1,G^LIB$PUT_OUTPUT
		movl	#1,r0
		ret	
		.end echo
$   If F$Search("Echo.Exe").nes."" Then Delete/Log/NoConfirm Echo.Exe;*
$   Link/NoMap/NoTrace/Exe=Echo.Exe Echo.Obj;
$   Delete/Log/NoConfirm Echo.Obj;*
$   echo == "$" + F$Parse("Echo.Exe")
$!
$!  And do it
$   Show Process/Accounting
$   testdir = "Directory/NoHead/NoTrail/Column=1"
$   PerlShr_filespec = f$parse("Sys$Disk:[-]''dbg'PerlShr''exe'")
$   Define 'dbg'Perlshr 'PerlShr_filespec'
$   MCR Sys$Disk:[]Perl. "-I[-.lib]" - "''p3'" "''p4'" "''p5'" "''p6'"
$   Deck/Dollar=$$END-OF-TEST$$
# $RCSfile: test.com,v $$Revision: 1.1 $$Date: 2001/11/13 00:26:19 $
# Modified for VMS 30-Sep-1994  Charles Bailey  bailey@newman.upenn.edu
#
# This is written in a peculiar style, since we're trying to avoid
# most of the constructs we'll be testing for.

# skip those tests we know will fail entirely or cause perl to hang bacause
# of Unixisms in the tests.  (The Perl operators being tested may work fine,
# but the tests may use other operators which don't.)
use Config;
use File::Spec;

@compexcl=('cpp.t');
@opexcl=('die_exit.t','exec.t','stat.t');
@exclist=(@compexcl,@libexcl,@opexcl);
foreach $file (@exclist) { $skip{$file}++; }

$| = 1;

# Let tests know they're running in the perl core.  Useful for modules
# which live dual lives on CPAN.
$ENV{PERL_CORE} = 1;

@ARGV = grep($_,@ARGV);  # remove empty elements due to "''p1'" syntax

if (lc($ARGV[0]) eq '-v') {
    $verbose = 1;
    shift;
}

chdir 't' if -f 't/TEST';

if ($ARGV[0] eq '') {
    foreach (<[.*]*.t>, <[-.ext...]*.t>, <[-.lib...]*.t>) {
      $_ = File::Spec->abs2rel($_);
      s/\[([a-z]+)/[.$1/;      # hmm, abs2rel doesn't do subdirs of the cwd
      ($fname = $_) =~ s/.*\]//;
      if ($skip{"\L$fname"}) { push(@skipped,$_); }
      else { push(@ARGV,$_); }
    }
}

if (@skipped) {
  print "The following tests were skipped because they rely extensively on\n";
  print " Unixisms not compatible with the current version of perl for VMS:\n";
  print "\t",join("\n\t",@skipped),"\n\n";
}

$bad = 0;
$good = 0;
$extra_skip = 0;
$total = @ARGV;
while ($test = shift) {
    if ($test =~ /^$/) {
	next;
    }
    $te = $test;
    chop($te);
    $te .= '.' x (40 - length($te));
	open(script,"$test") || die "Can't run $test.\n";
	$_ = <script>;
	close(script);
	if (/#!..perl(.*)/) {
	    $switch = $1;
	    # Add "" to protect uppercase switches on command line
	    $switch =~ s/-(\S*[A-Z]\S*)/"-$1"/g;
	} else {
	    $switch = '';
	}
	open(results,"\$ MCR Sys\$Disk:[]Perl. \"-I[-.lib]\" $switch $test 2>&1|") || (print "can't run.\n");
    $ok = 0;
    $next = 0;
    $pending_not = 0;
    while (<results>) {
	if ($verbose) {
	    print "$te$_";
	    $te = '';
	}
	unless (/^#/) {
	    if (/^1\.\.([0-9]+)( todo ([\d ]+))?/) {
		$max = $1;
                %todo = map { $_ => 1 } split / /, $3 if $3;
		$totmax += $max;
		$files += 1;
		$next = 1;
		$ok = 1;
	    } else {
                # our 'echo' substitute produces one more \n than Unix'
		next if /^\s*$/;


                if (/^(not )?ok (\d+)[^#]*(\s*#.*)?/ &&
                    $2 == $next)
                {
                    my($not, $num, $extra) = ($1, $2, $3);
                    my($istodo) = $extra =~ /^\s*#\s*TODO/ if $extra;
                    $istodo = 1 if $todo{$num};

                    if( $not && !$istodo ) {
                        $ok = 0;
                        $next = $num;
                        last;
                    }
                    elsif( $pending_not ) {
                        $next = $num;
                        $ok = 0;
                    }
                    else {
                        $next = $next + 1;
                    }
                }
                elsif(/^not $/) {
                    # VMS has this problem.  It sometimes adds newlines
                    # between prints.  This sometimes means you get
                    # "not \nok 42"
                    $pending_not = 1;
                }
                elsif (/^Bail out!\s*(.*)/i) { # magic words
                    die "FAILED--Further testing stopped" . ($1 ? ": $1\n" : ".\n");
		}
		else {
                    $ok = 0;
		}

	    }
	}
    }
    $next = $next - 1;
    if ($ok && $next == $max) {
	if ($max) {
	    print "${te}ok\n";
	    $good = $good + 1;
	} else {
	    print "${te}skipping test on this platform\n";
	    $files -= 1;
	    $extra_skip = $extra_skip + 1;
	}
    } else {
	$next += 1;
	print "${te}FAILED on test $next\n";
	$bad = $bad + 1;
	$_ = $test;
	if (/^base/) {
	    die "Failed a basic test--cannot continue.\n";
	}
    }
}

if ($bad == 0) {
    if ($ok) {
	print "All tests successful.\n";
    } else {
	die "FAILED--no tests were run for some reason.\n";
    }
} else {
    # $pct = sprintf("%.2f", $good / $total * 100);
    $gtotal = $total - $extra_skip;
    if ($gtotal <= 0) { $gtotal = $total; }
    $pct = sprintf("%.2f", $good / $gtotal * 100);
    if ($bad == 1) {
	warn "Failed 1 test, $pct% okay.\n";
   } else {
         if ($extra_skip > 0) {
	     warn "Total tests: $total, Passed $good, Skipped $extra_skip.\n";
	     warn "Failed $bad/$gtotal tests, $pct% okay.\n";
         }
         else {
	     warn "Total tests: $total, Passed $good.\n";
	     warn "Failed $bad/$gtotal tests, $pct% okay.\n";
         }
    }
}
($user,$sys,$cuser,$csys) = times;
print sprintf("u=%g  s=%g  cu=%g  cs=%g  scripts=%d  tests=%d\n",
    $user,$sys,$cuser,$csys,$files,$totmax);
$$END-OF-TEST$$
$ wrapup:
$   deassign 'dbg'Perlshr
$   Show Process/Accounting
$   Set Default &olddef
$   Set Message 'oldmsg'
$   Exit
