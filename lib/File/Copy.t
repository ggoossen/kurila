#!./perl -w

use Test::More

my $TB = Test::More->builder: 

plan: tests => 60

# We're going to override rename() later on but Perl has to see an override
# at compile time to honor it.
BEGIN { *CORE::GLOBAL::rename = sub (@< @_) { (CORE::rename: @_[0], @_[1]) }; }


use File::Copy
use Config


foreach my $code (@: "copy:", "copy: 'arg'", "copy: 'arg', 'arg', 'arg', 'arg'"
                     "move:", "move: 'arg'", "move: 'arg', 'arg', 'arg'"
    )
    eval $code
    like: $^EVAL_ERROR->message, qr/^Usage: |Not enough arguments|Too many arguments/
          "'$code' is a usage error"



for my $cross_partition_test (0..1)
    do
        # Simulate a cross-partition copy/move by forcing rename to
        # fail.
        no warnings 'redefine'
        *CORE::GLOBAL::rename = sub (@< @_) { 0 } if $cross_partition_test
    

    # First we create a file
    open: my $f, ">", "file-$^PID" or die: 
    binmode: $f # for DOSISH platforms, because test 3 copies to stdout
    printf: $f, "ok\n"
    close $f

    copy: "file-$^PID", "copy-$^PID"

    open: $f, "<", "copy-$^PID" or die: 
    my $foo = ~< $f->*
    close: $f

    is: -s "file-$^PID", -s "copy-$^PID", 'copy(fn, fn): files of the same size'

    is: $foo, "ok\n", 'copy(fn, fn): same contents'

    print: $^STDOUT, "# next test checks copying to STDOUT\n"
    binmode: $^STDOUT unless $^OS_NAME eq 'VMS' # Copy::copy works in binary mode
    # This outputs "ok" so its a test.
    copy: "copy-$^PID", $^STDOUT
    $TB->current_test++
    unlink: "copy-$^PID" or die: "unlink: $^OS_ERROR"

    open: $f, "<","file-$^PID"
    copy: \$f->*, "copy-$^PID"
    open: my $r, "<", "copy-$^PID" or die: "open copy-$^PID: $^OS_ERROR"; $foo = ~< $r->*; close: $r
    is: $foo, "ok\n", 'copy(*$f, fn): same contents'
    unlink: "copy-$^PID" or die: "unlink: $^OS_ERROR"

    open: $f, "<","file-$^PID"
    copy: \$f->*, "copy-$^PID"
    close: $f or die: "close: $^OS_ERROR"
    open: $r, "<", "copy-$^PID" or die: ; $foo = ~< $r->*; close: $r or die: "close: $^OS_ERROR"
    is: $foo, "ok\n", 'copy(\*$f, fn): same contents'
    unlink: "copy-$^PID" or die: "unlink: $^OS_ERROR"

    require IO::File
    my $fh = (IO::File->new: "copy-$^PID", ">") or die: "Cannot open copy-$^PID:$^OS_ERROR"
    binmode: $fh or die: 
    copy: "file-$^PID",$fh
    $fh->close or die: "close: $^OS_ERROR"
    open: $r, "<", "copy-$^PID" or die: ; $foo = ~< $r->*; close: $r
    is: $foo, "ok\n", 'copy(fn, io): same contents'
    unlink: "copy-$^PID" or die: "unlink: $^OS_ERROR"

    require IO::File
    my $fh = (IO::File->new: "copy-$^PID", ">") or die: "Cannot open copy-$^PID:$^OS_ERROR"
    binmode: $fh or die: 
    copy: "file-$^PID",$fh
    $fh->close
    open: $r, "<", "copy-$^PID" or die: ; $foo = ~< $r->*; close: $r
    is: $foo, "ok\n", 'copy(fn, fh): same contents'
    unlink: "file-$^PID" or die: "unlink: $^OS_ERROR"

    ok: !(move: "file-$^PID", "copy-$^PID"), "move on missing file"
    ok: -e "copy-$^PID",                '  target still there'

    # Doesn't really matter what time it is as long as its not now.
    my $time = 1000000000
    utime:  $time, $time, "copy-$^PID" 

    # Recheck the mtime rather than rely on utime in case we're on a
    # system where utime doesn't work or there's no mtime at all.
    # The destination file will reflect the same difficulties.
    my $mtime = (@: (stat: "copy-$^PID"))[9]

    ok: (move: "copy-$^PID", "file-$^PID"), 'move'
    ok: -e "file-$^PID",              '  destination exists'
    ok: !-e "copy-$^PID",              '  source does not'
    open: $r, "<", "file-$^PID" or die: ; $foo = ~< $r->*; close: $r
    is: $foo, "ok\n", 'contents preserved'

    :TODO do
        local $TODO = 'mtime only preserved on ODS-5 with POSIX dates and DECC$EFS_FILE_TIMESTAMPS enabled' if $^OS_NAME eq 'VMS'

        my $dest_mtime = (@: (stat: "file-$^PID"))[9]
        is: $dest_mtime, $mtime
            "mtime preserved by copy()".
               ($cross_partition_test ?? " while testing cross-partition" !! "")
    

    # trick: create lib/ if not exists - not needed in Perl core
    unless (-d 'lib') { mkdir: 'lib' or die: ; }
    copy: "file-$^PID", "lib"
    open: $r, "<", "lib/file-$^PID" or die: $^OS_ERROR; $foo = ~< $r->*; close: $r
    is: $foo, "ok\n", 'copy(fn, dir): same contents'
    unlink: "lib/file-$^PID" or die: "unlink: $^OS_ERROR"

    # Do it twice to ensure copying over the same file works.
    copy: "file-$^PID", "lib"
    open: $r, "<", "lib/file-$^PID" or die: ; $foo = ~< $r->*; close: $r
    is: $foo, "ok\n", 'copy over the same file works'
    unlink: "lib/file-$^PID" or die: "unlink: $^OS_ERROR"

    do
        my $warnings = ''
        local $^WARN_HOOK = sub (@< @_) { $warnings .= @_[0]->{?description} }
        ok: (copy: "file-$^PID", "file-$^PID"), 'copy(fn, fn) succeeds'

        like: $warnings, qr/are identical/, 'but warns'
        ok: -s "file-$^PID", 'contents preserved'
    

    move: "file-$^PID", "lib"
    open: $r, "<", "lib/file-$^PID" or die: "open lib/file-$^PID: $^OS_ERROR"; $foo = ~< $r->*; close: $r
    is: $foo, "ok\n", 'move(fn, dir): same contents'
    ok: !-e "file-$^PID", 'file moved indeed'
    unlink: "lib/file-$^PID" or die: "unlink: $^OS_ERROR"

    :SKIP do
        skip: "Testing symlinks", 3 unless config_value: "d_symlink"

        open: $f, ">", "file-$^PID" or die: $^OS_ERROR
        print: $f, "dummy content\n"
        close $f
        symlink: "file-$^PID", "symlink-$^PID" or die: $^OS_ERROR

        my $warnings = ''
        local $^WARN_HOOK = sub (@< @_) { $warnings .= @_[0]->{?description} }
        ok: !(copy: "file-$^PID", "symlink-$^PID"), 'copy to itself (via symlink) fails'

        like: $warnings, qr/are identical/, 'emits a warning'
        ok: !-z "file-$^PID"
            'rt.perl.org 5196: copying to itself would truncate the file'

        unlink: "symlink-$^PID"
        unlink: "file-$^PID"
    

    :SKIP do
        skip: "Testing hard links", 3
            if !(config_value: "d_link") or $^OS_NAME eq 'MSWin32' or $^OS_NAME eq 'cygwin'

        open: $f, ">", "file-$^PID" or die: $^OS_ERROR
        print: $f, "dummy content\n"
        close $f
        link: "file-$^PID", "hardlink-$^PID" or die: $^OS_ERROR

        my $warnings = ''
        local $^WARN_HOOK = sub (@< @_) { $warnings .= @_[0]->{?description} }
        ok: !(copy: "file-$^PID", "hardlink-$^PID"), 'copy to itself (via hardlink) fails'

        like: $warnings, qr/are identical/, 'emits a warning'
        ok: ! -z "file-$^PID"
            'rt.perl.org 5196: copying to itself would truncate the file'

        unlink: "hardlink-$^PID"
        unlink: "file-$^PID"

END 
    1 while unlink: "file-$^PID"
    1 while unlink: "lib/file-$^PID"
