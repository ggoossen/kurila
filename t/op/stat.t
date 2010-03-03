#!./perl

BEGIN 
    require './test.pl'	# for which_perl() etc


use Config
use File::Spec

plan: tests => 106

my $Perl = (which_perl: )

my $Is_Amiga   = $^OS_NAME eq 'amigaos'
my $Is_Cygwin  = $^OS_NAME eq 'cygwin'
my $Is_Darwin  = $^OS_NAME eq 'darwin'
my $Is_Dos     = $^OS_NAME eq 'dos'
my $Is_MacOS   = $^OS_NAME eq 'MacOS'
my $Is_MPE     = $^OS_NAME eq 'mpeix'
my $Is_MSWin32 = $^OS_NAME eq 'MSWin32'
my $Is_NetWare = $^OS_NAME eq 'NetWare'
my $Is_OS2     = $^OS_NAME eq 'os2'
my $Is_Solaris = $^OS_NAME eq 'solaris'
my $Is_VMS     = $^OS_NAME eq 'VMS'
my $Is_DGUX    = $^OS_NAME eq 'dgux'
my $Is_MPRAS   = $^OS_NAME =~ m/svr4/ && -f '/etc/.relid'
my $Is_Rhapsody= $^OS_NAME eq 'rhapsody'

my $Is_Dosish  = $Is_Dos || $Is_OS2 || $Is_MSWin32 || $Is_NetWare || $Is_Cygwin

my $Is_UFS     = $Is_Darwin && (@: `df -t ufs . 2>/dev/null`) == 2

my(@: $DEV, $INO, $MODE, $NLINK, $UID, $GID, $RDEV, $SIZE
      $ATIME, $MTIME, $CTIME, $BLKSIZE, $BLOCKS) = @:  <0..12

my $Curdir = File::Spec->curdir: 


my $tmpfile = 'Op_stat.tmp'
my $tmpfile_link = $tmpfile.'2'

chmod: 0666, $tmpfile
1 while unlink: $tmpfile
(open: my $foo, ">", "$tmpfile") || DIE: "Can't open temp test file: $^OS_ERROR"
close $foo

(open: $foo, ">", "$tmpfile") || DIE: "Can't open temp test file: $^OS_ERROR"

my(@: $nlink, $mtime, $ctime) =  (@: (stat: $foo))[[(@: $NLINK, $MTIME, $CTIME)]]

# The clock on a network filesystem might be different from the
# system clock.
my $Filesystem_Time_Offset = (abs: $mtime - time) 

#nlink should if link support configured in Perl.
:SKIP do
    skip: "No link count - Hard link support not built in.", 1
        unless config_value: 'd_link'

    is: $nlink, 1, 'nlink on regular file'


:SKIP do
    skip: "mtime and ctime not reliable", 2
        if $Is_MSWin32 or $Is_NetWare or $Is_Cygwin or $Is_Dos or $Is_MacOS or $Is_Darwin

    ok:  $mtime,           'mtime' 
    is:  $mtime, $ctime,   'mtime == ctime' 



# Cygwin seems to have a 3 second granularity on its timestamps.
my $funky_FAT_timestamps = $Is_Cygwin
sleep 3 if $funky_FAT_timestamps

print: $foo, "Now is the time for all good men to come to.\n"
close: $foo

sleep 2


:SKIP do
    unlink: $tmpfile_link
    my $lnk_result = try { (link: $tmpfile, $tmpfile_link) }
    skip: "link() unimplemented", 6 if $^EVAL_ERROR and $^EVAL_ERROR->{?description} =~ m/unimplemented/

    is:  $^EVAL_ERROR, '',         'link() implemented' 
    ok:  $lnk_result,    'linked tmp testfile' 
    ok:  (chmod: 0644, $tmpfile),             'chmoded tmp testfile' 

    my(@: $nlink, $mtime, $ctime) =  (@: (stat: $tmpfile))[[(@: $NLINK, $MTIME, $CTIME)]]

    :SKIP do
        skip: "No link count", 1 if config_value: 'dont_use_nlink'
        skip: "Cygwin9X fakes hard links by copying", 1
            if (config_value: 'myuname') =~ m/^cygwin_(?:9\d|me)\b/i

        is: $nlink, 2,     'Link count on hard linked file' 
    

    :SKIP do
        my $cwd = File::Spec->rel2abs: $Curdir
        skip: "Solaris tmpfs has different mtime/ctime link semantics", 2
            if $Is_Solaris and $cwd =~ m#^/tmp# and
              $mtime && $mtime == $ctime
        skip: "AFS has different mtime/ctime link semantics", 2
            if $cwd =~ m#$((config_value: 'afsroot'))/#
        skip: "AmigaOS has different mtime/ctime link semantics", 2
            if $Is_Amiga
        # Win32 could pass $mtime test but as FAT and NTFS have
        # no ctime concept $ctime is ALWAYS == $mtime
        # expect netware to be the same ...
        skip: "No ctime concept on this OS", 2
            if $Is_MSWin32 ||
          ($Is_Darwin && $Is_UFS)

        if( !(ok: $mtime, 'hard link mtime') ||
            !(isnt: $mtime, $ctime, 'hard link ctime != mtime') )
            print: $^STDERR, <<DIAG
# Check if you are on a tmpfs of some sort.  Building in /tmp sometimes
# has this problem.  Building on the ClearCase VOBS filesystem may also
# cause this failure.
#
# Darwin's UFS doesn't have a ctime concept, and thus is expected to fail
# this test.
DIAG
        
    



# truncate and touch $tmpfile.
(open: my $f, ">", "$tmpfile") || DIE: "Can't open temp test file: $^OS_ERROR"
ok: -z $f,     '-z on empty filehandle'
ok: ! -s $f,   '   and -s'
close $f

ok: -z $tmpfile,     '-z on empty file'
ok: ! -s $tmpfile,   '   and -s'

(open: $f, ">", "$tmpfile") || DIE: "Can't open temp test file: $^OS_ERROR"
print: $f, "hi\n"
close $f

(open: $f, "<", "$tmpfile") || DIE: "Can't open temp test file: $^OS_ERROR"
ok: !-z $f,     '-z on empty filehandle'
ok:  -s $f,   '   and -s'
close $f

ok: ! -z $tmpfile,   '-z on non-empty file'
ok: -s $tmpfile,     '   and -s'


# Strip all access rights from the file.
ok:  (chmod: 0000, $tmpfile),     'chmod 0000' 

:SKIP do
    skip: "-r, -w and -x have different meanings on VMS", 3 if $Is_VMS

    :SKIP do
        # Going to try to switch away from root.  Might not work.
        my $olduid = $^UID
        try { $^UID = 1; }
        skip: "Can't test -r or -w meaningfully if you're superuser", 2
            if $^UID == 0

        :SKIP do
            skip: "Can't test -r meaningfully?", 1 if $Is_Dos || $Is_Cygwin
            ok: !-r $tmpfile,    "   -r"
        

        ok: !-w $tmpfile,    "   -w"

        # switch uid back (may not be implemented)
        try { $^UID = $olduid; }
    

    ok: ! -x $tmpfile,   '   -x'




ok: (chmod: 0700,$tmpfile),    'chmod 0700'
ok: -r $tmpfile,     '   -r'
ok: -w $tmpfile,     '   -w'

:SKIP do
    skip: "-x simply determines if a file ends in an executable suffix", 1
        if $Is_Dosish || $Is_MacOS

    ok: -x $tmpfile,     '   -x'


ok:   -f $tmpfile,   '   -f'
ok: ! -d $tmpfile,   '   !-d'

# Is this portable?
ok:   -d $Curdir,          '-d cwd' 
ok: ! -f $Curdir,          '!-f cwd' 


:SKIP do
    unlink: $tmpfile_link
    my $symlink_rslt = try { (symlink: $tmpfile, $tmpfile_link) }
    skip: "symlink not implemented", 3 if $^EVAL_ERROR and $^EVAL_ERROR->{?description} =~ m/unimplemented/

    is:  $^EVAL_ERROR, '',     'symlink() implemented' 
    ok:  $symlink_rslt,      'symlink() ok' 
    ok: -l $tmpfile_link,    '-l'


ok: -o $tmpfile,     '-o'

ok: -e $tmpfile,     '-e'

unlink: $tmpfile_link
ok: ! -e $tmpfile_link,  '   -e on unlinked file'

:SKIP do
    skip: "No character, socket or block special files", 6
        if $Is_MSWin32 || $Is_NetWare || $Is_Dos
    skip: "/dev isn't available to test against", 6
        unless -d '/dev' && -r '/dev' && -x '/dev'
    skip: "Skipping: unexpected ls output in MP-RAS", 6
        if $Is_MPRAS

    # VMS problem:  If GNV or other UNIX like tool is installed, then
    # sometimes Perl will find /bin/ls, and will try to run it.
    # But since Perl on VMS does not know to run it under Bash, it will
    # try to run the DCL verb LS.  And if the VMS product Language
    # Sensitive Editor is installed, or some other LS verb, that will
    # be run instead.  So do not do this until we can teach Perl
    # when to use BASH on VMS.
    skip: "ls command not available to Perl in OpenVMS right now.", 6
        if $Is_VMS

    my $LS  = (config_value: 'd_readlink') ?? "ls -lL" !! "ls -l"
    my $CMD = "$LS /dev 2>/dev/null"
    my $DEV = qx($CMD)

    skip: "$CMD failed", 6 if $DEV eq ''

    my @DEV = @:  do { my $dev; (opendir: $dev, "/dev") ?? (readdir: $dev) !! () } 

    skip: "opendir failed: $^OS_ERROR", 6 if (nelems @DEV) == 0

    # /dev/stdout might be either character special or a named pipe,
    # or a symlink, or a socket, depending on which OS and how are
    # you running the test, so let's censor that one away.
    # Similar remarks hold for stderr.
    $DEV =~ s{^[cpls].+?\sstdout$}{}m
    @DEV = grep: { $_ ne 'stdout' }, @DEV
    $DEV =~ s{^[cpls].+?\sstderr$}{}m
    @DEV = grep: { $_ ne 'stderr' }, @DEV

    # /dev/printer is also naughty: in IRIX it shows up as
    # Srwx-----, not srwx------.
    $DEV =~ s{^.+?\sprinter$}{}m
    @DEV = grep: { $_ ne 'printer' }, @DEV

    # If running as root, we will see .files in the ls result,
    # and readdir() will see them always.  Potential for conflict,
    # so let's weed them out.
    $DEV =~ s{^.+?\s\..+?$}{}m
    @DEV = grep: { ! m{^\..+$} }, @DEV

    # Irix ls -l marks sockets with 'S' while 's' is a 'XENIX semaphore'.
    if ($^OS_NAME eq 'irix')
        $DEV =~ s{^S(.+?)}{s$1}mg
    

    my $try = sub (@< @_)
        my @c1 = @:  eval qq[\$DEV =~ m/^@_[0].*/mg] 
        die: if $^EVAL_ERROR
        my @c2 = eval qq[grep: \{ @_[1] "/dev/\$_" \}, \@DEV]
        die: if $^EVAL_ERROR
        my $c1 = nelems @c1
        my $c2 = nelems @c2
        is: $c1, $c2, "ls and @_[1] agreeing on /dev ($c1 $c2)"
    

    :SKIP do
        skip: "DG/UX ls -L broken", 3 if $Is_DGUX

        $try->& <: 'b', '-b'
        $try->& <: 'c', '-c'
        $try->& <: 's', '-S'

    

    ok: ! -b $Curdir,    '!-b cwd'
    ok: ! -c $Curdir,    '!-c cwd'
    ok: ! -S $Curdir,    '!-S cwd'



:SKIP do
    my($cnt, $uid)
    $cnt = 0
    $uid = 0

    # Find a set of directories that's very likely to have setuid files
    # but not likely to be *all* setuid files.
    my @bin = grep: {-d && -r && -x}, qw(/sbin /usr/sbin /bin /usr/bin)
    skip: "Can't find a setuid file to test with", 3 unless (nelems @bin)

    for my $bin ( @bin)
        opendir: my $bin_dh, $bin or die: "Can't opendir $bin: $^OS_ERROR"
        while ((defined: ($_ = readdir $bin_dh)))
            $_ = "$bin/$_"
            $cnt++
            $uid++ if -u
            last if $uid && $uid +< $cnt
        
        closedir $bin_dh
    

    skip: "No setuid programs", 3 if $uid == 0

    isnt: $cnt, 0,    'found some programs'
    isnt: $uid, 0,    '  found some setuid programs'
    ok: $uid +< $cnt,  "    they're not all setuid"



# To assist in automated testing when a controlling terminal (/dev/tty)
# may not be available (at, cron  rsh etc), the PERL_SKIP_TTY_TEST env var
# can be set to skip the tests that need a tty.
:SKIP do
    skip: "These tests require a TTY", 4 if env::var: 'PERL_SKIP_TTY_TEST'

    my $TTY = $Is_Rhapsody ?? "/dev/ttyp0" !! "/dev/tty"

    :SKIP do
        skip: "Test uses unixisms", 2 if $Is_MSWin32 || $Is_NetWare
        skip: "No TTY to test -t with", 2 unless -e $TTY

        (open: my $tty_fh, "<", $TTY) ||
            warn: "Can't open $TTY--run t/TEST outside of make.\n"
        ok: -t $tty_fh,  '-t'
        ok: -c $tty_fh,  'tty is -c'
        close: $tty_fh
    
    ok: ! -t *TTY,    '!-t on closed TTY filehandle'


my $Null = File::Spec->devnull: 
:SKIP do
    skip: "No null device to test with", 1 unless -e $Null
    skip: "We know Win32 thinks '$Null' is a TTY", 1 if $Is_MSWin32

    open: my $null_fh, "<", $Null or DIE: "Can't open $Null: $^OS_ERROR"
    ok: ! -t $null_fh,   'null device is not a TTY'
    close: $null_fh



# These aren't strictly "stat" calls, but so what?
my $statfile = File::Spec->catfile: $Curdir, 'op', 'stat.t'
ok:   -T $statfile,    '-T'
ok: ! -B $statfile,    '!-B'

:SKIP do
    skip: "DG/UX", 1 if $Is_DGUX
    ok: -B $Perl,      '-B'


ok: ! -T $Perl,    '!-T'

open: $foo, "<",$statfile
:SKIP do
    try { -T $foo; }
    skip: "-T/B on filehandle not implemented", 15 if $^EVAL_ERROR and $^EVAL_ERROR->{?description} =~ m/not implemented/

    is:  $^EVAL_ERROR, '',     '-T on filehandle causes no errors' 

    ok: -T $foo,      '   -T'
    ok: ! -B $foo,    '   !-B'

    $_ = ~< $foo
    like: $_, qr/perl/, 'after readline'
    ok: -T $foo,      '   still -T'
    ok: ! -B $foo,    '   still -B'
    close: $foo

    open: $foo, "<",$statfile
    $_ = ~< $foo
    like: $_, qr/perl/,      'reopened and after readline'
    ok: -T $foo,      '   still -T'
    ok: ! -B $foo,    '   still !-B'

    ok: (seek: $foo,0,0),   'after seek'
    ok: -T $foo,          '   still -T'
    ok: ! -B $foo,        '   still !-B'

    @: ~< $foo
    ok: eof $foo,         'at EOF'
    ok: -T $foo,          '   still -T'
    ok: -B $foo,          '   now -B'

close: $foo


:SKIP do
    skip: "No null device to test with", 2 unless -e $Null

    ok: -T $Null,  'null device is -T'
    ok: -B $Null,  '    and -B'



# and now, a few parsing tests:
$_ = $tmpfile
ok: -f,      'bare -f   uses $_'
ok: -f(),    '     -f() "'

unlink: $tmpfile or print: $^STDOUT, "# unlink failed: $^OS_ERROR\n"

# bug id 20011101.069
my @r = @:  stat: $Curdir 
is: nelems @r, 13,   'stat returns full 13 elements'

stat $^PROGRAM_NAME
dies_like:  sub (@< @_) { lstat _ }
            qr/^The stat preceding lstat\(\) wasn't an lstat/
            'lstat _ croaks after stat' 
dies_like:  sub (@< @_) { -l _ }
            qr/^The stat preceding -l _ wasn't an lstat/
            '-l _ croaks after stat' 

lstat $^PROGRAM_NAME
try { lstat _ }
is:  "$^EVAL_ERROR", "", "lstat _ ok after lstat" 
try { -l _ }
is:  "$^EVAL_ERROR", "", "-l _ ok after lstat" 

:SKIP do
    skip: "No lstat", 2 unless config_value: 'd_lstat'

    # bug id 20020124.004
    # If we have d_lstat, we should have symlink()
    my $linkname = 'dolzero'
    symlink: $^PROGRAM_NAME, $linkname or die: "# Can't symlink $^PROGRAM_NAME: $^OS_ERROR"
    lstat $linkname
    -T _
    dies_like: sub (@< @_) { lstat _ }
               qr/^The stat preceding lstat\(\) wasn't an lstat/
               'lstat croaks after -T _' 
    dies_like: sub (@< @_) { -l _ }
               qr/^The stat preceding -l _ wasn't an lstat/
               '-l _ croaks after -T _' 
    unlink: $linkname or print: $^STDOUT, "# unlink $linkname failed: $^OS_ERROR\n"


print: $^STDOUT, "# Zzz...\n"
sleep: 3
my $f = 'tstamp.tmp'
unlink: $f
ok: (open: my $s, ">", "$f"), 'can create tmp file'
close $s or die: 
my @a = @:  stat $f 
print: $^STDOUT, "# time=$^BASETIME, stat=($((join: ' ',@a)))\n"
my @b = @: -M _, -A _, -C _
print: $^STDOUT, "# -MAC=($((join: ' ',@b)))\n"
ok:  (-M _) +< 0, 'negative -M works'
ok:  (-A _) +< 0, 'negative -A works'
ok:  (-C _) +< 0, 'negative -C works'
ok: (unlink: $f), 'unlink tmp file'

do
    ok: (open: my $f, ">", $tmpfile), 'can create temp file'
    close $f
    chmod: 0077, $tmpfile
    my @a = @:  stat: $tmpfile 
    my $s1 = -s _
    -T _
    my $s2 = -s _
    is: $s1, $s2, q(-T _ doesn't break the statbuffer)
    unlink: $tmpfile


:SKIP do
    skip: "No dirfd()", 9 unless (config_value: 'd_dirfd') || config_value: 'd_dir_dd_fd'
    (ok: (opendir: my $dir, "."), 'Can open "." dir') || diag: "Can't open '.':  $^OS_ERROR"
    ok: (stat: $dir), "stat() on dirhandle works"
    ok: -d -r _ , "chained -x's on dirhandle"
    ok: -d $dir, "-d on a dirhandle works"

    # And now for the ambigious bareword case
    ok: (open: $dir, "<", "TEST"), 'Can open "TEST" dir'
       || diag: "Can't open 'TEST':  $^OS_ERROR"
    my $size = (@: (stat: $dir))[7]
    ok: defined $size, "stat() on bareword works"
    is: $size, -s "TEST", "size returned by stat of bareword is for the file"
    ok: -f _, "ambiguous bareword uses file handle, not dir handle"
    ok: -f $dir
    closedir $dir or die: $^OS_ERROR
    close $dir or die: $^OS_ERROR


do
    # RT #8244: *FILE{IO} does not behave like *FILE for stat() and -X() operators
    ok: (open: my $f, ">", $tmpfile), 'can create temp file'
    my @thwap = @:  stat $f 
    ok: (nelems @thwap), "stat(\$f) works"
    ok:  -f $f, "single file tests work with *F\{IO\}"
    close $f
    unlink: $tmpfile

    #PVIO's hold dirhandle information, so let's test them too.

    :SKIP do
        skip: "No dirfd()", 9 unless (config_value: 'd_dirfd') || config_value: 'd_dir_dd_fd'
        (ok: (opendir: my $dir, "."), 'Can open "." dir') || diag: "Can't open '.':  $^OS_ERROR"
        ok: (stat: $dir), "stat() on *DIR\{IO\} works"
        ok: -d _ , "The special file handle _ is set correctly"
        ok: -d -r $dir , "chained -x's on *DIR\{IO\}"

        # And now for the ambigious bareword case
        ok: (open: $dir, "<", "TEST"), 'Can open "TEST" dir'
           || diag: "Can't open 'TEST':  $^OS_ERROR"
        my $size = (@: (stat: $dir))[7]
        ok: defined $size, "stat() on *THINGY\{IO\} works"
        is: $size, -s "TEST"
            "size returned by stat of *THINGY\{IO\} is for the file"
        ok: -f _, "ambiguous *THINGY\{IO\} uses file handle, not dir handle"
        ok: -f $dir
        closedir $dir or die: $^OS_ERROR
        close $dir or die: $^OS_ERROR
    


END 
    chmod: 0666, $tmpfile
    1 while unlink: $tmpfile

