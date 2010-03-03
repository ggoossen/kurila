use ExtUtils::MakeMaker
use Config


our $VERSION = "1.10"

my %err = $%
my %wsa = $%

# Symbian cross-compiling environment.
my $IsSymbian = defined (env::var: "SDK") && -d "$((env::var: 'SDK'))\\epoc32"

my $IsMSWin32 = $^OS_NAME eq 'MSWin32' && !$IsSymbian

unlink: "Errno.pm" if -f "Errno.pm"
unlink: "Errno.tmp" if -f "Errno.tmp"
open: my $out, ">", "Errno.tmp" or die: "Cannot open Errno.tmp: $^OS_ERROR"
my @files = (get_files: )
if ((config_value: "gccversion") ne '' && $^OS_NAME eq 'MSWin32')
    # MinGW complains "warning: #pragma system_header ignored outside include
    # file" if the header files are processed individually, so include them
    # all in .c file and process that instead.
    open: my $incs, ">", 'includes.c' or
        die: "Cannot open includes.c"
    foreach my $file ( @files)
        next if $file eq 'errno.c'
        next unless -f $file
        print: $incs, qq[#include "$file"\n]
    
    close $incs
    process_file: 'includes.c'
    unlink: 'includes.c'
else
    foreach my $file ( @files)
        process_file: $file
    

(write_errno_pm: )
unlink: "errno.c" if -f "errno.c"
close $out or die: "Error closing Errno.tmp: $^OS_ERROR"
rename: "Errno.tmp", "Errno.pm" or die: "Cannot rename Errno.tmp to Errno.pm: $^OS_ERROR"

sub process_file($file)

    # for win32 perl under cygwin, we need to get a windows pathname
    if ($^OS_NAME eq 'MSWin32' && (config_value: "cc") =~ m/\B-mno-cygwin\b/ &&
        (defined: $file) && !-f $file)
        chomp: ($file = `cygpath -w "$file"`)
    

    return unless defined $file and -f $file
    #    warn "Processing $file\n";

    my $fh
    if (($^OS_NAME eq 'VMS') && ((config_value: "vms_cc_type") ne 'gnuc'))
        unless((open: $fh, "-|", "LIBRARY/EXTRACT=ERRNO/OUTPUT=SYS\$OUTPUT $file"))
            warn: "Cannot open '$file'"
            return
        
    elsif ((config_value: "gccversion") ne ''
               # OpenSTEP has gcc 2.7.2.1 which recognizes but
               # doesn't implement the -dM flag.
               && $^OS_NAME ne 'openstep' && $^OS_NAME ne 'next' && $^OS_NAME ne 'darwin'
        )
        # With the -dM option, gcc outputs every #define it finds
        unless((open: $fh,"-|","$((config_value: 'cc')) -E -dM $((config_value: 'cppflags')) $file"))
            warn: "Cannot open '$file'"
            return
        
    else
        unless((open: $fh, "<"," $file"))
            # This file could be a temporary file created by cppstdin
            # so only warn under -w, and return
            warn: "Cannot open '$file'" if $^WARNING
            return
        
    

    if ($^OS_NAME eq 'MacOS')
        while( ~< $fh)
            %err{+$1} = $2
                if m/^\s*#\s*define\s+(E\w+)\s+(\d+)/
        
    else
        while( ~< $fh)
            %err{+$1} = 1
                if m/^\s*#\s*define\s+(E\w+)\s+/
            if ($IsMSWin32)
                %wsa{+$1} = 1
                    if m/^\s*#\s*define\s+WSA(E\w+)\s+/
            
        
    

    close: $fh


my $cppstdin

sub default_cpp
    unless (defined $cppstdin)
        use File::Spec
        $cppstdin = config_value: "cppstdin"
        my $upup_cppstdin = File::Spec->catfile: File::Spec->updir
                                                 File::Spec->updir
                                                 "cppstdin"
        my $cppstdin_is_wrapper =
            ($cppstdin eq 'cppstdin'
               and -f $upup_cppstdin
             and -x $upup_cppstdin)
        $cppstdin = $upup_cppstdin if $cppstdin_is_wrapper
    
    return "$cppstdin $((config_value: 'cppflags')) $((config_value: 'cppminus'))"


sub get_files
    my %file = $%
    # VMS keeps its include files in system libraries (well, except for Gcc)
    if ($^OS_NAME eq 'VMS')
        if ($((config_value: 'vms_cc_type')) eq 'decc')
            %file{+'Sys$Library:DECC$RTLDEF.TLB'} = 1
        elsif ($((config_value: 'vms_cc_type')) eq 'vaxc')
            %file{+'Sys$Library:vaxcdef.tlb'} = 1
        elsif ($((config_value: 'vms_cc_type')) eq 'gcc')
            %file{+'gnu_cc_include:[000000]errno.h'} = 1
        
    elsif ($^OS_NAME eq 'os390')
        # OS/390 C compiler doesn't generate #file or #line directives
        %file{+'/usr/include/errno.h'} = 1
    elsif ($^OS_NAME eq 'vmesa')
        # OS/390 C compiler doesn't generate #file or #line directives
        %file{+'../../vmesa/errno.h'} = 1
    elsif ($((config_value: 'archname')) eq 'epoc')
        # Watch out for cross compiling for EPOC (usually done on linux)
        %file{+'/usr/local/epocemx/epocsdk/include/libc/sys/errno.h'} = 1
    elsif ($((config_value: 'archname')) eq 'arm-riscos')
        # Watch out for cross compiling for RISC OS
        my $dep = `echo "#include <errno.h>" | gcc -E -M -`
        if ($dep =~ m/(\S+errno\.h)/)
            %file{+$1} = 1
        
    elsif ($^OS_NAME eq 'linux' &&
        $((config_value: 'gccversion')) ne '' &&
        $((config_value: 'gccversion')) !~ m/intel/i
        # might be using, say, Intel's icc
        )
        # Some Linuxes have weird errno.hs which generate
        # no #file or #line directives
        my $linux_errno_h = -e '/usr/include/errno.h' ??
            '/usr/include/errno.h' !! '/usr/local/include/errno.h'
        %file{+$linux_errno_h} = 1
    elsif ($^OS_NAME eq 'MacOS')
        # note that we are only getting the GUSI errno's here ...
        # we might miss out on compiler-specific ones
        %file{+"$((env::var: 'GUSI'))include:sys:errno.h"} = 1

    elsif ($^OS_NAME eq 'beos' || $^OS_NAME eq 'haiku')
        # hidden in a special place
        %file{+'/boot/develop/headers/posix/errno.h'} = 1

    elsif ($^OS_NAME eq 'vos')
        # avoid problem where cpp returns non-POSIX pathnames
        %file{+'/system/include_library/errno.h'} = 1
    elsif ($IsSymbian)
        my $SDK = env::var: 'SDK'
        $SDK =~ s!\\!/!g
        %file{+"$SDK/epoc32/include/libc/sys/errno.h"} = 1
    else
        open: my $cppi, ">","errno.c" or
            die: "Cannot open errno.c"

        if ($^OS_NAME eq 'NetWare')
            print: $cppi, "#include <nwerrno.h>\n"
        else
            print: $cppi, "#include <errno.h>\n"
            if ($IsMSWin32)
                print: $cppi, "#define _WINSOCKAPI_\n" # don't drag in everything
                print: $cppi, "#include <winsock.h>\n"
            
        

        close: $cppi

        my $cppo
        # invoke CPP and read the output
        if ($IsMSWin32 || $^OS_NAME eq 'NetWare')
            open: $cppo,"-|","$((config_value: 'cpprun')) $((config_value: 'cppflags')) errno.c" or
                die: "Cannot run '$((config_value: 'cpprun')) $((config_value: 'cppflags')) errno.c'"
        else
            my $cpp = (default_cpp: )
            open: $cppo,"-|", "$cpp < errno.c" or
                die: "Cannot exec $cpp"
        

        my $pat
        if (($IsMSWin32 || $^OS_NAME eq 'NetWare') and (config_value: "cc") =~ m/^bcc/i)
            $pat = '^/\*\s+(.+)\s+\d+\s*:\s+\*/'
        else
            $pat = '^#\s*(?:line)?\s*\d+\s+"([^"]+)"'
        
        while( ~< $cppo)
            if ($^OS_NAME eq 'os2' or $IsMSWin32 or $^OS_NAME eq 'NetWare')
                if (m/$pat/o)
                    my $f = $1
                    $f =~ s,\\\\,/,g
                    %file{+$f} = 1
                
            else
                %file{+$1} = 1 if m/$pat/o
            
        
        close: $cppo
    
    return keys %file


sub write_errno_pm()

    # quick sanity check

    die: "No error definitions found" unless %err

    # create the CPP input

    open: my $cppi, ">","errno.c" or
        die: "Cannot open errno.c"

    if ($^OS_NAME eq 'NetWare')
        print: $cppi, "#include <nwerrno.h>\n"
    else
        print: $cppi, "#include <errno.h>\n"
    
    if ($IsMSWin32)
        print: $cppi, "#include <winsock.h>\n"
        foreach my $err (keys %wsa)
            print: $cppi, "#ifndef $err\n"
            print: $cppi, "#define $err WSA$err\n"
            print: $cppi, "#endif\n"
            %err{+$err} = 1

    foreach my $err (keys %err)
        print: $cppi, '"',$err,'" [[',$err,']]',"\n"

    close: $cppi

    unless ($^OS_NAME eq 'MacOS' || $^OS_NAME eq 'beos')        # trust what we have / get later
        # invoke CPP and read the output

        my $cppo
        if ($^OS_NAME eq 'VMS')
            my $cpp = "$((config_value: 'cppstdin')) $((config_value: 'cppflags')) $((config_value: 'cppminus'))"
            $cpp =~ s/sys\$input//i
            open: $cppo,"-|", "$cpp  errno.c" or
                die: "Cannot exec $((config_value: 'cppstdin'))"
        elsif ($IsMSWin32 || $^OS_NAME eq 'NetWare')
            open: $cppo,"-|", "$((config_value: 'cpprun')) $((config_value: 'cppflags')) errno.c" or
                die: "Cannot run '$((config_value: 'cpprun')) $((config_value: 'cppflags')) errno.c'"
        elsif ($IsSymbian)
            my $cpp = "gcc -E -I$((env::var: 'SDK'))\\epoc32\\include\\libc -"
            open: $cppo,"-|", "$cpp < errno.c"
                or die: "Cannot exec $cpp"
        else
            my $cpp = (default_cpp: )
            open: $cppo,"-|", "$cpp < errno.c"
                or die: "Cannot exec $cpp"
        

        %err = $%

        while( ~< $cppo)
            my($name,$expr)
            next unless (@: ?$name, ?$expr) = @: m/"(.*?)"\s*\[\s*\[\s*(.*?)\s*\]\s*\]/
            next if $name eq $expr
            $expr =~ s/\(?\([a-z_]\w*\)([^\)]*)\)?/$1/i # ((type)0xcafebabe) at alia
            $expr =~ s/((?:0x)?[0-9a-fA-F]+)[LU]+\b/$1/g # 2147483647L et alia
            next if $expr =~ m/^[a-zA-Z]+$/ # skip some Win32 functions
            if($expr =~ m/^0[xX]/)
                %err{+$name} = hex $expr
            else
                %err{+$name} = eval $expr
            
            delete %err{$name} unless defined %err{?$name}
        
        close: $cppo
    

    # Many of the E constants (including ENOENT, which is being
    # used in the Perl test suite a lot), are available only as
    # enums in BeOS, so compiling and executing some code is about
    # only way to find out what the numeric Evalues are. In fact above, we
    # didn't even bother to get the values of the ones that have numeric
    # values, since we can get all of them here, anyway.

    if ($^OS_NAME eq 'beos')
        if ((open: my $c, ">", "errno.c"))
            my @allerrs = keys %err
            print: $c ,<<EOF
#include <errno.h>
#include <stdio.h>
int main() \{
EOF
            for ( @allerrs)
                print: $c ,qq[printf("$_ \%d\n", $_);]
            
            print: $c ,"\}\n"
            close $c
            system: "cc -o errno errno.c"
            unlink: "errno.c"
            if ((open: $c, "-|", "./errno"))
                while ( ~< $c)
                    if (m/^(\w+) (-?\d+)$/) { %err{+$1} = $2 }
                
                close: $c
            else
                die: "failed to execute ./errno: $^OS_ERROR\n"
            
            unlink: "errno"
        else
            die: "failed to create errno.c: $^OS_ERROR\n"
        
    

    # Write Errno.pm

    print: $out, <<"EDQ"
#
# This file is auto-generated. ***ANY*** changes here will be lost
#

package Errno
our (\@EXPORT_OK,\%EXPORT_TAGS,\@ISA,\$VERSION,\%errno)
use Exporter ()
use Config

"\$(config_value: 'archname')-\$(config_value: 'osvers')" eq
    "$((config_value: 'archname'))-$((config_value: 'osvers'))" or
        die: "Errno architecture ($((config_value: 'archname'))-$((config_value: 'osvers'))) does not match executable architecture (\$(config_value: 'archname')-\$(config_value: 'osvers'))";

\$VERSION = "$VERSION";
\$VERSION = eval \$VERSION;
\@ISA = qw(Exporter);

EDQ

    my $len = 0
    my @err = sort: { %err{?$a} <+> %err{?$b} }, keys %err
    map: { $len = length if length +> $len }, @err

    my $j = "\@EXPORT_OK = qw(" . (join: " ",keys %err) . ");\n"
    $j =~ s/(.{50,70})\s/$1\n        /g
    print: $out, $j,"\n"

    print: $out, <<'ESQ'
%EXPORT_TAGS = %:
    POSIX => \qw(
ESQ

    my $k = join: " ", grep: { exists %err{$_} },
                                 qw(E2BIG EACCES EADDRINUSE EADDRNOTAVAIL EAFNOSUPPORT
        EAGAIN EALREADY EBADF EBUSY ECHILD ECONNABORTED
        ECONNREFUSED ECONNRESET EDEADLK EDESTADDRREQ EDOM EDQUOT
        EEXIST EFAULT EFBIG EHOSTDOWN EHOSTUNREACH EINPROGRESS
        EINTR EINVAL EIO EISCONN EISDIR ELOOP EMFILE EMLINK
        EMSGSIZE ENAMETOOLONG ENETDOWN ENETRESET ENETUNREACH
        ENFILE ENOBUFS ENODEV ENOENT ENOEXEC ENOLCK ENOMEM
        ENOPROTOOPT ENOSPC ENOSYS ENOTBLK ENOTCONN ENOTDIR
        ENOTEMPTY ENOTSOCK ENOTTY ENXIO EOPNOTSUPP EPERM
        EPFNOSUPPORT EPIPE EPROCLIM EPROTONOSUPPORT EPROTOTYPE
        ERANGE EREMOTE ERESTART EROFS ESHUTDOWN ESOCKTNOSUPPORT
        ESPIPE ESRCH ESTALE ETIMEDOUT ETOOMANYREFS ETXTBSY
        EUSERS EWOULDBLOCK EXDEV)

    $k =~ s/(.{50,70})\s/$1\n\t/g
    print: $out, "\t",$k,"\n    )\n\n\n"

    foreach my $err ( @err)
        printf: $out, "sub \%s () \{ \%d \}\n",$err,%err{?$err}

    print: $out, <<'ESQ'
my %name2no = %:
ESQ

    foreach my $err ( @err)
        printf: $out, "    \%s => \%d\n",$err,%err{?$err}

    print: $out, <<'ESQ'

1;
__END__

=head1 NAME

Errno - System errno constants

=head1 SYNOPSIS

    use Errno qw(EINTR EIO :POSIX);

=head1 DESCRIPTION

C<Errno> defines and conditionally exports all the error constants
defined in your system C<errno.h> include file. It has a single export
tag, C<:POSIX>, which will export all POSIX defined error numbers.

C<Errno> also makes C<%!> magic such that each element of C<%!> has a
non-zero value only if C<$!> is set to that value. For example:

    use Errno;

    unless (open(FH, "<", "/fangorn/spouse")) {
        if ($!{ENOENT}) {
            warn "Get a wife!\n";
        } else {
            warn "This path is barred: $!";
        } 
    } 

If a specified constant C<EFOO> does not exist on the system, C<$!{EFOO}>
returns C<"">.  You may use C<exists $!{EFOO}> to check whether the
constant is available on the system.

=head1 CAVEATS

Importing a particular constant may not be very portable, because the
import will fail on platforms that do not have that constant.  A more
portable way to set C<$!> to a valid value is to use:

    if (exists &Errno::EFOO) {
        $! = &Errno::EFOO;
    }

=head1 AUTHOR

Graham Barr <gbarr@pobox.com>

=head1 COPYRIGHT

Copyright (c) 1997-8 Graham Barr. All rights reserved.
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

ESQ


