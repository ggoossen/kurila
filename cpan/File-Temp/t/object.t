#!/usr/local/bin/perl -w
# Test for File::Temp - OO interface


use Test::More tests => 30
use File::Spec

# Will need to check that all files were unlinked correctly
# Set up an END block here to do it

# Arrays containing list of dirs/files to test
my (@files, @dirs, @still_there)

# And a test for files that should still be around
# These are tidied up
END 
    foreach ( @still_there)
        ok:  -f $_, "Check $_ exists" 
        ok:  (unlink:  $_ ), "Unlinked $_" 
        ok:  !(-f $_), "$_ no longer there"
    


# Loop over an array hoping that the files dont exist
END { foreach ( @files) { (ok:  !(-e $_), "File $_ should not be there" )} }

# And a test for directories
END { foreach ( @dirs)  { (ok:  !(-d $_), "Directory $_ should not be there" ) } }

# Need to make sure that the END blocks are setup before
# the ones that File::Temp configures since END blocks are evaluated
# in reverse order and we need to check the files *after* File::Temp
# removes them
BEGIN {(use_ok:  "File::Temp" ); }

# Tempfile
# Open tempfile in some directory, unlink at end
my $fh = File::Temp->new:  SUFFIX => '.txt'

ok:  (-f ($fh->filename: )), "File exists"  
# Should still be around after closing
ok:  (close:  $fh ), "Close file \$fh" 
ok:  (-f ($fh->filename: )), "File \$fh still exists after close" 
# Check again at exit
push: @files, ($fh->filename: )

# OO tempdir
my $tdir = File::Temp->newdir: 
my $dirname = $tdir->dirname: 
ok:  -d $dirname, "Directory \$tdir exists"
undef $tdir
ok:  !-d $dirname, "Directory should now be gone"

# Quick basic tempfile test
my $qfh = File::Temp->new: 
my $qfname = $qfh->filename: 
ok: -f $qfname, "temp file exists"
undef $qfh
ok:  !-f $qfname, "temp file now gone"


# TEMPDIR test as somewhere to put the temp files
# Create temp directory in current dir
my $template = 'tmpdirXXXXXX'
print: $^STDOUT, "# Template: $template\n"
my $tempdir = File::Temp::tempdir:  $template 
                                    DIR => (File::Spec->curdir: )
                                    CLEANUP => 1
                                   

print: $^STDOUT, "# TEMPDIR: $tempdir\n"

ok:  (-d $tempdir), "Does $tempdir directory exist" 
push: @dirs, $tempdir

# Create file in the temp dir
$fh = File::Temp->new: 
    DIR => $tempdir
    SUFFIX => '.dat',

ok:  ($fh->unlink_on_destroy: ), "should unlink"
print: $^STDOUT, "# TEMPFILE: Created \$fh\n"

ok:  (-f ($fh->filename: )), "File \$fh exists in tempdir?"
push: @files, ($fh->filename: )

# Test tempfile
# ..and again (without unlinking it)
$fh = File::Temp->new:  DIR => $tempdir, UNLINK => 0

print: $^STDOUT, "# TEMPFILE: Created \$fh\n"
ok:  (-f ($fh->filename: ) ), "Second file \$fh exists in tempdir [nounlink]?"
push: @files, ($fh->filename: )

# and another (with template)

$fh = File::Temp->new:  TEMPLATE => 'helloXXXXXXX'
                        DIR => $tempdir
                        SUFFIX => '.dat',

print: $^STDOUT, "# TEMPFILE: Created \$fh\n"

ok:  (-f ($fh->filename: )), "File \$fh exists? [from template]" 
push: @files, ($fh->filename: )


# Create a temporary file that should stay around after
# it has been closed
$fh = File::Temp->new:  TEMPLATE => 'permXXXXXXX', UNLINK => 0

print: $^STDOUT, "# TEMPFILE: Created \$fh\n"
ok:  -f ($fh->filename: ), "File \$fh exists?" 
ok:  (close:  $fh ), "Close file \$fh" 
ok:  ! ($fh->unlink_on_destroy: ), "should not unlink"
push:  @still_there, ($fh->filename: ) # check at END

# Now create a temp file that will remain when the object
# goes out of scope because of $KEEP_ALL
$fh = File::Temp->new:  TEMPLATE => 'permXXXXXXX', UNLINK => 1

print: $^STDOUT, "# TEMPFILE: Created \$fh\n"
ok:  -f ($fh->filename: ), "File \$fh exists?" 
ok:  (close:  $fh ), "Close file \$fh" 
ok:  ($fh->unlink_on_destroy: ), "should unlink (in principal)"
push:  @still_there, ($fh->filename: ) # check at END
$File::Temp::KEEP_ALL = 1

# Make sure destructors run
undef $fh

# allow end blocks to run
$File::Temp::KEEP_ALL = 0

# Now END block will execute to test the removal of directories
print: $^STDOUT, "# End of tests. Execute END blocks\n"

