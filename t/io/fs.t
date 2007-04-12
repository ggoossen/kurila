#!./perl

# $RCSfile: fs.t,v $$Revision: 4.1 $$Date: 92/08/07 18:27:28 $

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
}

use Config;

my $Is_VMSish = ($^O eq 'VMS');
$Is_Dosish = ($^O eq 'MSWin32' or $^O eq 'NetWare' or $^O eq 'dos' or
	      $^O eq 'os2' or $^O eq 'mint' or $^O eq 'cygwin' or
	      $^O eq 'mpeix');

if (defined &Win32::IsWinNT && Win32::IsWinNT()) {
    $Is_Dosish = '' if Win32::FsType() eq 'NTFS';
}

print "1..29\n";

$wd = ((($^O eq 'MSWin32') || ($^O eq 'NetWare')) ? `cd` : ($Is_VMSish) ? `show default` : `pwd`);
chop($wd);

if (($^O eq 'MSWin32') || ($^O eq 'NetWare')) {
    `rmdir /s /q tmp 2>nul`;
    `mkdir tmp`;
}
elsif ($Is_VMSish) {
    `if f\$search("[.tmp]*.*") .nes. "" then delete/nolog/noconfirm [.tmp]*.*.*`;
    `if f\$search("tmp.dir") .nes. "" then delete/nolog/noconfirm tmp.dir;`;
    `create/directory [.tmp]`;
}
else {
    `rm -f tmp 2>/dev/null; mkdir tmp 2>/dev/null`;
}
chdir './tmp';
`/bin/rm -rf a b c x` if -x '/bin/rm';

umask(022);

if (($^O eq 'MSWin32') || ($^O eq 'NetWare')) { print "ok 1 # skipped: bogus umask()\n"; }
elsif ((umask(0)&0777) == 022) {print "ok 1\n";} else {print "not ok 1\n";}
open(fh,'>x') || die "Can't create x";
close(fh);
open(fh,'>a') || die "Can't create a";
close(fh);

if ($Is_Dosish || $Is_VMSish) {print "ok 2 # skipped: no link\n";} 
elsif (eval {link('a','b')}) {print "ok 2\n";} 
else {print "not ok 2\n";}

if ($Is_Dosish || $Is_VMSish) {print "ok 3 # skipped: no link\n";} 
elsif (eval {link('b','c')}) {print "ok 3\n";} 
else {print "not ok 3\n";}

($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
    $blksize,$blocks) = stat('c');

if ($Config{dont_use_nlink} || $Is_Dosish || $Is_VMSish)
    {print "ok 4 # skipped: no link\n";} 
elsif ($nlink == 3)
    {print "ok 4\n";} 
else {print "not ok 4\n";}

if ($^O eq 'amigaos' || $Is_Dosish || $Is_VMSish)
    {print "ok 5 # skipped: no link\n";} 
elsif (($mode & 0777) == 0666)
    {print "ok 5\n";} 
else {print "not ok 5\n";}

$newmode = (($^O eq 'MSWin32') || ($^O eq 'NetWare')) ? 0444 : 0777;
if ((chmod $newmode,'a') == 1) {print "ok 6\n";} else {print "not ok 6\n";}

($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
    $blksize,$blocks) = stat('c');
if ($Is_Dosish || $Is_VMSish) {print "ok 7 # skipped: no link\n";} 
elsif (($mode & 0777) == $newmode) {print "ok 7\n";} 
else {print "not ok 7\n";}

$newmode = 0700;
if (($^O eq 'MSWin32') || ($^O eq 'NetWare')) {
    chmod 0444, 'x';
    $newmode = 0666;
}

if ($Is_Dosish || $Is_VMSish) {print "ok 8 # skipped: no link\n";} 
elsif ((chmod $newmode,'c','x') == 2) {print "ok 8\n";} 
else {print "not ok 8\n";}

($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
    $blksize,$blocks) = stat('c');
if ($Is_Dosish || $Is_VMSish) {print "ok 9 # skipped: no link\n";} 
elsif (($mode & 0777) == $newmode) {print "ok 9\n";} 
else {print "not ok 9\n";}

($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
    $blksize,$blocks) = stat('x');
if ($Is_Dosish || $Is_VMSish) {print "ok 10 # skipped: no link\n";} 
elsif (($mode & 0777) == $newmode) {print "ok 10\n";} 
else {print "not ok 10\n";}

if ($Is_Dosish || $Is_VMSish) {print "ok 11 # skipped: no link\n"; unlink 'b','x'; } 
elsif ((unlink 'b','x') == 2) {print "ok 11\n";} 
else {print "not ok 11\n";}
($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
    $blksize,$blocks) = stat('b');
if ($ino == 0) {print "ok 12\n";} else {print "not ok 12\n";}
($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
    $blksize,$blocks) = stat('x');
if ($ino == 0) {print "ok 13\n";} else {print "not ok 13\n";}

if (rename('a','b')) {print "ok 14\n";} else {print "not ok 14\n";}
($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
    $blksize,$blocks) = stat('a');
if ($ino == 0) {print "ok 15\n";} else {print "not ok 15\n";}
$delta = $Is_Dosish ? 2 : 1;	# Granularity of time on the filesystem
chmod 0777, 'b';
$foo = (utime 500000000,500000000 + $delta,'b');
if ($foo == 1) {print "ok 16\n";} else {print "not ok 16 $foo\n";}
($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
    $blksize,$blocks) = stat('b');
if (($^O eq 'MSWin32') || ($^O eq 'NetWare')) { print "ok 17 # skipped: bogus (stat)[1]\n"; }
elsif ($ino) {print "ok 17\n";} else {print "not ok 17\n";}
if ($wd =~ m#$Config{'afsroot'}/# || $^O eq 'amigaos' || $^O eq 'dos' || $^O eq 'MSWin32' || $^O eq 'NetWare' || $^O eq 'cygwin')
    {print "ok 18 # skipped: granularity of the filetime\n";}
elsif ($atime == 500000000 && $mtime == 500000000 + $delta)
    {print "ok 18\n";}
elsif ($^O =~ /\blinux\b/i) {
    # Maybe stat() cannot get the correct atime, as happens via NFS on linux?
    $foo = (utime 400000000,500000000 + 2*$delta,'b');
    my ($new_atime, $new_mtime) = (stat('b'))[8,9];
    if ($new_atime == $atime && $new_mtime - $mtime == $delta)
	{print "ok 18 # accounted for possible NFS/glibc2.2 bug on linux\n";}
    else
	{print "not ok 18 $atime/$new_atime $mtime/$new_mtime\n";}
}
elsif ($Is_VMSish) {
    if ($atime == 500000001 && $mtime == 500000000 + $delta)
        {print "ok 18\n";}
    else
	{print "not ok 18 $atime $mtime\n";}
} else
    {print "not ok 18 $atime $mtime\n";}

if ((unlink 'b') == 1) {print "ok 19\n";} else {print "not ok 19\n";}
($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
    $blksize,$blocks) = stat('b');
if ($ino == 0) {print "ok 20\n";} else {print "not ok 20\n";}
unlink 'c';

chdir $wd || die "Can't cd back to $wd";

unlink 'c';
# Yet another way to look for links (perhaps those that cannot be created by perl?).
# Hopefully there is an ls utility in your %PATH%. N.B. that $^O is 'cygwin' on Cygwin.
if ((($^O eq 'MSWin32') || ($^O eq 'NetWare')) and `ls -l perl 2>nul` =~ /^l.*->/) {
    # we have symbolic links
    system("cp TEST TEST$$");
    # we have to copy because e.g. GNU grep gets huffy if we have
    # a symlink forest to another disk (it complains about too many
    # levels of symbolic links, even if we have only two)
    if (symlink("TEST$$","c")) {print "ok 21\n";} else {print "not ok 21\n";}
    $foo = `grep perl c 2>&1`;
    if ($foo) {print "ok 22\n";} else {print "not ok 22\n";}
    unlink 'c';
    unlink("TEST$$");
}
else {
    if ( ($^O eq 'MSWin32') || ($^O eq 'NetWare') ) {
        print "ok 21 # skipped: no link\nok 22 # skipped: no link\n";
    }
    else {
        print "ok 21 # skipped: $^O is neither 'MSWin32' nor 'NetWare'\nok 22 # skipped: $^O is neither 'MSWin32' nor 'NetWare'\n";
    }
}

# truncate (may not be implemented everywhere)
unlink "Iofs.tmp";
if ($Is_VMSish) {
    open IOFSCOM, ">Iofs.tmp" or die "Could not write IOfs.tmp: $!";
    print IOFSCOM 'helloworld';
    close(IOFSCOM);
}
else {
    `echo helloworld > Iofs.tmp`;
}
#
# Perhaps the eval would be better written with a construct such as?:
#if (defined($Config{d_truncate}) && $Config{d_truncate} eq 'define') {
#
eval { truncate "Iofs.tmp", 5; };
if ($@) {
  if ($@ =~ /not implemented/) {
    print "# truncate not implemented -- skipping tests 23 through 26\n";
    for (23 .. 26) {
      print "ok $_ # Skip: no truncate\n";
    }
  } else {
    warn "io/fs before test 23: truncate dies with \$\@[$@]";
  }
}
else {
  if (-s "Iofs.tmp" == 5) {
    print "ok 23\n";
  } else {
    my $s = -s "Iofs.tmp";
    printf "# -s Iofs.tmp: %s\n", defined($s) ? $s : "UNDEFINED";
    print "not ok 23\n";
  }
  truncate "Iofs.tmp", 0;
  if (-z "Iofs.tmp") {print "ok 24\n"} else {print "not ok 24\n"}
  open(FH, ">Iofs.tmp") or die "Can't create Iofs.tmp";
  binmode FH;
  { select FH; $| = 1; select STDOUT }
  {
    use strict;
    print FH "x\n" x 200;
    truncate(FH, 200) or die "Can't truncate FH: $!";
  }
  if ($^O eq 'dos'
	# Not needed on HPFS, but needed on HPFS386 ?!
      or $^O eq 'os2')
  {
      close (FH); open (FH, ">>Iofs.tmp") or die "Can't reopen Iofs.tmp";
  }
  if (-s "Iofs.tmp" == 200) {
      print "ok 25\n"
  }
  else {
    my $s = -s "Iofs.tmp";
    printf "# -s Iofs.tmp: %s\n", defined($s) ? $s : "UNDEFINED";
    print "not ok 25\n";
  }
  truncate FH, 0;
  if ($^O eq 'dos'
	# Not needed on HPFS, but needed on HPFS386 ?!
      or $^O eq 'os2')
  {
      close (FH); open (FH, ">>Iofs.tmp") or die "Can't reopen Iofs.tmp";
  }
  if (-z "Iofs.tmp") {print "ok 26\n"} else {print "not ok 26\n"}
  close FH;
}

# check if rename() can be used to just change case of filename
if ($^O eq 'cygwin') {
  print "ok 27 # skipped: works only if check_case is set to relaxed.\n";
} else { 
  chdir './tmp';
  open(fh,'>x') || die "Can't create x";
  close(fh);
  rename('x', 'X');
  
  # this works on win32 only, because fs isn't casesensitive
  print 'not ' unless -e 'X'; 
  
  print "ok 27\n";
  unlink 'X';
  chdir $wd || die "Can't cd back to $wd";
}

# check if rename() works on directories
if ($Is_VMSish) {
    # must have delete access to rename a directory
    `set file tmp.dir/protection=o:d`;
    rename 'tmp.dir', 'tmp1.dir' or print "not ";
}
else {
    rename 'tmp', 'tmp1' or print "not ";
}
print "ok 28\n";
-d 'tmp1' or print "not ";
print "ok 29\n";

# need to remove 'tmp' if rename() in test 28 failed!
END { rmdir 'tmp1'; rmdir 'tmp'; unlink "Iofs.tmp"; }
