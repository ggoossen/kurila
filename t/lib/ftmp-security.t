#!./perl

BEGIN {
    chdir 't' if -d 't';
    unshift @INC, '../lib';
}

# Test for File::Temp - Security levels

# Some of the security checking will not work on all platforms
# Test a simple open in the cwd and tmpdir foreach of the
# security levels

use strict;
use Test;
BEGIN { plan tests => 13}

use File::Spec;
use File::Temp qw/ tempfile unlink0 /;
ok(1);

# The high security tests must currently be skipped on Windows
my $skipplat = ( $^O eq 'MSWin32' ? 1 : 0 );

# Can not run high security tests in perls before 5.6.0
my $skipperl  = ($] < 5.006 ? 1 : 0 );

# Determine whether we need to skip things and why
my $skip = 0;
if ($skipplat) {
  $skip = "Skip Not supported on this platform";
} elsif ($skipperl) {
  $skip = "Skip Perl version must be v5.6.0 for these tests";

}

print "# We will be skipping some tests : $skip\n" if $skip;

# start off with basic checking

File::Temp->safe_level( File::Temp::STANDARD );

print "# Testing with STANDARD security...\n";

&test_security(0);

# Try medium

File::Temp->safe_level( File::Temp::MEDIUM )
  unless $skip;

print "# Testing with MEDIUM security...\n";

# Now we need to start skipping tests
&test_security($skip);

# Try HIGH

File::Temp->safe_level( File::Temp::HIGH )
  unless $skip;

print "# Testing with HIGH security...\n";

&test_security($skip);

exit;

# Subroutine to open two temporary files.
# one is opened in the current dir and the other in the temp dir

sub test_security {

  # Read in the skip flag
  my $skip = shift;

  # If we are skipping we need to simply fake the correct number
  # of tests -- we dont use skip since the tempfile() commands will
  # fail with MEDIUM/HIGH security before the skip() command would be run
  if ($skip) {
    
    skip($skip,1);
    skip($skip,1);
    
    # plus we need an end block so the tests come out in the right order
    eval q{ END { skip($skip,1); skip($skip,1)  } 1; } || die;
    
    return;
  }


  # End blocks are evaluated in reverse order
  # If I want to check that the file was unlinked by the autmoatic
  # feature of the module I have to set up the end block before 
  # creating the file.
  # Use quoted end block to retain access to lexicals
  my @files;

  eval q{ END { foreach (@files) { ok( !(-e $_) )} } 1; } || die; 


  my $template = "temptestXXXXXXXX";
  my ($fh1, $fname1) = tempfile ( $template, 
				  DIR => File::Spec->curdir,
				  UNLINK => 1,
				);
  print "# Fname1 = $fname1\n";
  ok( ( -e $fname1) );

  # Explicitly 
  my ($fh2, $fname2) = tempfile ($template,  UNLINK => 1 );
  ok( (-e $fname2) );
  close($fh2);

  # Store filenames for the end block
  push(@files, $fname1, $fname2);



}
