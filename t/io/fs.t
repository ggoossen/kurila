#!./perl

BEGIN 
    require "./test.pl"


use Config
use File::Spec::Functions

my $Is_MacOS  = ($^OS_NAME eq 'MacOS')
my $Is_VMSish = ($^OS_NAME eq 'VMS')

our ($wd, $newmode, $delta, $foo)

if (($^OS_NAME eq 'MSWin32') || ($^OS_NAME eq 'NetWare'))
    $wd = `cd`
elsif ($^OS_NAME eq 'VMS')
    $wd = `show default`
else
    $wd = `pwd`

chomp: $wd

my $has_link            = config_value: 'd_link'
my $accurate_timestamps =
    !($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare' ||
      $^OS_NAME eq 'dos'     || $^OS_NAME eq 'os2'     ||
      $^OS_NAME eq 'cygwin'  ||
      $^OS_NAME eq 'amigaos' || $wd =~ m#$((config_value: 'afsroot'))/# ||
      $Is_MacOS
      )

if (exists &Win32::IsWinNT &&( Win32::IsWinNT: ))
    if ((Win32::FsType: ) eq 'NTFS')
        $has_link            = 1
        $accurate_timestamps = 1


my $needs_fh_reopen =
    $^OS_NAME eq 'dos'
    # Not needed on HPFS, but needed on HPFS386 ?!
    || $^OS_NAME eq 'os2'

$needs_fh_reopen = 1 if (exists &Win32::IsWin95 &&( Win32::IsWin95: ))

my $skip_mode_checks =
      $^OS_NAME eq 'cygwin' && (env::var: 'CYGWIN') !~ m/ntsec/

plan: tests => 51


if (($^OS_NAME eq 'MSWin32') || ($^OS_NAME eq 'NetWare'))
    `rmdir /s /q tmp 2>nul`
    `mkdir tmp`
elsif ($^OS_NAME eq 'VMS')
    `if f\$search("[.tmp]*.*") .nes. "" then delete/nolog/noconfirm [.tmp]*.*.*`
    `if f\$search("tmp.dir") .nes. "" then set file/prot=o:rwed tmp.dir;`
    `if f\$search("tmp.dir") .nes. "" then delete/nolog/noconfirm tmp.dir;`
    `create/directory [.tmp]`
elsif ($Is_MacOS)
    rmdir "tmp"; mkdir: "tmp"
else
    `rm -f tmp 2>/dev/null; mkdir tmp 2>/dev/null`

my $tmpdir = (tempfile: )
my $tmpdir1 = (tempfile: )

chdir catdir: (curdir: ), 'tmp'

`/bin/rm -rf a b c x` if -x '/bin/rm'

umask: 022

:SKIP do
    skip: "bogus umask", 1 if ($^OS_NAME eq 'MSWin32') || ($^OS_NAME eq 'NetWare') || ($^OS_NAME eq 'epoc') || $Is_MacOS

    (is: ((umask: 0)^&^0777), 022, 'umask'),


(open: my $fh, ">",'x') || die: "Can't create x"
close: $fh
(open: $fh, ">",'a') || die: "Can't create a"
close: $fh

my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
    $blksize,$blocks,$a_mode)

:SKIP do
    skip: "no link", 4 unless $has_link

    ok: (link: 'a','b'), "link a b"
    ok: (link: 'b','c'), "link b c"

    $a_mode = (@: (stat: 'a'))[2]

    (@: $dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime
        $blksize,$blocks) = @: stat: 'c'

    :SKIP do
        skip: "no nlink", 1 if config_value: 'dont_use_nlink'

        is: $nlink, 3, "link count of triply-linked file"
    

    :SKIP do
        skip: "hard links not that hard in $^OS_NAME", 1 if $^OS_NAME eq 'amigaos'
        skip: "no mode checks", 1 if $skip_mode_checks

        #      if ($^O eq 'cygwin') { # new files on cygwin get rwx instead of rw-
        #          is($mode & 0777, 0777, "mode of triply-linked file");
        #      } else {
        is: (sprintf: '0%o', $mode ^&^ 0777)
            (sprintf: '0%o', $a_mode ^&^ 0777)
            "mode of triply-linked file"
    #      }
    


$newmode = (($^OS_NAME eq 'MSWin32') || ($^OS_NAME eq 'NetWare')) ?? 0444 !! 0777

is: (chmod: $newmode,'a'), 1, "chmod succeeding"

:SKIP do
    skip: "no link", 7 unless $has_link

    (@: $dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime
        $blksize,$blocks) = @: stat: 'c'

    :SKIP do
        skip: "no mode checks", 1 if $skip_mode_checks

        is: $mode ^&^ 0777, $newmode, "chmod going through"
    

    $newmode = 0700
    chmod: 0444, 'x'
    $newmode = 0666

    is: (chmod: $newmode,'c','x'), 2, "chmod two files"

    (@: $dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime
        $blksize,$blocks) = @: stat: 'c'

    :SKIP do
        skip: "no mode checks", 1 if $skip_mode_checks

        is: $mode ^&^ 0777, $newmode, "chmod going through to c"
    

    (@: $dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime
        $blksize,$blocks) = @: stat: 'x'

    :SKIP do
        skip: "no mode checks", 1 if $skip_mode_checks

        is: $mode ^&^ 0777, $newmode, "chmod going through to x"
    

    is: (unlink: 'b','x'), 2, "unlink two files"

    (@: ?$dev,?$ino,?$mode,?$nlink,?$uid,?$gid,?$rdev,?$size,?$atime,?$mtime,?$ctime
        ?$blksize,?$blocks) = @: stat: 'b'

    is: $ino, undef, "ino of removed file b should be undef"

    (@: ?$dev,?$ino,?$mode,?$nlink,?$uid,?$gid,?$rdev,?$size,?$atime,?$mtime,?$ctime
        ?$blksize,?$blocks) = @: stat: 'x'

    is: $ino, undef, "ino of removed file x should be undef"


:SKIP do
    skip: "no fchmod", 5 unless ((config_value: 'd_fchmod') || "") eq "define"
    ok: (open: my $fh, "<", "a"), "open a"
    is: (chmod: 0, $fh), 1, "fchmod"
    $mode = (@: stat "a")[2]
    :SKIP do
        skip: "no mode checks", 1 if $skip_mode_checks
        is: $mode ^&^ 0777, 0, "perm reset"
    
    is: (chmod: $newmode, "a"), 1, "fchmod"
    $mode = (@: stat $fh)[2]
    :SKIP do
        skip: "no mode checks", 1 if $skip_mode_checks
        is: $mode ^&^ 0777, $newmode, "perm restored"
    


:SKIP do
    skip: "no fchown", 1 unless ((config_value: 'd_fchown') || "") eq "define"
    open: my $fh, "<", "a"
    is: (chown: -1, -1, $fh), 1, "fchown"


:SKIP do
    skip: "has fchmod", 1 if ((config_value: 'd_fchmod') || "") eq "define"
    open: my $fh, "<", "a"
    try { (chmod: 0777, $fh); }
    like: $^EVAL_ERROR->{?description}, qr/^The fchmod function is unimplemented at/, "fchmod is unimplemented"


:SKIP do
    skip: "has fchown", 1 if ((config_value: 'd_fchown') || "") eq "define"
    open: my $fh, "<", "a"
    try { (chown: 0, 0, $fh); }
    like: $^EVAL_ERROR->{?description}, qr/^The f?chown function is unimplemented at/, "fchown is unimplemented"


is: (rename: 'a','b'), 1, "rename a b"

(@: ?$dev,?$ino,?$mode,?$nlink,?$uid,?$gid,?$rdev,?$size,?$atime,?$mtime,?$ctime
    ?$blksize,?$blocks) = @: stat: 'a'

is: $ino, undef, "ino of renamed file a should be undef"

$delta = $accurate_timestamps ?? 1 !! 2	# Granularity of time on the filesystem
chmod: 0777, 'b'

$foo = (utime: 500000000,500000000 + $delta,'b')
is: $foo, 1, "utime"
(check_utime_result: )

utime: undef, undef, 'b'
(@: $atime,$mtime) =  (@: stat 'b')[[8..9]]
print: $^STDOUT, "# utime undef, undef --> $atime, $mtime\n"
isnt: $atime, 500000000, 'atime'
isnt: $mtime, 500000000 + $delta, 'mtime'

:SKIP do
    skip: "no futimes", 4 unless ((config_value: 'd_futimes') || "") eq "define"
    open: my $fh, "<", 'b'
    $foo = ((utime: 500000000,500000000 + $delta, $fh))
    is: $foo, 1, "futime"
    (check_utime_result: )



sub check_utime_result()
    (@: $dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime
        $blksize,$blocks) = @: stat: 'b'

    :SKIP do
        skip: "bogus inode num", 1 if ($^OS_NAME eq 'MSWin32') || ($^OS_NAME eq 'NetWare')

        ok: $ino,    'non-zero inode num'
    

    :SKIP do
        skip: "filesystem atime/mtime granularity too low", 2
            unless $accurate_timestamps

        print: $^STDOUT, "# atime - $atime  mtime - $mtime  delta - $delta\n"
        if($atime == 500000000 && $mtime == 500000000 + $delta)
            pass: 'atime'
            pass: 'mtime'
        else
            if ($^OS_NAME =~ m/\blinux\b/i)
                print: $^STDOUT, "# Maybe stat() cannot get the correct atime, ".
                           "as happens via NFS on linux?\n"
                $foo = (utime: 400000000,500000000 + 2*$delta,'b')
                my (@: $new_atime, $new_mtime) =  (@: (stat: 'b'))[[8..9]]
                print: $^STDOUT, "# newatime - $new_atime  nemtime - $new_mtime\n"
                if ($new_atime == $atime && $new_mtime - $mtime == $delta)
                    pass: "atime - accounted for possible NFS/glibc2.2 bug on linux"
                    pass: "mtime - accounted for possible NFS/glibc2.2 bug on linux"
                else
                    fail: "atime - $atime/$new_atime $mtime/$new_mtime"
                    fail: "mtime - $atime/$new_atime $mtime/$new_mtime"
                
            elsif ($^OS_NAME eq 'VMS')
                # why is this 1 second off?
                is:  $atime, 500000001,          'atime' 
                is:  $mtime, 500000000 + $delta, 'mtime' 
            elsif ($^OS_NAME eq 'beos')
                :SKIP do
                    skip: "atime not updated", 1
                
                is: $mtime, 500000001, 'mtime'
            else
                fail: "atime"
                fail: "mtime"
            
        
    


:SKIP do
    skip: "has futimes", 1 if ((config_value: 'd_futimes') || "") eq "define"
    (open: my $fh, "<", "b") || die: 
    try { (utime: undef, undef, $fh); }
    like: $^EVAL_ERROR->{?description}, qr/^The futimes function is unimplemented at/, "futimes is unimplemented"


is: (unlink: 'b'), 1, "unlink b"

(@: ?$dev,?$ino,?$mode,?$nlink,?$uid,?$gid,?$rdev,?$size,?$atime,?$mtime,?$ctime
    ?$blksize,?$blocks) = @: stat: 'b'
is: $ino, undef, "ino of unlinked file b should be undef"
unlink: 'c'

chdir $wd || die: "Can't cd back to $wd"

# Yet another way to look for links (perhaps those that cannot be
# created by perl?).  Hopefully there is an ls utility in your
# %PATH%. N.B. that $^O is 'cygwin' on Cygwin.

:SKIP do
    skip: "Win32/Netware specific test", 2
        unless ($^OS_NAME eq 'MSWin32') || ($^OS_NAME eq 'NetWare')
    skip: "No symbolic links found to test with", 2
        unless  `ls -l perl 2>nul` =~ m/^l.*->/

    system: "cp TEST TEST$^PID"
    # we have to copy because e.g. GNU grep gets huffy if we have
    # a symlink forest to another disk (it complains about too many
    # levels of symbolic links, even if we have only two)
    is: (symlink: "TEST$^PID","c"), 1, "symlink"
    $foo = `grep perl c 2>&1`
    ok: $foo, "found perl in c"
    unlink: 'c'
    unlink: "TEST$^PID"


unlink: "Iofs.tmp"
open: my $iofscom, ">", "Iofs.tmp" or die: "Could not write IOfs.tmp: $^OS_ERROR"
print: $iofscom, 'helloworld'
close: $iofscom

# TODO: pp_truncate needs to be taught about F_CHSIZE and F_FREESP,
# as per UNIX FAQ.

:SKIP do
    # Check truncating a closed file.
    try { (truncate: "Iofs.tmp", 5); }

    skip: "no truncate - $^EVAL_ERROR", 8 if $^EVAL_ERROR

    is: -s "Iofs.tmp", 5, "truncation to five bytes"

    truncate: "Iofs.tmp", 0

    ok: -z "Iofs.tmp",    "truncation to zero bytes"

    #these steps are necessary to check if file is really truncated
    #On Win95, $fh is updated, but file properties aren't
    open: $fh, ">", "Iofs.tmp" or die: "Can't create Iofs.tmp"
    print: $fh, "x\n" x 200
    close $fh

    # Check truncating an open file.
    open: $fh, ">>", "Iofs.tmp" or die: "Can't open Iofs.tmp for appending"

    binmode: $fh
    iohandle::output_autoflush: $fh, 1

    do
        print: $fh, "x\n" x 200
        ok: (truncate: $fh, 200), "fh resize to 200"

    if ($needs_fh_reopen)
        (close: $fh); open: $fh, ">>", "Iofs.tmp" or die: "Can't reopen Iofs.tmp"

    :SKIP do
        if ($^OS_NAME eq 'vos')
            skip: "# TODO - hit VOS bug posix-973 - cannot resize an open file below the current file pos.", 5

        is: -s "Iofs.tmp", 200, "fh resize to 200 working (filename check)"

        ok: (truncate: $fh, 0), "fh resize to zero"

        if ($needs_fh_reopen)
            (close: $fh); open: $fh, ">>", "Iofs.tmp" or die: "Can't reopen Iofs.tmp"

        ok: -z "Iofs.tmp", "fh resize to zero working (filename check)"

        close $fh

        open: $fh, ">>", "Iofs.tmp" or die: "Can't open Iofs.tmp for appending"

        binmode: $fh
        iohandle::output_autoflush: $fh, 1

        do
            print: $fh, "x\n" x 200
            ok: (truncate: $fh, 100), "fh resize by IO slot"

        if ($needs_fh_reopen)
            (close: $fh); open: $fh, ">>", "Iofs.tmp" or die: "Can't reopen Iofs.tmp"

        is: -s "Iofs.tmp", 100, "fh resize by IO slot working"

        close $fh


# check if rename() can be used to just change case of filename
:SKIP do
    skip: "Works in Cygwin only if check_case is set to relaxed", 1
        if ((env::var: 'CYGWIN') && ((env::var: 'CYGWIN') =~ m/check_case:(?:adjust|strict)/))

    chdir './tmp'
    (open: $fh, ">",'x') || die: "Can't create x"
    close: $fh
    rename: 'x', 'X'

    # this works on win32 only, because fs isn't casesensitive
    ok: -e 'X', "rename working"

    1 while unlink: 'X'
    chdir $wd || die: "Can't cd back to $wd"


# check if rename() works on directories
if ($^OS_NAME eq 'VMS')
    # must have delete access to rename a directory
    `set file tmp.dir/protection=o:d`
    (ok: (rename: 'tmp.dir', 'tmp1.dir'), "rename on directories") ||
        print: $^STDOUT, "# errno: $^OS_ERROR\n"
else
    ok: (rename: 'tmp', 'tmp1'), "rename on directories"


ok: -d 'tmp1', "rename on directories working"

do
    # Change 26011: Re: A surprising segfault
    # to make sure only that these obfuscated sentences will not crash.

    map: { (chmod: ) }, @:  ('')x68
    ok: 1, "extend sp in pp_chmod"

    map: { (chown: ) }, @:  ('')x68
    ok: 1, "extend sp in pp_chown"


# need to remove $tmpdir if rename() in test 28 failed!
END { rmdir $tmpdir1; rmdir $tmpdir; }
