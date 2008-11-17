package TestPodChecker;

BEGIN {
   use File::Basename;
   use File::Spec;
   push @INC, '..';
   my $THISDIR = dirname $0;
   unshift @INC, $THISDIR;
   require "testcmp.pl";
   TestCompare->import();
   my $PARENTDIR = dirname $THISDIR;
   push @INC, < map { 'File::Spec'->catfile($_, 'lib') } @( ($PARENTDIR, $THISDIR));
   require VMS::Filespec if $^O eq 'VMS';
}

use Pod::Checker;
use vars < qw(@ISA @EXPORT $MYPKG);
#use diagnostics;
use Exporter;
#use File::Compare;

@ISA = qw(Exporter);
@EXPORT = qw(&testpodchecker);
$MYPKG = try { (caller)[[0]] };

sub stripname( $ ) {
   local $_ = shift;
   return m/(\w[.\w]*)\s*$/ ?? $1 !! $_;
}

sub msgcmp( $ $ ) {
   ## filter out platform-dependent aspects of error messages
   my $lines = @_;
   for ($lines) {
      ## remove filenames from error messages to avoid any
      ## filepath naming differences between OS platforms
      s/(at line \S+ in file) .*\W(\w+\.[tT])\s*$/$("$1 ".lc($2))/;
      s/.*\W(\w+\.[tT]) (has \d+ pod syntax error)/$(lc($1)." $2")/;
   }
   return $lines[0] ne $lines[1];
}

sub testpodcheck( @ ) {
   my %args = %( < @_ );
   my $infile  = %args{'In'}  || die "No input file given!";
   my $outfile = %args{'Out'} || die "No output file given!";
   my $cmpfile = %args{'Cmp'} || die "No compare-result file given!";

   my $different = '';
   my $testname = basename $cmpfile, '.t', '.xr';

   unless (-e $cmpfile) {
      my $msg = "*** Can't find comparison file $cmpfile for testing $infile";
      warn  "$msg\n";
      return  $msg;
   }

   print "# Running podchecker for '$testname'...\n";
   ## Compare the output against the expected result
   if ($^O eq 'VMS') {
      for (@($infile, $outfile, $cmpfile)) {
         $_ = VMS::Filespec::unixify($_)  unless  ref;
      }
   }
   podchecker($infile, $outfile);
   if ( testcmp(\%('cmplines' => \&msgcmp), $outfile, $cmpfile) ) {
       $different = "$outfile is different from $cmpfile";
   }
   else {
       unlink($outfile);
   }
   return  $different;
}

sub testpodchecker( @ ) {
   my %opts = %( (ref @_[0] eq 'HASH') ?? < %{shift()} !! () );
   my @testpods = @_;
   my @($testname, $testdir) = @("", "");
   my $cmpfile = "";
   my @($outfile, $errfile) = @("", "");
   my $passes = 0;
   my $failed = 0;
   local $_;

   print "1..", nelems @testpods, "\n"  unless (%opts{?'xrgen'});

   for my $podfile ( @testpods) {
      @($testname, $_, ...) =  fileparse($podfile);
      $testdir ||=  $_;
      $testname  =~ s/\.t$//;
      $cmpfile   =  $testdir . $testname . '.xr';
      $outfile   =  $testdir . $testname . '.OUT';

      if (%opts{?'xrgen'}) {
          if (%opts{?'force'} or ! -e $cmpfile) {
             ## Create the comparison file
             print "# Creating expected result for \"$testname\"" .
                   " podchecker test ...\n";
             podchecker($podfile, $cmpfile);
          }
          else {
             print "# File $cmpfile already exists" .
                   " (use 'force' to regenerate it).\n";
          }
          next;
      }

      my $failmsg = testpodcheck
                        In  => $podfile,
                        Out => $outfile,
                        Cmp => $cmpfile;
      if ($failmsg) {
          ++$failed;
          print "#\tFAILED. ($failmsg)\n";
	  print "not ok ", $failed+$passes, "\n";
      }
      else {
          ++$passes;
          unlink($outfile);
          print "#\tPASSED.\n";
	  print "ok ", $failed+$passes, "\n";
      }
   }
   return  $passes;
}

1;
