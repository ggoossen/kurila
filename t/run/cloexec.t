#!./perl
#
# Test inheriting file descriptors across exec (close-on-exec).
#
# perlvar describes $^F aka $SYSTEM_FD_MAX as follows:
#
#  The maximum system file descriptor, ordinarily 2.  System file
#  descriptors are passed to exec()ed processes, while higher file
#  descriptors are not.  Also, during an open(), system file descriptors
#  are preserved even if the open() fails.  (Ordinary file descriptors
#  are closed before the open() is attempted.)  The close-on-exec
#  status of a file descriptor will be decided according to the value of
#  C<$^F> when the corresponding file, pipe, or socket was opened, not
#  the time of the exec().
#
# This documented close-on-exec behaviour is typically implemented in
# various places (e.g. pp_sys.c) with code something like:
#
#  #if defined(HAS_FCNTL) && defined(F_SETFD)
#      fcntl(fd, F_SETFD, fd > PL_maxsysfd);  /* ensure close-on-exec */
#  #endif
#
# This behaviour, therefore, is only currently implemented for platforms
# where:
#
#  a) HAS_FCNTL and F_SETFD are both defined
#  b) Integer fds are native OS handles
#
# ... which is typically just the Unix-like platforms.
#
# Notice that though integer fds are supported by the C runtime library
# on Windows, they are not native OS handles, and so are not inherited
# across an exec (though native Windows file handles are).

BEGIN {
    require './test.pl';
}

BEGIN {
    use Config;
    if (! config_value('d_fcntl')) {
        skip_all("fcntl() is not available");
    }
}

my $Is_VMS      = $^OS_NAME eq 'VMS';
my $Is_MacOS    = $^OS_NAME eq 'MacOS';
my $Is_Win32    = $^OS_NAME eq 'MSWin32';

# When in doubt, skip.
skip_all("MacOS")    if $Is_MacOS;
skip_all("VMS")      if $Is_VMS;
skip_all("Win32")    if $Is_Win32;

sub make_tmp_file {
    my @($fname, $fcontents) =  @_;
    my $fhtmp;
    open   $fhtmp, ">", "$fname"  or die "open  '$fname': $^OS_ERROR";
    print  $fhtmp, $fcontents  or die "print '$fname': $^OS_ERROR";
    close  $fhtmp             or die "close '$fname': $^OS_ERROR";
}

my $Perl = which_perl();
my $quote = $Is_VMS || $Is_Win32 ?? '"' !! "'";

my $tmperr             = 'cloexece.tmp';
my $tmpfile1           = 'cloexec1.tmp';
my $tmpfile2           = 'cloexec2.tmp';
my $tmpfile1_contents  = "tmpfile1 line 1\ntmpfile1 line 2\n";
my $tmpfile2_contents  = "tmpfile2 line 1\ntmpfile2 line 2\n";
make_tmp_file($tmpfile1, $tmpfile1_contents);
make_tmp_file($tmpfile2, $tmpfile2_contents);

# $Child_prog is the program run by the child that inherits the fd.
# Note: avoid using ' or " in $Child_prog since it is run with -e
my $Child_prog = <<'CHILD_PROG';
my $fd = shift(@ARGV);
print $^STDOUT, qq{childfd=$fd\n};
open my $inherit, qq{<&=}, qq{$fd} or die qq{open $fd: $^OS_ERROR};
my $line = ~< $inherit;
close $inherit or die qq{close $fd: $^OS_ERROR};
print $^STDOUT, $line
CHILD_PROG
$Child_prog =~ s/\n//g;

plan(tests => 22);

sub test_not_inherited {
    my $expected_fd = shift;
    ok( -f $tmpfile2, "tmpfile '$tmpfile2' exists" );
    my $cmd = qq{$Perl -e $quote$Child_prog$quote $expected_fd};
    # Expect 'Bad file descriptor' or similar to be written to STDERR.
    my $saverr; open $saverr, ">&", $^STDERR;  # save original STDERR
    open $^STDERR, ">", "$tmperr" or die "open '$tmperr': $^OS_ERROR";
    my $out = `$cmd`;
    my $rc  = $^CHILD_ERROR >> 8;
    open $^STDERR, ">&", $saverr or die "error: restore STDERR: $^OS_ERROR";
    close $saverr or die "error: close SAVERR: $^OS_ERROR";
    # XXX: it seems one cannot rely on a non-zero return code,
    # at least not on Tru64.
    # cmp_ok( $rc, '!=', 0,
    #     "child return code=$rc (non-zero means cannot inherit fd=$expected_fd)" );
    cmp_ok( nelems(@: $out =~ m/(\n)/g), '==', 1,
        "child stdout: has 1 newline (rc=$rc, should be non-zero)" );
    is( $out, "childfd=$expected_fd\n", 'child stdout: fd' );
}

sub test_inherited {
    my $expected_fd = shift;
    ok( -f $tmpfile1, "tmpfile '$tmpfile1' exists" );
    my $cmd = qq{$Perl -e $quote$Child_prog$quote $expected_fd};
    my $out = `$cmd`;
    my $rc  = $^CHILD_ERROR >> 8;
    cmp_ok( $rc, '==', 0,
        "child return code=$rc (zero means inherited fd=$expected_fd ok)" );
    my @lines = split(m/^/, $out);
    cmp_ok( (nelems @($out =~ m/(\n)/g)), '==', 2, 'child stdout: has 2 newlines' );
    cmp_ok( scalar(nelems @lines),  '==', 2, 'child stdout: split into 2 lines' );
    is( @lines[0], "childfd=$expected_fd\n", 'child stdout: fd' );
    is( @lines[1], "tmpfile1 line 1\n",      'child stdout: line 1' );
}

$^SYSTEM_FD_MAX == 2 or print $^STDERR, "# warning: \$^F is $^SYSTEM_FD_MAX (not 2)\n";

# Should not be able to inherit > $^F in the default case.
open my $fhparent2, "<", "$tmpfile2" or die "open '$tmpfile2': $^OS_ERROR";
my $parentfd2 = fileno $fhparent2;
defined $parentfd2 or die "fileno: $^OS_ERROR";
cmp_ok( $parentfd2, '+>', $^SYSTEM_FD_MAX, "parent open fd=$parentfd2 (\$^F=$^SYSTEM_FD_MAX)" );
test_not_inherited($parentfd2);
close $fhparent2 or die "close '$tmpfile2': $^OS_ERROR";

# Should be able to inherit $^F after setting to $parentfd2
# Need to set $^F before open because close-on-exec set at time of open.
$^SYSTEM_FD_MAX = $parentfd2;
open my $fhparent1, "<", "$tmpfile1" or die "open '$tmpfile1': $^OS_ERROR";
my $parentfd1 = fileno $fhparent1;
defined $parentfd1 or die "fileno: $^OS_ERROR";
cmp_ok( $parentfd1, '+<=', $^SYSTEM_FD_MAX, "parent open fd=$parentfd1 (\$^F=$^SYSTEM_FD_MAX)" );
test_inherited($parentfd1);
close $fhparent1 or die "close '$tmpfile1': $^OS_ERROR";

# ... and test that you cannot inherit fd = $^F+n.
open $fhparent1, "<", "$tmpfile1" or die "open '$tmpfile1': $^OS_ERROR";
open $fhparent2, "<", "$tmpfile2" or die "open '$tmpfile2': $^OS_ERROR";
$parentfd2 = fileno $fhparent2;
defined $parentfd2 or die "fileno: $^OS_ERROR";
cmp_ok( $parentfd2, '+>', $^SYSTEM_FD_MAX, "parent open fd=$parentfd2 (\$^F=$^SYSTEM_FD_MAX)" );
test_not_inherited($parentfd2);
close $fhparent2 or die "close '$tmpfile2': $^OS_ERROR";
close $fhparent1 or die "close '$tmpfile1': $^OS_ERROR";

# ... and now you can inherit after incrementing.
$^SYSTEM_FD_MAX = $parentfd2;
open $fhparent2, "<", "$tmpfile2" or die "open '$tmpfile2': $^OS_ERROR";
open $fhparent1, "<", "$tmpfile1" or die "open '$tmpfile1': $^OS_ERROR";
$parentfd1 = fileno $fhparent1;
defined $parentfd1 or die "fileno: $^OS_ERROR";
cmp_ok( $parentfd1, '+<=', $^SYSTEM_FD_MAX, "parent open fd=$parentfd1 (\$^F=$^SYSTEM_FD_MAX)" );
test_inherited($parentfd1);
close $fhparent1 or die "close '$tmpfile1': $^OS_ERROR";
close $fhparent2 or die "close '$tmpfile2': $^OS_ERROR";

END {
    defined $tmperr   and unlink($tmperr);
    defined $tmpfile1 and unlink($tmpfile1);
    defined $tmpfile2 and unlink($tmpfile2);
}
