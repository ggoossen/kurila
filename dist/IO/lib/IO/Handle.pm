package IO::Handle

=head1 NAME

IO::Handle - supply object methods for I/O handles

=head1 SYNOPSIS

    use IO::Handle;

    $io = new IO::Handle;
    if ($io->fdopen(fileno(STDIN),"r")) {
        print $io->getline;
        $io->close;
    }

    $io = new IO::Handle;
    if ($io->fdopen(fileno(STDOUT),"w")) {
        $io->print("Some text\n");
    }

    # setvbuf is not available by default on Perls 5.8.0 and later.
    use IO::Handle '_IOLBF';
    $io->setvbuf($buffer_var, _IOLBF, 1024);

    undef $io;       # automatically closes the file if it's open

    autoflush STDOUT 1;

=head1 DESCRIPTION

C<IO::Handle> is the base class for all other IO handle classes. It is
not intended that objects of C<IO::Handle> would be created directly,
but instead C<IO::Handle> is inherited from by several other classes
in the IO hierarchy.

If you are reading this documentation, looking for a replacement for
the C<FileHandle> package, then I suggest you read the documentation
for C<IO::File> too.

=head1 CONSTRUCTOR

=over 4

=item new ()

Creates a new C<IO::Handle> object.

=item new_from_fd ( FD, MODE )

Creates an C<IO::Handle> like C<new> does.
It requires two parameters, which are passed to the method C<fdopen>;
if the fdopen fails, the object is destroyed. Otherwise, it is returned
to the caller.

=back

=head1 METHODS

See L<perlfunc> for complete descriptions of each of the following
supported C<IO::Handle> methods, which are just front ends for the
corresponding built-in functions:

    $io->close
    $io->eof
    $io->fcntl( FUNCTION, SCALAR )
    $io->fileno
    $io->getc
    $io->ioctl( FUNCTION, SCALAR )
    $io->read ( BUF, LEN, [OFFSET] )
    $io->print ( ARGS )
    $io->printf ( FMT, [ARGS] )
    $io->stat
    $io->sysread ( BUF, LEN, [OFFSET] )
    $io->syswrite ( BUF, [LEN, [OFFSET]] )
    $io->truncate ( LEN )

See L<perlvar> for complete descriptions of each of the following
supported C<IO::Handle> methods.  All of them return the previous
value of the attribute and takes an optional single argument that when
given will set the value.  If no argument is given the previous value
is unchanged (except for $io->autoflush will actually turn ON
autoflush by default).

    $io->autoflush ( [BOOL] )                         $|
    $io->input_line_number( [NUM])                    $.

The following methods are not supported on a per-filehandle basis.

    IO::Handle->output_field_separator( [STR] )       $,
    IO::Handle->output_record_separator( [STR] )      $\

    IO::Handle->input_record_separator( [STR] )       $/

Furthermore, for doing normal I/O you might need these:

=over 4

=item $io->fdopen ( FD, MODE )

C<fdopen> is like an ordinary C<open> except that its first parameter
is not a filename but rather a file handle name, an IO::Handle object,
or a file descriptor number.  (For the documentation of the C<open>
method, see L<IO::File>.)

=item $io->opened

Returns true if the object is currently a valid file descriptor, false
otherwise.

=item $io->getline

This works like <$io> described in L<perlop/"I/O Operators">
except that it's more readable and can be safely called in a
list context but still returns just one line.  If used as the conditional
+within a C<while> or C-style C<for> loop, however, you will need to
+emulate the functionality of <$io> with C<< defined($_ = $io->getline) >>.

=item $io->getlines

This works like <$io> when called in a list context to read all
the remaining lines in a file, except that it's more readable.
It will also die() if accidentally called in a scalar context.

=item $io->ungetc ( ORD )

Pushes a character with the given ordinal value back onto the given
handle's input stream.  Only one character of pushback per handle is
guaranteed.

=item $io->write ( BUF, LEN [, OFFSET ] )

This C<write> is like C<write> found in C, that is it is the
opposite of read.

=item $io->error

Returns a true value if the given handle has experienced any errors
since it was opened or since the last call to C<clearerr>, or if the
handle is invalid. It only returns false for a valid handle with no
outstanding errors.

=item $io->clearerr

Clear the given handle's error indicator. Returns -1 if the handle is
invalid, 0 otherwise.

=item $io->sync

C<sync> synchronizes a file's in-memory state  with  that  on the
physical medium. C<sync> does not operate at the perlio api level, but
operates on the file descriptor (similar to sysread, sysseek and
systell). This means that any data held at the perlio api level will not
be synchronized. To synchronize data that is buffered at the perlio api
level you must use the flush method. C<sync> is not implemented on all
platforms. Returns "0 but true" on success, C<undef> on error, C<undef>
for an invalid handle. See L<fsync(3c)>.

=item $io->flush

C<flush> causes perl to flush any buffered data at the perlio api level.
Any unread data in the buffer will be discarded, and any unwritten data
will be written to the underlying file descriptor. Returns "0 but true"
on success, C<undef> on error.

=item $io->printflush ( ARGS )

Turns on autoflush, print ARGS and then restores the autoflush status of the
C<IO::Handle> object. Returns the return value from print.

=item $io->blocking ( [ BOOL ] )

If called with an argument C<blocking> will turn on non-blocking IO if
C<BOOL> is false, and turn it off if C<BOOL> is true.

C<blocking> will return the value of the previous setting, or the
current setting if C<BOOL> is not given.

If an error occurs C<blocking> will return undef and C<$!> will be set.

=back


If the C functions setbuf() and/or setvbuf() are available, then
C<IO::Handle::setbuf> and C<IO::Handle::setvbuf> set the buffering
policy for an IO::Handle.  The calling sequences for the Perl functions
are the same as their C counterparts--including the constants C<_IOFBF>,
C<_IOLBF>, and C<_IONBF> for setvbuf()--except that the buffer parameter
specifies a scalar variable to use as a buffer. You should only
change the buffer before any I/O, or immediately after calling flush.

WARNING: The IO::Handle::setvbuf() is not available by default on
Perls 5.8.0 and later because setvbuf() is rather specific to using
the stdio library, while Perl prefers the new perlio subsystem instead.

WARNING: A variable used as a buffer by C<setbuf> or C<setvbuf> B<must not
be modified> in any way until the IO::Handle is closed or C<setbuf> or
C<setvbuf> is called again, or memory corruption may result! Remember that
the order of global destruction is undefined, so even if your buffer
variable remains in scope until program termination, it may be undefined
before the file IO::Handle is closed. Note that you need to import the
constants C<_IOFBF>, C<_IOLBF>, and C<_IONBF> explicitly. Like C, setbuf
returns nothing. setvbuf returns "0 but true", on success, C<undef> on
failure.

Lastly, there is a special method for working under B<-T> and setuid/gid
scripts:

=over 4

=item $io->untaint

Marks the object as taint-clean, and as such data read from it will also
be considered taint-clean. Note that this is a very trusting action to
take, and appropriate consideration for the data source and potential
vulnerability should be kept in mind. Returns 0 on success, -1 if setting
the taint-clean flag failed. (eg invalid handle)

=back

=head1 NOTE

An C<IO::Handle> object is a reference to a symbol/GLOB reference (see
the C<Symbol> package).  Some modules that
inherit from C<IO::Handle> may want to keep object related variables
in the hash table part of the GLOB. In an attempt to prevent modules
trampling on each other I propose the that any such module should prefix
its variables with its own name separated by _'s. For example the IO::Socket
module keeps a C<timeout> variable in 'io_socket_timeout'.

=head1 SEE ALSO

L<perlfunc>,
L<perlop/"I/O Operators">,
L<IO::File>

=head1 BUGS

Due to backwards compatibility, all filehandles resemble objects
of class C<IO::Handle>, or actually classes derived from that class.
They actually aren't.  Which means you can't derive your own
class from C<IO::Handle> and inherit those methods.

=head1 HISTORY

Derived from FileHandle.pm by Graham Barr E<lt>F<gbarr@pobox.com>E<gt>

=cut

our($VERSION, @EXPORT_OK, @ISA)
use Symbol
use IO ()	# Load the XS module

require Exporter
@ISA = qw(Exporter)

$VERSION = "1.27_01"
$VERSION = eval $VERSION

@EXPORT_OK = qw(
    autoflush
    output_field_separator
    output_record_separator
    input_record_separator
    input_line_number

    print
    printf
    getline
    getlines

    printflush
    flush

    SEEK_SET
    SEEK_CUR
    SEEK_END
    _IOFBF
    _IOLBF
    _IONBF
)

################################################
## Constructors, destructors.
##

sub new
    my $class = (ref: @_[0]) || @_[0] || "IO::Handle"
    (nelems @_) == 1 or die: "usage: new $class"
    my $io = (gensym: )
    bless: $io, $class


sub new_from_fd
    my $class = (ref: @_[0]) || @_[0] || "IO::Handle"
    (nelems @_) == 3 or die: "usage: new_from_fd $class FD, MODE"
    my $io = (gensym: )
    shift
    IO::Handle::fdopen: $io, < @_
        or return undef
    bless: $io, $class


################################################
## Open and close.
##

sub _open_mode_string($mode)
    $mode =~ m/^\+?(<|>>?)$/
        or $mode =~ s/^r(\+?)$/$1</
        or $mode =~ s/^w(\+?)$/$1>/
        or $mode =~ s/^a(\+?)$/$1>>/
        or die: "IO::Handle: bad open mode: $mode"
    $mode


sub fdopen($io, $fd, $mode)

    my $fdmode = '&'
    if (!(ref: $fd) && $fd =~ m#^\d+$#)
        # It's an FD number; prefix with "=".
        $fdmode .= "="
    

    open: $io, (_open_mode_string: $mode) . $fdmode, $fd
        ?? $io !! undef


sub close($io)
    close: $io


################################################
## Normal I/O functions.
##

# flock
# select

sub opened($io)
    defined fileno: $io


sub fileno($io)
    fileno: $io


sub getc($io)
    getc: $io


sub eof($io)
    eof: $io


sub print($this, @< @args)
    print: $this, < @args


sub printf($this, @< @args)
    printf: $this, < @args


sub getline($this)
    return scalar ~< $this


*gets = \&getline  # deprecated

sub getlines($this)
    return @:  ~< $this 


sub truncate($io, $len)
    truncate: $io, $len


sub read($io, $bufref, $len, ?$offset)
    read: $io, $bufref->$, $len, $offset || 0


sub sysread($io, $bufref, $len, ?$offset)
    sysread: $io, $bufref->$, $len, $offset || 0


sub write($io, $buf, ?$len, ?$offset)
    $len //= length: $buf
    print: $io, substr: $buf, $offset || 0, $len


sub syswrite($io, $buf, ?$len, ?$offset)
    if (defined: $len)
        syswrite: $io, $buf, $len, $offset || 0
    else
        syswrite: $io, $buf


sub stat($io)
    stat: @_[0]


################################################
## State modification functions.
##

sub autoflush($fh, @< @_)
    my $prev = iohandle::output_autoflush: $fh
    iohandle::output_autoflush: $fh, @_ ?? @_[0] !! 1
    return $prev


sub output_field_separator
    warn: "output_field_separator is not supported on a per-handle basis"
        if ref: @_[0]
    my $prev = $^OUTPUT_FIELD_SEPARATOR
    $^OUTPUT_FIELD_SEPARATOR = @_[1] if (nelems @_) +> 1
    $prev


sub input_record_separator(@< @_)
    warn: "input_record_separator is not supported on a per-handle basis"
        if ref: @_[0]
    my $prev = $^INPUT_RECORD_SEPARATOR
    $^INPUT_RECORD_SEPARATOR = @_[1] if (nelems @_) +> 1
    $prev


sub input_line_number
    ref: @_[0] or die: 'usage: $io->input_line_number'
    my $fh = qualify: @_[0], $: caller
    my $prev = iohandle::input_line_number: $fh
    iohandle::input_line_number: $fh, @_[1] if (nelems @_) +> 1
    return $prev


sub fcntl($io, $op, $value)
    return fcntl: $io, $op, $value


sub ioctl($io, $op, $value)
    return ioctl: $io, $op, $value


# this sub is for compatability with older releases of IO that used
# a sub called constant to detemine if a constant existed -- GMB
#
# The SEEK_* and _IO?BF constants were the only constants at that time
# any new code should just chech defined(&CONSTANT_NAME)

sub constant($name)
    (($name =~ m/^(SEEK_(SET|CUR|END)|_IO[FLN]BF)$/) && exists (Symbol::fetch_glob: $name)->*->&)
        ??( (Symbol::fetch_glob: $name)->*->& <: ) !! undef



sub printflush($io, @< @args)
    my $prev_autoflush = iohandle::output_autoflush: $io, 1
    print: $io, < @args
    iohandle::output_autoflush: $io, $prev_autoflush
    return


1
