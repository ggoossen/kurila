# NOTE: this file tests how large files (>2GB) work with perlio (stdio/sfio).
# sysopen(), sysseek(), syswrite(), sysread() are tested in t/lib/syslfs.t.
# If you modify/add tests here, remember to update also ext/Fcntl/t/syslfs.t.

use Config

BEGIN 
    # Don't bother if there are no quad offsets.
    if ((config_value: 'lseeksize') +< 8)
        print: $^STDOUT, "1..0 # Skip: no 64-bit file offsets\n"
        exit: 0
    


our @s
our $fail
my $big

sub zap
    close: $big
    unlink: "big"
    unlink: "big1"
    unlink: "big2"


sub bye
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


$^OUTPUT_AUTOFLUSH = 1

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


# Then try to heuristically deduce whether we have sparse files.

# Let's not depend on Fcntl or any other extension.

my (@: $SEEK_SET, $SEEK_CUR, $SEEK_END) = @: 0, 1, 2

# We'll start off by creating a one megabyte file which has
# only three "true" bytes.  If we have sparseness, we should
# consume less blocks than one megabyte (assuming nobody has
# one megabyte blocks...)

open: $big, ">", "big1" or
    do { warn: "open big1 failed: $^OS_ERROR\n"; bye: }
binmode: $big or
    do { warn: "binmode big1 failed: $^OS_ERROR\n"; bye: }
seek: $big, 1_000_000, $SEEK_SET or
    do { warn: "seek big1 failed: $^OS_ERROR\n"; bye: }
print: $big, "big" or
    do { warn: "print big1 failed: $^OS_ERROR\n"; bye: }
close: $big or
    do { warn: "close big1 failed: $^OS_ERROR\n"; bye: }

my @s1 = @:  stat: "big1" 

print: $^STDOUT, "# s1 = $((join: ' ',@s1))\n"

open: $big, ">", "big2" or
    do { warn: "open big2 failed: $^OS_ERROR\n"; bye: }
binmode: $big or
    do { warn: "binmode big2 failed: $^OS_ERROR\n"; bye: }
seek: $big, 2_000_000, $SEEK_SET or
    do { warn: "seek big2 failed; $^OS_ERROR\n"; bye: }
print: $big, "big" or
    do { warn: "print big2 failed; $^OS_ERROR\n"; bye: }
close: $big or
    do { warn: "close big2 failed; $^OS_ERROR\n"; bye: }

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

my $r = system: '../perl', '-e', <<'EOF'
open(my $big, ">", "big");
seek($big, 5_000_000_000, 0);
print $big, "big";
exit 0;
EOF

open: $big, ">", "big" or do { warn: "open failed: $^OS_ERROR\n"; bye: }
binmode: $big
if ($r or not (seek: $big, 5_000_000_000, $SEEK_SET))
    my $err = $r ?? 'signal '.($r ^&^ 0x7f) !! $^OS_ERROR
    explain: "seeking past 2GB failed: $err"
    (bye: )


# Either the print or (more likely, thanks to buffering) the close will
# fail if there are are filesize limitations (process or fs).
my $print = print: $big, "big"
print: $^STDOUT, "# print failed: $^OS_ERROR\n" unless $print
my $close = close $big
print: $^STDOUT, "# close failed: $^OS_ERROR\n" unless $close
unless ($print && $close)
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
            printf: $^STDOUT, "# \%s - unpack('L', pack('L', \%s)) - 1 equals \%s.\n"
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

open: $big, "<", "big" or do { warn: "open failed: $^OS_ERROR\n"; bye: }
binmode: $big

fail: unless seek: $big, 4_500_000_000, $SEEK_SET
print: $^STDOUT, "ok 5\n"

offset: 'tell($big)', 4_500_000_000
print: $^STDOUT, "ok 6\n"

fail: unless seek: $big, 1, $SEEK_CUR
print: $^STDOUT, "ok 7\n"

# If you get 205_032_705 from here it means that
# your tell() is returning 32-bit values since (I32)4_500_000_001
# is exactly 205_032_705.
offset: 'tell($big)', 4_500_000_001
print: $^STDOUT, "ok 8\n"

fail: unless seek: $big, -1, $SEEK_CUR
print: $^STDOUT, "ok 9\n"

offset: 'tell($big)', 4_500_000_000
print: $^STDOUT, "ok 10\n"

fail: unless seek: $big, -3, $SEEK_END
print: $^STDOUT, "ok 11\n"

offset: 'tell($big)', 5_000_000_000
print: $^STDOUT, "ok 12\n"

my $big_str

fail: unless (read: $big, $big_str, 3) == 3
print: $^STDOUT, "ok 13\n"

fail: unless $big_str eq "big"
print: $^STDOUT, "ok 14\n"

# 705_032_704 = (I32)5_000_000_000
# See that we don't have "big" in the 705_... spot:
# that would mean that we have a wraparound.
fail: unless seek: $big, 705_032_704, $SEEK_SET
print: $^STDOUT, "ok 15\n"

my $zero

fail: unless (read: $big, $zero, 3) == 3
print: $^STDOUT, "ok 16\n"

fail: unless $zero eq "\0\0\0"
print: $^STDOUT, "ok 17\n"

explain:  if $fail

(bye: ) # does the necessary cleanup

END 
    # unlink may fail if applied directly to a large file
    # be paranoid about leaving 5 gig files lying around
    open: $big, ">", "big" # truncate
    close: $big
    1 while unlink: "big" # standard portable idiom

# eof
