#!/usr/bin/perl -w
# Test for File::Temp - Security levels

# Some of the security checking will not work on all platforms
# Test a simple open in the cwd and tmpdir foreach of the
# security levels

use Test::More
BEGIN { (plan: tests => 13) }

use File::Spec

# Set up END block - this needs to happen before we load
# File::Temp since this END block must be evaluated after the
# END block configured by File::Temp
my @files # list of files to remove
END { foreach ( @files) { (ok:  !(-e $_) )} }

use File::Temp < qw/ tempfile unlink0 /
ok: 1

# The high security tests must currently be skipped on some platforms
my $skipplat = ( (
    # No sticky bits.
    $^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare' || $^OS_NAME eq 'os2' || $^OS_NAME eq 'dos' || $^OS_NAME eq 'mpeix' || $^OS_NAME eq 'MacOS'
    ) ?? 1 !! 0 )

# Determine whether we need to skip things and why
my $skip = 0
if ($skipplat)
    $skip = "Skip Not supported on this platform"


print: $^STDOUT, "# We will be skipping some tests : $skip\n" if $skip

# start off with basic checking

File::Temp->safe_level:  (File::Temp::STANDARD: ) 

print: $^STDOUT, "# Testing with STANDARD security...\n"

test_security: 0

# Try medium

File::Temp->safe_level:  (File::Temp::MEDIUM: ) 
    unless $skip

print: $^STDOUT, "# Testing with MEDIUM security...\n"

# Now we need to start skipping tests
test_security: $skip

# Try HIGH

File::Temp->safe_level:  (File::Temp::HIGH: ) 
    unless $skip

print: $^STDOUT, "# Testing with HIGH security...\n"

test_security: $skip

exit

# Subroutine to open two temporary files.
# one is opened in the current dir and the other in the temp dir

sub test_security

    # Read in the skip flag
    my $skip = shift

    # If we are skipping we need to simply fake the correct number
    # of tests -- we dont use skip since the tempfile() commands will
    # fail with MEDIUM/HIGH security before the skip() command would be run
    if ($skip)

        skip: $skip,1
        skip: $skip,1

        # plus we need an end block so the tests come out in the right order
        eval q{ END { skip($skip,1); skip($skip,1)  } 1; } || die: 

        return
    

    # Create the tempfile
    my $template = "tmpXXXXX"
    my (@: $fh1, $fname1) =  try { (tempfile:  $template
                                               DIR => File::Spec->tmpdir
                                               UNLINK => 1
                                            );
    } || @: undef, undef

    if (defined $fname1)
        print: $^STDOUT, "# fname1 = $fname1\n"
        ok:  (-e $fname1) 
        push: @files, $fname1 # store for end block
    elsif (File::Temp->safe_level != (File::Temp::STANDARD: ))
        :SKIP
            do
            my $skip2 = "Skip: " . File::Spec->tmpdir . " possibly insecure:  $($^EVAL_ERROR && $^EVAL_ERROR->message).  " .
                "See INSTALL under 'make test'"
            skip: $skip2, 2
        
    else
        ok: 0
    

    # Explicitly
    if ( $^UID +< File::Temp->top_system_uid )
        skip: "Skip Test inappropriate for root", 1
        eval q{ END { skip($skip,1); } 1; } || die: 
        return
    
    my (@: $fh2, $fname2) =  try { (tempfile: $template,  UNLINK => 1 ); }
    if (defined $fname2)
        print: $^STDOUT, "# fname2 = $fname2\n"
        ok:  (-e $fname2) 
        push: @files, $fname2 # store for end block
        close: $fh2
    elsif (File::Temp->safe_level != (File::Temp::STANDARD: ))
        chomp: $^EVAL_ERROR
        my $skip2 = "Skip: current directory possibly insecure: $^EVAL_ERROR.  " .
            "See INSTALL under 'make test'"
        skip: $skip2, 1
        # plus we need an end block so the tests come out in the right order
        eval q{ END { skip($skip2,1); } 1; } || die: 
    else
        ok: 0
    


