package ExtUtils::MM

use ExtUtils::MakeMaker::Config

our $VERSION = '6.44'

require ExtUtils::Liblist
require ExtUtils::MakeMaker
our @ISA = qw(ExtUtils::Liblist ExtUtils::MakeMaker)

=head1 NAME

ExtUtils::MM - OS adjusted ExtUtils::MakeMaker subclass

=head1 SYNOPSIS

  require ExtUtils::MM;
  my $mm = MM->new(...);

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY>

ExtUtils::MM is a subclass of ExtUtils::MakeMaker which automatically
chooses the appropriate OS specific subclass for you
(ie. ExtUils::MM_Unix, etc...).

It also provides a convenient alias via the MM class (I didn't want
MakeMaker modules outside of ExtUtils/).

This class might turn out to be a temporary solution, but MM won't go
away.

=cut

do
    # Convenient alias.
    package MM
    our @ISA = qw(ExtUtils::MM)
    sub DESTROY {}


sub _is_win95
    # miniperl might not have the Win32 functions available and we need
    # to run in miniperl.
    return exists &Win32::IsWin95 ??( Win32::IsWin95: )
        !! ! defined env::var: 'SYSTEMROOT'


my %Is = $%
%Is{+VMS}    = $^OS_NAME eq 'VMS'
%Is{+OS2}    = $^OS_NAME eq 'os2'
%Is{+MacOS}  = $^OS_NAME eq 'MacOS'
if( $^OS_NAME eq 'MSWin32' )
    ( (_is_win95: ) ?? %Is{+Win95} !! %Is{+Win32} ) = 1

%Is{+UWIN}   = $^OS_NAME =~ m/^uwin(-nt)?$/
%Is{+Cygwin} = $^OS_NAME eq 'cygwin'
%Is{+NW5}    = %Config{?osname} eq 'NetWare'  # intentional
%Is{+BeOS}   = $^OS_NAME =~ m/beos/i    # XXX should this be that loose?
%Is{+DOS}    = $^OS_NAME eq 'dos'
if( %Is{?NW5} )
    $^OS_NAME = 'NetWare'
    delete %Is{Win32}

%Is{+VOS}    = $^OS_NAME eq 'vos'
%Is{+QNX}    = $^OS_NAME eq 'qnx'
%Is{+AIX}    = $^OS_NAME eq 'aix'
%Is{+Darwin} = $^OS_NAME eq 'darwin'
%Is{+Haiku}  = $^OS_NAME eq 'haiku'

%Is{+Unix}   = !grep: { $_ }, values %Is

map: { delete %Is{$_} unless %Is{?$_} }, keys %Is
_assert:  (nelems: %Is) == 2 
my(@: $OS) =  keys %Is


my $class = "ExtUtils::MM_$OS"
eval "require $class" unless $^INCLUDED{?"ExtUtils/MM_$OS.pm"} ## no critic
die: $^EVAL_ERROR if $^EVAL_ERROR
unshift: @ISA, $class


sub _assert
    my $sanity = shift
    die: (sprintf: "Assert failed at \%s line \%d\n", < (@: caller)[[1..2]]) unless $sanity
    return
