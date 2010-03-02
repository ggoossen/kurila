#!perl

use File::Basename
use File::Spec

use Test::More
plan: tests => 8

use Pod::Functions

# How do you test exported vars?
my(@:  $pkg_ref, $exp_ref ) = @:  \%Pod::Functions::Kinds, \%Kinds 
is:  $pkg_ref, $exp_ref, '%Pod::Functions::Kinds exported' 

(@:  $pkg_ref, $exp_ref ) = @:  \%Pod::Functions::Type, \%Type 
is:  $pkg_ref, $exp_ref, '%Pod::Functions::Type exported' 

(@:  $pkg_ref, $exp_ref ) = @:  \%Pod::Functions::Flavor, \%Flavor 
is:  $pkg_ref, $exp_ref, '%Pod::Functions::Flavor exported' 

(@:  $pkg_ref, $exp_ref ) = @:  \%Pod::Functions::Type_Description
                                \%Type_Description 
is:  $pkg_ref, $exp_ref, '%Pod::Functions::Type_Description exported' 

(@:  $pkg_ref, $exp_ref ) = @:  \@Pod::Functions::Type_Order, \@Type_Order 
is:  $pkg_ref, $exp_ref, '@Pod::Functions::Type_Order exported' 

# Check @Type_Order
my @catagories = qw(
    String  Regexp Math ARRAY     LIST    HASH    I/O
    Binary  File   Flow Namespace Misc    Process Modules
    Objects Socket SysV User      Network Time
)

ok:  (eq_array:  \@Type_Order, \@catagories )
     '@Type_Order' 

my @cat_keys = grep: { exists %Type_Description{ $_ } }, @Type_Order

ok:  (eq_array:  \@cat_keys, \@catagories )
     'keys() %Type_Description' 

my(@:  _, $path, _ ) =  fileparse:  $^PROGRAM_NAME 
my $pod_functions = File::Spec->catfile: 
    $path, File::Spec->updir, 'Functions.pm' 

:SKIP do
    my $test_out = do { local $^INPUT_RECORD_SEPARATOR = undef; ~< $^DATA }

    skip:  "Can't fork '$^EXECUTABLE_NAME': $^OS_ERROR", 1
        unless open: my $fh, "-|", qq[$^EXECUTABLE_NAME "-I../lib" $pod_functions]
    my $fake_out = do { local $^INPUT_RECORD_SEPARATOR = undef; ~< $fh }
    skip:  "Pipe error: $^OS_ERROR", 1
        unless close $fh

    is:  $fake_out, $test_out, 'run as plain program' 


=head1 NAME

Functions.t - Test Pod::Functions

=head1 AUTHOR

20011229 Abe Timmerman <abe@ztreet.demon.nl>

=cut

__DATA__

Functions for SCALARs or strings:
     chomp, chop, chr, crypt, hex, index, lc, lcfirst, length,
     oct, ord, pack, q/STRING/, qq/STRING/, reverse, rindex,
     sprintf, substr, tr///, uc, ucfirst, y///

Regular expressions and pattern matching:
     m//, pos, qr/STRING/, quotemeta, s///, split, study

Numeric functions:
     abs, atan2, cos, exp, hex, int, log, oct, rand, sin, sqrt,
     srand

Functions for real @ARRAYs:
     pop, push, shift, splice, unshift

Functions for list data:
     grep, join, map, qw/STRING/, reverse, sort, unpack

Functions for real %HASHes:
     delete, each, exists, keys, values

Input and output functions:
     binmode, close, closedir, die, eof, fileno, flock, getc,
     print, printf, read, readdir, readline, rewinddir, seek,
     seekdir, select, syscall, sysread, sysseek, syswrite,
     tell, telldir, truncate, warn, write

Functions for fixed length data or records:
     pack, read, syscall, sysread, sysseek, syswrite, unpack,
     vec

Functions for filehandles, files, or directories:
     -X, chdir, chmod, chown, chroot, fcntl, glob, ioctl, link,
     lstat, mkdir, open, opendir, readlink, rename, rmdir,
     stat, symlink, sysopen, umask, unlink, utime

Keywords related to control flow of your perl program:
     caller, continue, die, do, dump, eval, exit, goto, last,
     next, prototype, redo, return, sub, wantarray

Keywords altering or affecting scoping of identifiers:
     caller, import, local, my, our, package, use

Miscellaneous functions:
     defined, dump, eval, local, my, our, prototype, reset,
     scalar, undef, wantarray

Functions for processes and process groups:
     alarm, exec, fork, getpgrp, getppid, getpriority, kill,
     pipe, qx/STRING/, readpipe, setpgrp, setpriority, sleep,
     system, times, wait, waitpid

Keywords related to perl modules:
     do, import, no, package, require, use

Keywords related to classes and object-orientedness:
     bless, package, ref, tie, tied, untie, use

Low-level socket functions:
     accept, bind, connect, getpeername, getsockname,
     getsockopt, listen, recv, send, setsockopt, shutdown,
     socket, socketpair

System V interprocess communication functions:
     msgctl, msgget, msgrcv, msgsnd, semctl, semget, semop,
     shmctl, shmget, shmread, shmwrite

Fetching user and group info:
     endgrent, endhostent, endnetent, endpwent, getgrent,
     getgrgid, getgrnam, getlogin, getpwent, getpwnam,
     getpwuid, setgrent, setpwent

Fetching network info:
     endprotoent, endservent, gethostbyaddr, gethostbyname,
     gethostent, getnetbyaddr, getnetbyname, getnetent,
     getprotobyname, getprotobynumber, getprotoent,
     getservbyname, getservbyport, getservent, sethostent,
     setnetent, setprotoent, setservent

Time-related functions:
     gmtime, localtime, time, times
