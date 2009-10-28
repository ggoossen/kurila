# File/Copy.pm. Written in 1994 by Aaron Sherman <ajs@ajs.com>. This
# source code has been placed in the public domain by the author.
# Please be kind and preserve the documentation.
#
# Additions copyright 1996 by Charles Bailey.  Permission is granted
# to distribute the revised code under the same terms as Perl itself.

package File::Copy

use warnings
use File::Spec
use Config
our(@ISA, @EXPORT, @EXPORT_OK, $VERSION, $Too_Big, $Syscopy_is_copy)

# Note that this module implements only *part* of the API defined by
# the File/Copy.pm module of the File-Tools-2.0 package.  However, that
# package has not yet been updated to work with Perl 5.004, and so it
# would be a Bad Thing for the CPAN module to grab it and replace this
# module.  Therefore, we set this module's version higher than 2.0.
$VERSION = '2.11'

require Exporter
@ISA = qw(Exporter)
@EXPORT = qw(copy move)
@EXPORT_OK = qw(cp mv)

$Too_Big = 1024 * 1024 * 2

my $macfiles
if ($^OS_NAME eq 'MacOS')
    $macfiles = try { require Mac::MoreFiles }
    warn: 'Mac::MoreFiles could not be loaded; using non-native syscopy'
        if $^EVAL_ERROR && $^WARNING


sub _catname($from, $to)
    if (not exists &basename)
        require File::Basename
        File::Basename->import: 'basename'
    

    if ($^OS_NAME eq 'MacOS')
        # a partial dir name that's valid only in the cwd (e.g. 'tmp')
        $to = ':' . $to if $to !~ m/:/
    

    return File::Spec->catfile: $to,( basename: $from)


# _eq($from, $to) tells whether $from and $to are identical
# works for strings and references
sub _eq
    return @_[0] == @_[1] if ref @_[0] && ref @_[1]
    return @_[0] eq @_[1] if !ref @_[0] && !ref @_[1]
    return ""


sub copy
    die: "Usage: copy(FROM, TO [, BUFFERSIZE]) "
        unless((nelems @_) == 2 || (nelems @_) == 3)

    my $from = shift
    my $to = shift

    my $size
    if (@_)
        $size = (shift: @_) + 0
        croak: "Bad buffer size for copy: $size\n" unless $size +> 0

    my $from_a_handle = (ref: $from
                         ?? ((ref: $from) eq 'GLOB'
                             || UNIVERSAL::isa: $from, 'GLOB'
                             || (UNIVERSAL::isa: $from, 'IO::Handle'))
                         !! ((ref: \$from) eq 'GLOB'))
    my $to_a_handle =   (ref: $to
                         ?? ((ref: $to) eq 'GLOB'
                             || UNIVERSAL::isa: $to, 'GLOB'
                             || (UNIVERSAL::isa: $to, 'IO::Handle'))
                         !! ((ref: \$to) eq 'GLOB'))

    if ((_eq: $from, $to)) # works for references, too
        warn: "'$from' and '$to' are identical (not copied)"
        # The "copy" was a success as the source and destination contain
        # the same data.
        return 1
    

    if (( ((config_value: "d_symlink") && (config_value: "d_readlink"))
          || (config_value: "d_link"))
          && !($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'os2'))
        my @fs = @:  stat: $from 
        if ((nelems @fs))
            my @ts = @:  stat: $to 
            if ((nelems @ts) && @fs[0] == @ts[0] && @fs[1] == @ts[1])
                warn: "'$from' and '$to' are identical (not copied)"
                return 0
            
        
    

    if (!$from_a_handle && !$to_a_handle && -d $to && ! -d $from)
        $to = _catname: $from, $to
    

    if (exists &syscopy && !$Syscopy_is_copy
          && !$to_a_handle
          && !($from_a_handle && $^OS_NAME eq 'os2' )   # OS/2 cannot handle handles
          && !($from_a_handle && $^OS_NAME eq 'mpeix')  # and neither can MPE/iX.
          && !($from_a_handle && $^OS_NAME eq 'MSWin32')
          && !($from_a_handle && $^OS_NAME eq 'MacOS')
          && !($from_a_handle && $^OS_NAME eq 'NetWare')
        )
        my $copy_to = $to

        if ($^OS_NAME eq 'VMS' && -e $from)

            if (! -d $to && ! -d $from)

                # VMS has sticky defaults on extensions, which means that
                # if there is a null extension on the destination file, it
                # will inherit the extension of the source file
                # So add a '.' for a null extension.

                $copy_to = VMS::Filespec::vmsify: $to
                my (@: $vol, $dirs, $file) =  File::Spec->splitpath: $copy_to
                $file = $file . '.' unless ($file =~ m/(?<!\^)\./)
                $copy_to = File::Spec->catpath: $vol, $dirs, $file

                # Get rid of the old versions to be like UNIX
                1 while unlink: $copy_to

        return syscopy: $from, $copy_to

    my $closefrom = 0
    my $closeto = 0
    my ($status, $r, $buf)

    my $from_h
    my $to_h

    my $fail_open1 = sub (@< @_) { return 0; }
    my $fail_open2 =
        sub (@< @_)
        if ($closefrom)
            $status = $^OS_ERROR
            $^OS_ERROR = 0
            close $from_h
            $^OS_ERROR = $status unless $^OS_ERROR
        
        return ($fail_open1->& <: )
    
    # All of these contortions try to preserve error messages...
    my $fail_inner =
        sub (@< @_)
        if ($closeto)
            $status = $^OS_ERROR
            $^OS_ERROR = 0
            close $to_h
            $^OS_ERROR = $status unless $^OS_ERROR
        
        return ($fail_open2->& <: )
    

    if ($from_a_handle)
        $from_h = $from
    else
        $from = (_protect: $from) if $from =~ m/^\s/s
        open: $from_h, "<", "$from\0" or return ($fail_open1->& <: )
        binmode: $from_h or die: "($^OS_ERROR,$^EXTENDED_OS_ERROR)"
        $closefrom = 1
    

    if ($to_a_handle)
        $to_h = $to
    else
        $to = (_protect: $to) if $to =~ m/^\s/s
        open: $to_h,">", "$to\0" or return ($fail_open2->& <: )
        binmode: $to_h or die: "($^OS_ERROR,$^EXTENDED_OS_ERROR)"
        $closeto = 1
    

    if ((nelems @_))
        $size = (shift: @_) + 0
        die: "Bad buffer size for copy: $size\n" unless ($size +> 0)
    else
        $size = -s $from_h || 0
        $size = 1024 if ($size +< 512)
        $size = $Too_Big if ($size +> $Too_Big)
    

    $^OS_ERROR = 0
    while (1)
        my ($r, $w, $t)
        defined: ($r = (sysread: $from_h, $buf, $size))
            or return ($fail_inner->& <: )
        last unless $r
        $w = 0
        while ($w +< $r)
            $t = syswrite: $to_h, $buf, $r - $w, $w
                or return ($fail_inner->& <: )
            $w += $t
        
    

    (close: $to_h) || return ($fail_open2->& <: ) if $closeto
    (close: $from_h) || return ($fail_open1->& <: ) if $closefrom

    # Use this idiom to avoid uninitialized value warning.
    return 1


sub move
    die: "Usage: move(FROM, TO) " unless (nelems @_) == 2

    my(@: $from,$to) =  @_

    my($fromsz,$tosz1,$tomt1,$tosz2,$tomt2,$sts,$ossts)

    if (-d $to && ! -d $from)
        $to = _catname: $from, $to
    

    (@: $tosz1,$tomt1) =  (@: (stat: $to))[[@: 7,9]]
    $fromsz = -s $from
    if ($^OS_NAME eq 'os2' and defined $tosz1 and defined $fromsz)
        # will not rename with overwrite
        unlink: $to
    

    my $rename_to = $to
    if ($^OS_NAME eq 'VMS' && -e $from)

        if (! -d $to && ! -d $from)
            # VMS has sticky defaults on extensions, which means that
            # if there is a null extension on the destination file, it
            # will inherit the extension of the source file
            # So add a '.' for a null extension.

            $rename_to = VMS::Filespec::vmsify: $to
            my (@: $vol, $dirs, $file) =  File::Spec->splitpath: $rename_to
            $file = $file . '.' unless ($file =~ m/(?<!\^)\./)
            $rename_to = File::Spec->catpath: $vol, $dirs, $file

            # Get rid of the old versions to be like UNIX
            1 while unlink: $rename_to
        
    

    return 1 if rename: $from, $rename_to

    # Did rename return an error even though it succeeded, because $to
    # is on a remote NFS file system, and NFS lost the server's ack?
    return 1 if (defined: $fromsz) && !-e $from &&           # $from disappeared
        ((@: $tosz2,$tomt2) =  (@: (stat: $to))[[@:7,9]]) &&    # $to's there
        ((!defined $tosz1) ||                      #  not before or
         ($tosz1 != $tosz2 or $tomt1 != $tomt2)) &&  #   was changed
      $tosz2 == $fromsz                         # it's all there

    (@: $tosz1,$tomt1) =  (@: (stat: $to))[[@:7,9]]  # just in case rename did something

    do
        local $^EVAL_ERROR = undef
        try {
            copy: $from,$to or die: ;
            my(@: $atime, $mtime) =  (@: (stat: $from))[[8..9]];
            (utime: $atime, $mtime, $to);
            unlink: $from   or die: ;
            }
        return 1 unless $^EVAL_ERROR
    
    (@: $sts,$ossts) = @: $^OS_ERROR + 0, $^EXTENDED_OS_ERROR + 0

    (@: $tosz2,$tomt2, ...) = (@: < (@: (stat: $to))[[@:7,9]],0,0) if defined $tomt1
    unlink: $to if !(defined: $tomt1) or $tomt1 != $tomt2 or $tosz1 != $tosz2
    (@: $^OS_ERROR,$^EXTENDED_OS_ERROR) = @: $sts,$ossts
    return 0


*cp = \&copy
*mv = \&move


# &syscopy is an XSUB under OS/2
unless (exists &syscopy)
    if ($^OS_NAME eq 'VMS')
        *syscopy = \&rmscopy
    elsif ($^OS_NAME eq 'mpeix')
        *syscopy = sub (@< @_)
            return 0 unless (nelems @_) == 2
            # Use the MPE cp program in order to
            # preserve MPE file attributes.
            return (system: '/bin/cp', '-f', @_[0], @_[1]) == 0
        
    elsif ($^OS_NAME eq 'MSWin32' && exists &DynaLoader::boot_DynaLoader)
        # Win32::CopyFile() fill only work if we can load Win32.xs
        *syscopy = sub (@< @_)
            return 0 unless (nelems @_) == 2
            return Win32::CopyFile: < @_, 1
        
    elsif ($macfiles)
        *syscopy = sub (@< @_)
            my(@: $from, $to) =  @_
            my($dir, $toname)

            return 0 unless -e $from

            if ($to =~ m/(.*:)([^:]+):?$/)
                (@: $dir, $toname) = @: $1, $2
            else
                (@: $dir, $toname) = @: ":", $to
            

            unlink: $to
            Mac::MoreFiles::FSpFileCopy: $from, $dir, $toname, 1
        
    else
        $Syscopy_is_copy = 1
        *syscopy = \&copy
    


1

__END__

=head1 NAME

File::Copy - Copy files or filehandles

=head1 SYNOPSIS

        use File::Copy;

        copy("file1","file2") or die "Copy failed: $!";
        copy("Copy.pm",$^STDOUT);
        move("/dev1/fileA","/dev2/fileB");

        use File::Copy "cp";

        $n = FileHandle->new("/a/file","r");
        cp($n,"x");

=head1 DESCRIPTION

The File::Copy module provides two basic functions, C<copy> and
C<move>, which are useful for getting the contents of a file from
one place to another.

=over 4

=item copy
X<copy> X<cp>

The C<copy> function takes two
parameters: a file to copy from and a file to copy to. Either
argument may be a string, a FileHandle reference or a FileHandle
glob. Obviously, if the first argument is a filehandle of some
sort, it will be read from, and if it is a file I<name> it will
be opened for reading. Likewise, the second argument will be
written to (and created if need be).  Trying to copy a file on top
of itself is a fatal error.

B<Note that passing in
files as handles instead of names may lead to loss of information
on some operating systems; it is recommended that you use file
names whenever possible.>  Files are opened in binary mode where
applicable.  To get a consistent behaviour when copying from a
filehandle to a file, use C<binmode> on the filehandle.

An optional third parameter can be used to specify the buffer
size used for copying. This is the number of bytes from the
first file, that will be held in memory at any given time, before
being written to the second file. The default buffer size depends
upon the file, but will generally be the whole file (up to 2MB), or
1k for filehandles that do not reference files (eg. sockets).

You may use the syntax C<use File::Copy "cp"> to get at the
"cp" alias for this function. The syntax is I<exactly> the same.

As of version 2.13, on UNIX systems, "copy" will preserve permission
bits like the shell utility C<cp> would do.

=item move
X<move> X<mv> X<rename>

The C<move> function also takes two parameters: the current name
and the intended name of the file to be moved.  If the destination
already exists and is a directory, and the source is not a
directory, then the source file will be renamed into the directory
specified by the destination.

If possible, move() will simply rename the file.  Otherwise, it copies
the file to the new location and deletes the original.  If an error occurs
during this copy-and-delete process, you may be left with a (possibly partial)
copy of the file under the destination name.

You may use the "mv" alias for this function in the same way that
you may use the "cp" alias for C<copy>.

=item syscopy
X<syscopy>

File::Copy also provides the C<syscopy> routine, which copies the
file specified in the first parameter to the file specified in the
second parameter, preserving OS-specific attributes and file
structure.  For Unix systems, this is equivalent to the simple
C<copy> routine, which doesn't preserve OS-specific attributes.  For
VMS systems, this calls the C<rmscopy> routine (see below).  For OS/2
systems, this calls the C<syscopy> XSUB directly. For Win32 systems,
this calls C<Win32::CopyFile>.

On Mac OS (Classic), C<syscopy> calls C<Mac::MoreFiles::FSpFileCopy>,
if available.

B<Special behaviour if C<syscopy> is defined (OS/2, VMS and Win32)>:

If both arguments to C<copy> are not file handles,
then C<copy> will perform a "system copy" of
the input file to a new output file, in order to preserve file
attributes, indexed file structure, I<etc.>  The buffer size
parameter is ignored.  If either argument to C<copy> is a
handle to an opened file, then data is copied using Perl
operators, and no effort is made to preserve file attributes
or record structure.

The system copy routine may also be called directly under VMS and OS/2
as C<File::Copy::syscopy> (or under VMS as C<File::Copy::rmscopy>, which
is the routine that does the actual work for syscopy).

=item rmscopy($from,$to[,$date_flag])
X<rmscopy>

The first and second arguments may be strings, typeglobs, typeglob
references, or objects inheriting from IO::Handle;
they are used in all cases to obtain the
I<filespec> of the input and output files, respectively.  The
name and type of the input file are used as defaults for the
output file, if necessary.

A new version of the output file is always created, which
inherits the structure and RMS attributes of the input file,
except for owner and protections (and possibly timestamps;
see below).  All data from the input file is copied to the
output file; if either of the first two parameters to C<rmscopy>
is a file handle, its position is unchanged.  (Note that this
means a file handle pointing to the output file will be
associated with an old version of that file after C<rmscopy>
returns, not the newly created version.)

The third parameter is an integer flag, which tells C<rmscopy>
how to handle timestamps.  If it is E<lt> 0, none of the input file's
timestamps are propagated to the output file.  If it is E<gt> 0, then
it is interpreted as a bitmask: if bit 0 (the LSB) is set, then
timestamps other than the revision date are propagated; if bit 1
is set, the revision date is propagated.  If the third parameter
to C<rmscopy> is 0, then it behaves much like the DCL COPY command:
if the name or type of the output file was explicitly specified,
then no timestamps are propagated, but if they were taken implicitly
from the input filespec, then all timestamps other than the
revision date are propagated.  If this parameter is not supplied,
it defaults to 0.

Like C<copy>, C<rmscopy> returns 1 on success.  If an error occurs,
it sets C<$!>, deletes the output file, and returns 0.

=back

=head1 RETURN

All functions return 1 on success, 0 on failure.
$! will be set if an error was encountered.

=head1 NOTES

=over 4

=item *

On Mac OS (Classic), the path separator is ':', not '/', and the 
current directory is denoted as ':', not '.'. You should be careful 
about specifying relative pathnames. While a full path always begins 
with a volume name, a relative pathname should always begin with a 
':'.  If specifying a volume name only, a trailing ':' is required.

E.g.

  copy("file1", "tmp");        # creates the file 'tmp' in the current directory
  copy("file1", ":tmp:");      # creates :tmp:file1
  copy("file1", ":tmp");       # same as above
  copy("file1", "tmp");        # same as above, if 'tmp' is a directory (but don't do
                               # that, since it may cause confusion, see example #1)
  copy("file1", "tmp:file1");  # error, since 'tmp:' is not a volume
  copy("file1", ":tmp:file1"); # ok, partial path
  copy("file1", "DataHD:");    # creates DataHD:file1

  move("MacintoshHD:fileA", "DataHD:fileB"); # moves (doesn't copy) files from one
                                             # volume to another

=back

=head1 AUTHOR

File::Copy was written by Aaron Sherman I<E<lt>ajs@ajs.comE<gt>> in 1995,
and updated by Charles Bailey I<E<lt>bailey@newman.upenn.eduE<gt>> in 1996.

=cut

