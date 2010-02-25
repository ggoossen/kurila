# NOTE: this file tests how large files (>2GB) work with raw system IO.
# stdio: open(), tell(), seek(), print(), read() is tested in t/op/lfs.t.
# If you modify/add tests here, remember to update also t/op/lfs.t.

use Config

BEGIN 
    # Don't bother if there are no quad offsets.
    if ((config_value: 'lseeksize') +< 8)
        print: $^STDOUT, "1..0 # Skip: no 64-bit file offsets\n"
        exit: 0
    
    require Fcntl; Fcntl->import:  < qw(/^O_/ /^SEEK_/)



$^OUTPUT_AUTOFLUSH = 1

our @s
our $fail

my $big_fh

sub zap
    close: $big_fh
    unlink: "big"
    unlink: "big1"
    unlink: "big2"


sub bye()
    (zap: )
    exit: 0


my $explained

sub explain
    unless ($explained++)
        print: $^STDOUT, <<EOM
#
# If the lfs (large file support: large meaning larger than two
# gigabytes) tests are skipped or fail, it may mean either that your
# process (or process group) is not allowed to write large files
# (resource limits) or that the file system (the network filesystem?)
# you are running the tests on doesn't let your user/group have large
# files (quota) or the filesystem simply doesn't support large files.
# You may even need to reconfigure your kernel.  (This is all very
# operating system and site-dependent.)
#
# Perl may still be able to support large files, once you have
# such a process, enough quota, and such a (file) system.
# It is just that the test failed now.
#
EOM
    
    print: $^STDOUT, "1..0 # Skip: $((join: ' ',@_))\n" if (nelems @_)


print: $^STDOUT, "# checking whether we have sparse files...\n"

# Known have-nots.
if ($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare' || $^OS_NAME eq 'VMS')
    print: $^STDOUT, "1..0 # Skip: no sparse files in $^OS_NAME\n"
    (bye: )


# Known haves that have problems running this test
# (for example because they do not support sparse files, like UNICOS)
if ($^OS_NAME eq 'unicos')
    print: $^STDOUT, "1..0 # Skip: no sparse files in $^OS_NAME, unable to test large files\n"
    (bye: )


# Then try heuristically to deduce whether we have sparse files.

# We'll start off by creating a one megabyte file which has
# only three "true" bytes.  If we have sparseness, we should
# consume less blocks than one megabyte (assuming nobody has
# one megabyte blocks...)

sysopen: $big_fh, "big1", O_WRONLY^|^O_CREAT^|^O_TRUNC or
    do { warn: "sysopen big1 failed: $^OS_ERROR\n"; bye: }
sysseek: $big_fh, 1_000_000, SEEK_SET or
    do { warn: "sysseek big1 failed: $^OS_ERROR\n"; bye: }
syswrite: $big_fh, "big" or
    do { warn: "syswrite big1 failed; $^OS_ERROR\n"; bye: }
close: $big_fh or
    do { warn: "close big1 failed: $^OS_ERROR\n"; bye: }

my @s1 = @:  stat: "big1" 

print: $^STDOUT, "# s1 = $((join: ' ',@s1))\n"

sysopen: $big_fh, "big2", O_WRONLY^|^O_CREAT^|^O_TRUNC or
    do { warn: "sysopen big2 failed: $^OS_ERROR\n"; bye: }
sysseek: $big_fh, 2_000_000, SEEK_SET or
    do { warn: "sysseek big2 failed: $^OS_ERROR\n"; bye: }
syswrite: $big_fh, "big" or
    do { warn: "syswrite big2 failed; $^OS_ERROR\n"; bye: }
close: $big_fh or
    do { warn: "close big2 failed: $^OS_ERROR\n"; bye: }

my @s2 = @:  stat: "big2" 

print: $^STDOUT, "# s2 = $((join: ' ',@s2))\n"

(zap: )

unless (@s1[7] == 1_000_003 && @s2[7] == 2_000_003 &&
    @s1[11] == @s2[11] && @s1[12] == @s2[12])
    print: $^STDOUT, "1..0 # Skip: no sparse files?\n"
    (bye: )


print: $^STDOUT, "# we seem to have sparse files...\n"

# By now we better be sure that we do have sparse files:
# if we are not, the following will hog 5 gigabytes of disk.  Ooops.
# This may fail by producing some signal; run in a subprocess first for safety

(env::var: 'LC_ALL' ) = "C"

my $r = system: '../perl', '-I../lib', '-e', <<'EOF'
use Fcntl qw(/^O_/ /^SEEK_/);
sysopen($big_fh, "big", O_WRONLY^|^O_CREAT^|^O_TRUNC) or die $!;
my $sysseek = sysseek($big_fh, 5_000_000_000, SEEK_SET);
my $syswrite = syswrite($big_fh, "big");
exit 0;
EOF

sysopen: $big_fh, "big", O_WRONLY^|^O_CREAT^|^O_TRUNC or
    do { warn: "sysopen 'big' failed: $^OS_ERROR\n"; bye: }
my $sysseek = sysseek: $big_fh, 5_000_000_000, SEEK_SET
unless (! $r && defined $sysseek && $sysseek == 5_000_000_000)
    $sysseek = 'undef' unless defined $sysseek
    explain: "seeking past 2GB failed: "
             $r ?? 'signal '.($r ^&^ 0x7f) !! "$^OS_ERROR (sysseek returned $sysseek)"
    (bye: )


# The syswrite will fail if there are are filesize limitations (process or fs).
my $syswrite = syswrite: $big_fh, "big"
print: $^STDOUT, "# syswrite failed: $^OS_ERROR (syswrite returned "
       defined $syswrite ?? $syswrite !! 'undef', ")\n"
    unless defined $syswrite && $syswrite == 3
my $close     = close $big_fh
print: $^STDOUT, "# close failed: $^OS_ERROR\n" unless $close
unless($syswrite && $close)
    if ($^OS_ERROR =~m/too large/i)
        explain: "writing past 2GB failed: process limits?"
    elsif ($^OS_ERROR =~ m/quota/i)
        explain: "filesystem quota limits?"
    else
        explain: "error: $^OS_ERROR"
    
    (bye: )


@s = @:  stat: "big" 

print: $^STDOUT, "# $((join: ' ',@s))\n"

unless (@s[7] == 5_000_000_003)
    explain: "kernel/fs not configured to use large files?"
    (bye: )


sub fail ()
    print: $^STDOUT, "not "
    $fail++


sub offset($offset_will_be, $offset_want)
    my $offset_is = eval $offset_will_be
    unless ($offset_is == $offset_want)
        print: $^STDOUT, "# bad offset $offset_is, want $offset_want\n"
        my (@: $offset_func) = @: $offset_will_be =~ m/^(\w+)/
        if ((unpack: "L", (pack: "L", $offset_want)) == $offset_is)
            print: $^STDOUT, "# 32-bit wraparound suspected in $offset_func() since\n"
            print: $^STDOUT, "# $offset_want cast into 32 bits equals $offset_is.\n"
        elsif ($offset_want - (unpack: "L", (pack: "L", $offset_want)) - 1
                   == $offset_is)
            print: $^STDOUT, "# 32-bit wraparound suspected in $offset_func() since\n"
            printf: $^STDOUT, q|# %s - unpack('L', pack('L', %s)) - 1 equals %s.| . "\n"
                    $offset_want
                    $offset_want
                    $offset_is
        
        (fail: )
    


print: $^STDOUT, "1..17\n"

$fail = 0

fail: unless @s[7] == 5_000_000_003	# exercizes pp_stat
print: $^STDOUT, "ok 1\n"

fail: unless -s "big" == 5_000_000_003	# exercizes pp_ftsize
print: $^STDOUT, "ok 2\n"

fail: unless -e "big"
print: $^STDOUT, "ok 3\n"

fail: unless -f "big"
print: $^STDOUT, "ok 4\n"

sysopen: $big_fh, "big", O_RDONLY or do { warn: "sysopen failed: $^OS_ERROR\n"; bye: }

offset: 'sysseek($big_fh, 4_500_000_000, SEEK_SET)', 4_500_000_000
print: $^STDOUT, "ok 5\n"

offset: 'sysseek($big_fh, 0, SEEK_CUR)', 4_500_000_000
print: $^STDOUT, "ok 6\n"

offset: 'sysseek($big_fh, 1, SEEK_CUR)', 4_500_000_001
print: $^STDOUT, "ok 7\n"

offset: 'sysseek($big_fh, 0, SEEK_CUR)', 4_500_000_001
print: $^STDOUT, "ok 8\n"

offset: 'sysseek($big_fh, -1, SEEK_CUR)', 4_500_000_000
print: $^STDOUT, "ok 9\n"

offset: 'sysseek($big_fh, 0, SEEK_CUR)', 4_500_000_000
print: $^STDOUT, "ok 10\n"

offset: 'sysseek($big_fh, -3, SEEK_END)', 5_000_000_000
print: $^STDOUT, "ok 11\n"

offset: 'sysseek($big_fh, 0, SEEK_CUR)', 5_000_000_000
print: $^STDOUT, "ok 12\n"

my $big

fail: unless (sysread: $big_fh, $big, 3) == 3
print: $^STDOUT, "ok 13\n"

fail: unless $big eq "big"
print: $^STDOUT, "ok 14\n"

# 705_032_704 = (I32)5_000_000_000
# See that we don't have "big" in the 705_... spot:
# that would mean that we have a wraparound.
fail: unless sysseek: $big_fh, 705_032_704, SEEK_SET
print: $^STDOUT, "ok 15\n"

my $zero

fail: unless (read: $big_fh, $zero, 3) == 3
print: $^STDOUT, "ok 16\n"

fail: unless $zero eq "\0\0\0"
print: $^STDOUT, "ok 17\n"

explain:  if $fail

(bye: ) # does the necessary cleanup

END 
    # unlink may fail if applied directly to a large file
    # be paranoid about leaving 5 gig files lying around
    open: $big_fh, ">", "big" # truncate
    close: $big_fh
    1 while unlink: "big" # standard portable idiom


# eof
