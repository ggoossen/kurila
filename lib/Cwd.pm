package Cwd;
require 5.6.0;

=head1 NAME

Cwd - get pathname of current working directory

=head1 SYNOPSIS

    use Cwd;
    $dir = cwd;

    use Cwd;
    $dir = getcwd;

    use Cwd;
    $dir = fastcwd;

    use Cwd;
    $dir = fastgetcwd;

    use Cwd 'chdir';
    chdir "/tmp";
    print $ENV{'PWD'};

    use Cwd 'abs_path';	    # aka realpath()
    print abs_path($ENV{'PWD'});

    use Cwd 'fast_abs_path';
    print fast_abs_path($ENV{'PWD'});

=head1 DESCRIPTION

This module provides functions for determining the pathname of the
current working directory.  By default, it exports the functions
cwd(), getcwd(), fastcwd(), and fastgetcwd() into the caller's
namespace.  Each of these functions are called without arguments and
return the absolute path of the current working directory.  It is
recommended that cwd (or another *cwd() function) be used in I<all>
code to ensure portability.

The cwd() is the most natural and safe form for the current
architecture. For most systems it is identical to `pwd` (but without
the trailing line terminator).

The getcwd() function re-implements the getcwd(3) (or getwd(3)) functions
in Perl.

The fastcwd() function looks the same as getcwd(), but runs faster.
It's also more dangerous because it might conceivably chdir() you out
of a directory that it can't chdir() you back into.  If fastcwd
encounters a problem it will return undef but will probably leave you
in a different directory.  For a measure of extra security, if
everything appears to have worked, the fastcwd() function will check
that it leaves you in the same directory that it started in. If it has
changed it will C<die> with the message "Unstable directory path,
current directory changed unexpectedly". That should never happen.

The fastgetcwd() function is provided as a synonym for cwd().

The abs_path() function takes a single argument and returns the
absolute pathname for that argument.  It uses the same algorithm as
getcwd().  (Actually, getcwd() is abs_path("."))  Symbolic links and
relative-path components ("." and "..") are resolved to return the
canonical pathname, just like realpath(3).  This function is also
callable as realpath().

The fast_abs_path() function looks the same as abs_path() but runs
faster and, like fastcwd(), is more dangerous.

If you ask to override your chdir() built-in function, then your PWD
environment variable will be kept up to date.  (See
L<perlsub/Overriding Builtin Functions>.) Note that it will only be
kept up to date if all packages which use chdir import it from Cwd.

=head1 NOTES

=over 4

=item *

On Mac OS (Classic), the path separator is ':', not '/', and the 
current directory is denoted as ':', not '.'. To move up the directory 
tree, you will use '::' to move up one level, but ':::' and so on to 
move up the tree two or more levels (i.e. the equivalent to '../../..'
is '::::'). Generally, you should be careful about specifying relative pathnames. 
While a full path always begins with a volume name, a relative pathname 
should always begin with a ':'.  If specifying a volume name only, a 
trailing ':' is required.

Actually, on Mac OS, the C<getcwd()>, C<fastgetcwd()> and C<fastcwd()>
functions  are all aliases for the C<cwd()> function, which, on Mac OS,
calls `pwd`. Likewise, the C<abs_path()> function is an alias for
C<fast_abs_path()>.

=back

=cut

use strict;

use Carp;

our $VERSION = '2.05';

use base qw/ Exporter /;
our @EXPORT = qw(cwd getcwd fastcwd fastgetcwd);
our @EXPORT_OK = qw(chdir abs_path fast_abs_path realpath fast_realpath);

# sys_cwd may keep the builtin command

# All the functionality of this module may provided by builtins,
# there is no sense to process the rest of the file.
# The best choice may be to have this in BEGIN, but how to return from BEGIN?

if ($^O eq 'os2' && defined &sys_cwd && defined &sys_abspath) {
    local $^W = 0;
    *cwd		= \&sys_cwd;
    *getcwd		= \&cwd;
    *fastgetcwd		= \&cwd;
    *fastcwd		= \&cwd;
    *abs_path		= \&sys_abspath;
    *fast_abs_path	= \&abs_path;
    *realpath		= \&abs_path;
    *fast_realpath	= \&abs_path;
    return 1;
}

eval {
    require XSLoader;
    XSLoader::load('Cwd');
};

# The 'natural and safe form' for UNIX (pwd may be setuid root)

sub _backtick_pwd {
    my $cwd = `pwd`;
    # `pwd` may fail e.g. if the disk is full
    chomp($cwd) if defined $cwd;
    $cwd;
}

# Since some ports may predefine cwd internally (e.g., NT)
# we take care not to override an existing definition for cwd().

unless(defined &cwd) {
    # The pwd command is not available in some chroot(2)'ed environments
    if($^O eq 'MacOS' || grep { -x "$_/pwd" } split(':', $ENV{PATH})) {
	*cwd = \&_backtick_pwd;
    }
    else {
	*cwd = \&getcwd;
    }
}

# set a reasonable (and very safe) default for fastgetcwd, in case it
# isn't redefined later (20001212 rspier)
*fastgetcwd = \&cwd;

# By Brandon S. Allbery
#
# Usage: $cwd = getcwd();

sub getcwd
{
    abs_path('.');
}

# Keeps track of current working directory in PWD environment var
# Usage:
#	use Cwd 'chdir';
#	chdir $newdir;

my $chdir_init = 0;

sub chdir_init {
    if ($ENV{'PWD'} and $^O ne 'os2' and $^O ne 'dos' and $^O ne 'MSWin32') {
	my($dd,$di) = stat('.');
	my($pd,$pi) = stat($ENV{'PWD'});
	if (!defined $dd or !defined $pd or $di != $pi or $dd != $pd) {
	    $ENV{'PWD'} = cwd();
	}
    }
    else {
	my $wd = cwd();
	$wd = Win32::GetFullPathName($wd) if $^O eq 'MSWin32';
	$ENV{'PWD'} = $wd;
    }
    # Strip an automounter prefix (where /tmp_mnt/foo/bar == /foo/bar)
    if ($^O ne 'MSWin32' and $ENV{'PWD'} =~ m|(/[^/]+(/[^/]+/[^/]+))(.*)|s) {
	my($pd,$pi) = stat($2);
	my($dd,$di) = stat($1);
	if (defined $pd and defined $dd and $di == $pi and $dd == $pd) {
	    $ENV{'PWD'}="$2$3";
	}
    }
    $chdir_init = 1;
}

sub chdir {
    my $newdir = @_ ? shift : '';	# allow for no arg (chdir to HOME dir)
    $newdir =~ s|///*|/|g unless $^O eq 'MSWin32';
    chdir_init() unless $chdir_init;
    my $newpwd;
    if ($^O eq 'MSWin32') {
	# get the full path name *before* the chdir()
	$newpwd = Win32::GetFullPathName($newdir);
    }

    return 0 unless CORE::chdir $newdir;

    if ($^O eq 'VMS') {
	return $ENV{'PWD'} = $ENV{'DEFAULT'}
    }
    elsif ($^O eq 'MacOS') {
	return $ENV{'PWD'} = cwd();
    }
    elsif ($^O eq 'MSWin32') {
	$ENV{'PWD'} = $newpwd;
	return 1;
    }

    if ($newdir =~ m#^/#s) {
	$ENV{'PWD'} = $newdir;
    } else {
	my @curdir = split(m#/#,$ENV{'PWD'});
	@curdir = ('') unless @curdir;
	my $component;
	foreach $component (split(m#/#, $newdir)) {
	    next if $component eq '.';
	    pop(@curdir),next if $component eq '..';
	    push(@curdir,$component);
	}
	$ENV{'PWD'} = join('/',@curdir) || '/';
    }
    1;
}

# added function alias for those of us more
# used to the libc function.  --tchrist 27-Jan-00
*realpath = \&abs_path;

sub fast_abs_path {
    my $cwd = getcwd();
    require File::Spec;
    my $path = @_ ? shift : File::Spec->curdir;
    CORE::chdir($path) || croak "Cannot chdir to $path:$!";
    my $realpath = getcwd();
    CORE::chdir($cwd)  || croak "Cannot chdir back to $cwd:$!";
    $realpath;
}

# added function alias to follow principle of least surprise
# based on previous aliasing.  --tchrist 27-Jan-00
*fast_realpath = \&fast_abs_path;


# --- PORTING SECTION ---

# VMS: $ENV{'DEFAULT'} points to default directory at all times
# 06-Mar-1996  Charles Bailey  bailey@newman.upenn.edu
# Note: Use of Cwd::chdir() causes the logical name PWD to be defined
#   in the process logical name table as the default device and directory
#   seen by Perl. This may not be the same as the default device
#   and directory seen by DCL after Perl exits, since the effects
#   the CRTL chdir() function persist only until Perl exits.

sub _vms_cwd {
    return $ENV{'DEFAULT'};
}

sub _vms_abs_path {
    return $ENV{'DEFAULT'} unless @_;
    my $path = VMS::Filespec::pathify($_[0]);
    croak("Invalid path name $_[0]") unless defined $path;
    return VMS::Filespec::rmsexpand($path);
}

sub _os2_cwd {
    $ENV{'PWD'} = `cmd /c cd`;
    chop $ENV{'PWD'};
    $ENV{'PWD'} =~ s:\\:/:g ;
    return $ENV{'PWD'};
}

sub _win32_cwd {
    $ENV{'PWD'} = Win32::GetCwd();
    $ENV{'PWD'} =~ s:\\:/:g ;
    return $ENV{'PWD'};
}

*_NT_cwd = \&_win32_cwd if (!defined &_NT_cwd && 
                            defined &Win32::GetCwd);

*_NT_cwd = \&_os2_cwd unless defined &_NT_cwd;

sub _dos_cwd {
    if (!defined &Dos::GetCwd) {
        $ENV{'PWD'} = `command /c cd`;
        chop $ENV{'PWD'};
        $ENV{'PWD'} =~ s:\\:/:g ;
    } else {
        $ENV{'PWD'} = Dos::GetCwd();
    }
    return $ENV{'PWD'};
}

sub _qnx_cwd {
    $ENV{'PWD'} = `/usr/bin/fullpath -t`;
    chop $ENV{'PWD'};
    return $ENV{'PWD'};
}

sub _qnx_abs_path {
    my $path = @_ ? shift : '.';
    my $realpath=`/usr/bin/fullpath -t $path`;
    chop $realpath;
    return $realpath;
}

sub _epoc_cwd {
    $ENV{'PWD'} = EPOC::getcwd();
    return $ENV{'PWD'};
}

{
    no warnings;	# assignments trigger 'subroutine redefined' warning

    if ($^O eq 'VMS') {
        *cwd		= \&_vms_cwd;
        *getcwd		= \&_vms_cwd;
        *fastcwd	= \&_vms_cwd;
        *fastgetcwd	= \&_vms_cwd;
        *abs_path	= \&_vms_abs_path;
        *fast_abs_path	= \&_vms_abs_path;
    }
    elsif ($^O eq 'NT' or $^O eq 'MSWin32') {
        # We assume that &_NT_cwd is defined as an XSUB or in the core.
        *cwd		= \&_NT_cwd;
        *getcwd		= \&_NT_cwd;
        *fastcwd	= \&_NT_cwd;
        *fastgetcwd	= \&_NT_cwd;
        *abs_path	= \&fast_abs_path;
    }
    elsif ($^O eq 'os2') {
        # sys_cwd may keep the builtin command
        *cwd		= defined &sys_cwd ? \&sys_cwd : \&_os2_cwd;
        *getcwd		= \&cwd;
        *fastgetcwd	= \&cwd;
        *fastcwd	= \&cwd;
        *abs_path	= \&fast_abs_path;
    }
    elsif ($^O eq 'dos') {
        *cwd		= \&_dos_cwd;
        *getcwd		= \&_dos_cwd;
        *fastgetcwd	= \&_dos_cwd;
        *fastcwd	= \&_dos_cwd;
        *abs_path	= \&fast_abs_path;
    }
    elsif ($^O =~ m/^(?:qnx|nto)$/ ) {
        *cwd		= \&_qnx_cwd;
        *getcwd		= \&_qnx_cwd;
        *fastgetcwd	= \&_qnx_cwd;
        *fastcwd	= \&_qnx_cwd;
        *abs_path	= \&_qnx_abs_path;
        *fast_abs_path	= \&_qnx_abs_path;
    }
    elsif ($^O eq 'cygwin') {
        *getcwd	= \&cwd;
        *fastgetcwd	= \&cwd;
        *fastcwd	= \&cwd;
        *abs_path	= \&fast_abs_path;
    }
    elsif ($^O eq 'epoc') {
        *cwd            = \&_epoc_cwd;
        *getcwd	        = \&_epoc_cwd;
        *fastgetcwd	= \&_epoc_cwd;
        *fastcwd	= \&_epoc_cwd;
        *abs_path	= \&fast_abs_path;
    }
    elsif ($^O eq 'MacOS') {
    	*getcwd     = \&cwd;
    	*fastgetcwd = \&cwd;
    	*fastcwd    = \&cwd;
    	*abs_path   = \&fast_abs_path;
    }
}

# package main; eval join('',<DATA>) || die $@;	# quick test

1;

__END__
BEGIN { import Cwd qw(:DEFAULT chdir); }
print join("\n", cwd, getcwd, fastcwd, "");
chdir('..');
print join("\n", cwd, getcwd, fastcwd, "");
print "$ENV{PWD}\n";
