#!./miniperl

use warnings
use Config
use Cwd

# To clarify, this isn't the entire suite of modules considered "toolchain"
# It's not even all modules needed to build ext/
# It's just the source paths of the (minimum complete set of) modules in ext/
# needed to build the nonxs modules
# After which, all nonxs modules are in lib, which was always sufficient to
# allow miniperl to build everything else.

my @toolchain = qw(ext/constant/lib ext/ExtUtils-Command/lib
		   ext/ExtUtils-Install/lib ext/ExtUtils-MakeMaker/lib
		   ext/ExtUtils-Manifest/lib ext/Text-ParseWords/lib
       ext/File-Path/lib)

# This script acts as a simple interface for building extensions.

# It's actually a cut and shut of the Unix version ext/utils/makeext and the
# Windows version win32/build_ext.pl hence the two invocation styles.

# On Unix, it primarily used by the perl Makefile one extention at a time:
#
# d_dummy $(dynamic_ext): miniperl preplibrary FORCE
#       @$(RUN) ./miniperl make_ext.pl --target=dynamic $@ MAKE=$(MAKE) LIBPERL_A=$(LIBPERL)
#
# On Windows or VMS,
# If '--static' is specified, static extensions will be built.
# If '--dynamic' is specified, dynamic extensions will be built.
# If '--nonxs' is specified, nonxs extensions will be built.
# If '--all' is specified, all extensions will be built.
#
#    make_ext.pl "MAKE=make [-make_opts]" --dir=directory [--target=target] [--static|--dynamic|--all] +ext2 !ext1
#
# E.g.
# 
#     make_ext.pl "MAKE=nmake -nologo" --dir=..\ext
# 
#     make_ext.pl "MAKE=nmake -nologo" --dir=..\ext --target=clean
# 
#     make_ext.pl MAKE=dmake --dir=..\ext
# 
#     make_ext.pl MAKE=dmake --dir=..\ext --target=clean
# 
# Will skip building extensions which are marked with an '!' char.
# Mostly because they still not ported to specified platform.
# 
# If any extensions are listed with a '+' char then only those
# extensions will be built, but only if they arent countermanded
# by an '!ext' and are appropriate to the type of building being done.

# It may be deleted in a later release of perl so try to
# avoid using it for other purposes.

my $is_Win32 = $^OS_NAME eq 'MSWin32'
my $is_VMS = $^OS_NAME eq 'VMS'
my $is_Unix = !$is_Win32 && !$is_VMS

require FindExt if $is_Win32

my (%excl, %incl, %opts, @extspec, @pass_through)

foreach (@ARGV)
    if (m/^!(.*)$/)
        %excl{+$1} = 1
    elsif (m/^\+(.*)$/)
        %incl{+$1} = 1
    elsif (m/^--([\w\-]+)$/)
        %opts{+$1} = 1
    elsif (m/^--([\w\-]+)=(.*)$/)
        %opts{+$1} = $2
    elsif (m/^--([\w\-]+)=(.*)$/)
        %opts{+$1} = $2
    elsif (m/=/)
        push @pass_through, $_
    else
        push @extspec, $_

my $static = %opts{?static} || %opts{?all}
my $dynamic = %opts{?dynamic} || %opts{?all}
my $nonxs = %opts{?nonxs} || %opts{?all}

# The Perl Makefile.SH will expand all extensions to
#       lib/auto/X/X.a  (or lib/auto/X/Y/Y.a if nested)
# A user wishing to run make_ext might use
#       X (or X/Y or X::Y if nested)

# canonise into X/Y form (pname)

foreach (@extspec)
    if (s{^lib/auto/}{})
        # Remove lib/auto prefix and /*.* suffix
        s{/[^/]+\.[^/]+$}{}
    elsif (s{^ext/}{})
        # Remove ext/ prefix and /pm_to_blib suffix
        s{/pm_to_blib$}{}
        # Targets are given as files on disk, but the extension spec is still
        # written using /s for each ::
        s!-!/!
    elsif (s{::}{\/}g)
        # Convert :: to /
        1
    else
        s/\..*o//

my $makecmd  = shift @pass_through # Should be something like MAKE=make
unshift @pass_through, 'PERL_CORE=1'

my $dir  = %opts{?dir} || 'ext';
my $target   = %opts{?target} // 'all'

# Previously, $make was taken from config.sh.  However, the user might
# instead be running a possibly incompatible make.  This might happen if
# the user types "gmake" instead of a plain "make", for example.  The
# correct current value of MAKE will come through from the main perl
# makefile as MAKE=/whatever/make in $makecmd.  We'll be cautious in
# case third party users of this script (are there any?) don't have the
# MAKE=$(MAKE) argument, which was added after 5.004_03.
unless(defined $makecmd and $makecmd =~ m/^MAKE=(.*)$/)
    die "$^PROGRAM_NAME:  WARNING:  Please include MAKE=\$(MAKE) in \@ARGV\n"

# This isn't going to cope with anything fancy, such as spaces inside command
# names, but neither did what it replaced. Once there is a use case that needs
# it, please supply patches. Until then, I'm sticking to KISS
my @make = split ' ', $1 || config_value('make') || env::var('MAKE')
# Using an array of 0 or 1 elements makes the subsequent code simpler.
my @run = @: config_value('run')
@run = $@ if not defined @run[?0] or @run[0] eq '';


if ($target eq '')
    die "make_ext: no make target specified (eg all or clean)\n"
elsif ($target !~ m/(?:^all|clean)$/)
    # for the time being we are strict about what make_ext is used for
    die "$^PROGRAM_NAME: unknown make target '$target'\n"

if (!@extspec and !$static and !$dynamic and !$nonxs)
    die "$^PROGRAM_NAME: no extension specified\n"

my $perl
my %extra_passthrough

if ($is_Win32)
    (my $here = getcwd()) =~ s{/}{\\}g
    $perl = $^EXECUTABLE_NAME
    if ($perl =~ m#^\.\.#)
        $perl = "$here\\$perl"
    (my $topdir = $perl) =~ s/\\[^\\]+$//
    # miniperl needs to find perlglob and pl2bat
    env::var('PATH') = "$topdir;$topdir\\win32\\bin;$(env::var('PATH'))"
    my $pl2bat = "$topdir\\win32\\bin\\pl2bat"
    unless (-f "$pl2bat.bat")
        my @args = @: $perl, < (@: "$pl2bat.pl") x 2
        print $^STDOUT, "$(join ' ', @args)\n"
        system(< @args) unless defined $::Cross::platform

    print $^STDOUT, "In ", getcwd()
    chdir($dir) || die "Cannot cd to $dir\n"
    (my $ext = getcwd()) =~ s{/}{\\}g
    FindExt::scan_ext($ext)
    FindExt::set_static_extensions(split ' ', config_value('static_ext'))

    my @ext
    push @ext, < FindExt::static_ext() if $static
    push @ext, < FindExt::dynamic_ext() if $dynamic
    push @ext, < FindExt::nonxs_ext() if $nonxs

    foreach (sort @ext)
        if (%incl and !exists %incl{$_})
            #warn "Skipping extension $ext\\$_, not in inclusion list\n";
            next
        if (exists %excl{$_})
            warn "Skipping extension $ext\\$_, not ported to current platform"
            next
        push @extspec, $_
        if(FindExt::is_static($_))
            push %extra_passthrough{+$_}, 'LINKTYPE=static'

    chdir '..' # now in the Perl build directory
elsif ($is_VMS)
    $perl = $^EXECUTABLE_NAME
    push @extspec, (< split ' ', config_value('static_ext')) if $static
    push @extspec, (< split ' ', config_value('dynamic_ext')) if $dynamic
    push @extspec, (< split ' ', config_value('nonxs_ext')) if $nonxs

foreach my $spec (@extspec) 
    my $mname = $spec
    $mname =~ s!/!::!g
    my $ext_pathname;
    if (-d "ext/$spec")
        # Old style ext/Data/Dumper/
        $ext_pathname = "ext/$spec"
    else
        # New style ext/Data-Dumper/
        my $copy = $spec
        $copy =~ s!/!-!g
        $ext_pathname = "ext/$copy"

    if (config_value('osname') eq 'catamount')
        # Snowball's chance of building extensions.
        die "This is $(config_value('osname')), not building $mname, sorry.\n"

    print $^STDOUT, "\tMaking $mname ($target)\n"

    build_extension($ext_pathname, $perl, $mname,
                    @pass_through +@+ (%extra_passthrough{?$spec} || $@))

sub build_extension($ext_dir, $perl, $mname, $pass_through)
    my $up = $ext_dir
    $up =~ s![^/]+!..!g

    $perl ||= "$up/miniperl"
    my $return_dir = $up
    my $lib_dir = "$up/lib"
    # $lib_dir must be last, as we're copying files into it, and in a parallel
    # make there's a race condition if one process tries to open a module that
    # another process has half-written.
    env::var('PERL5LIB')
        = join config_value('path_sep'), map {"$up/$_"}, @: < @toolchain, $lib_dir

    unless (chdir "$ext_dir")
        warn "Cannot cd to $ext_dir: $^OS_ERROR"
        return

    my $makefile
    if ($is_VMS)
        $makefile = 'descrip.mms'
        if ($target =~ m/clean$/
            && !-f $makefile
            && -f "$($makefile)_old")
            $makefile = "$($makefile)_old"
    else
        $makefile = 'Makefile'
    
    if (!-f $makefile)
        if (!-f 'Makefile.PL')
            print $^STDOUT, "\nCreating Makefile.PL in $ext_dir for $mname\n"
            # We need to cope well with various possible layouts
            my @dirs = split m/::/, $mname
            my $leaf = pop @dirs
            my $leafname = "$leaf.pm"
            my $pathname = join '/', @dirs +@+ @: $leafname
            my @locations = @: $leafname, $pathname, "lib/$pathname"
            my $fromname
            foreach (@locations)
                if (-f $_)
                    $fromname = $_
                    last

            unless ($fromname)
                die "For $mname tried $(join ' ', @locations) in in $ext_dir but can't find source"

            open my $fh, '>', 'Makefile.PL'
                or die "Can't open Makefile.PL for writing: $^OS_ERROR"
            print $fh, <<"EOM"
#-*- buffer-read-only: t -*-

# This Makefile.PL was written by $^PROGRAM_NAME.
# It will be deleted automatically by make realclean

use ExtUtils::MakeMaker

WriteMakefile(
    NAME          => '$mname',
    VERSION_FROM  => '$fromname',
    ABSTRACT_FROM => '$fromname',
    realclean     => \%: FILES => 'Makefile.PL'
    );

# ex: set ro:
EOM
            close $fh or die "Can't close Makefile.PL: $^OS_ERROR"

        print $^STDOUT, "\nRunning Makefile.PL in $ext_dir\n"

        # Presumably this can be simplified
        my @cross
        if (defined $::Cross::platform)
            # Inherited from win32/buildext.pl
            @cross = "-MCross=$::Cross::platform"
        elsif (%opts{?cross})
            # Inherited from make_ext.pl
            @cross = '-MCross'
            
        my @args = @: < @cross, 'Makefile.PL'
        if ($is_VMS)
            my $libd = VMS::Filespec::vmspath($lib_dir)
            push @args, "INST_LIB=$libd", "INST_ARCHLIB=$libd"
        else
            push @args, 'INSTALLDIRS=perl', 'INSTALLMAN1DIR=none',
                'INSTALLMAN3DIR=none'
        push @args, < $pass_through
        _quote_args(\@args) if $is_VMS
        print $^STDOUT, join(' ', @: < @run, $perl, < @args), "\n"
        my $code = system < @run, $perl, < @args
        warn "$code from $ext_dir\'s Makefile.PL" if $code

        # Right. The reason for this little hack is that we're sitting inside
        # a program run by ./miniperl, but there are tasks we need to perform
        # when the 'realclean', 'distclean' or 'veryclean' targets are run.
        # Unfortunately, they can be run *after* 'clean', which deletes
        # ./miniperl
        # So we do our best to leave a set of instructions identical to what
        # we would do if we are run directly as 'realclean' etc
        # Whilst we're perfect, unfortunately the targets we call are not, as
        # some of them rely on a $(PERL) for their own distclean targets.
        # But this always used to be a problem with the old /bin/sh version of
        # this.
        if ($is_Unix)
            my $suffix = '.sh'
            foreach my $clean_target (@: 'realclean', 'veryclean')
                my $file = "$return_dir/$clean_target$suffix"
                open my $fh, '>>', $file or die "open $file: $^OS_ERROR"
                # Quite possible that we're being run in parallel here.
                # Can't use Fcntl this early to get the LOCK_EX
                flock $fh, 2 or warn "flock $file: $^OS_ERROR"
                print $fh, <<"EOS"
cd $ext_dir
if test ! -f Makefile -a -f Makefile.old; then
    echo "Note: Using Makefile.old"
    make -f Makefile.old $clean_target MAKE='$(join ' ', @make)' $(join ' ', @pass_through)
else
    if test ! -f Makefile ; then
        echo "Warning: No Makefile!"
    fi
    make $clean_target MAKE='$(join ' ', @make)' $(join ' ', @pass_through)
fi
cd $return_dir
EOS
                close $fh or die "close $file: $^OS_ERROR"

    if (not -f $makefile)
        print $^STDOUT, "Warning: No Makefile!\n"

    if ($is_VMS)
        _macroify_passthrough(\$pass_through)
        unshift $pass_through, "/DESCRIPTION=$makefile"

    if (!$target or $target !~ m/clean$/)
        # Give makefile an opportunity to rewrite itself.
        # reassure users that life goes on...
        my @args = @: 'config', < $pass_through
        _quote_args(\@args) if $is_VMS
        system(< @run, < @make, < @args) and print $^STDOUT, "$(join ' ', @run +@+ @make +@+ @args) failed, continuing anyway...\n"

    my @targ = @: $target, < $pass_through
    _quote_args(\@targ) if $is_VMS
    print $^STDOUT, "Making $target in $ext_dir\n$(join ' ', @: < @run, < @make, < @targ)\n"
    my $code = system(< @run, < @make, < @targ)
    die "Unsuccessful make($ext_dir): code=$code" if $code != 0

    chdir $return_dir || die "Cannot cd to $return_dir: $^OS_ERROR"

sub _quote_args($args)

    # Do not quote qualifiers that begin with '/'.
    map { if (! m/^\//)
             $_ =~ s/\"/""/g     # escape C<"> by doubling
             $_ = q(").$_.q(")
        }, $args->@

sub _macroify_passthrough($passthrough)
    _quote_args($passthrough);
    my $macro = '/MACRO=(' . join(',',$passthrough->@) . ')';
    $passthrough->$ = @: $macro
