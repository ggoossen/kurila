package Module::Build;

# This module doesn't do much of anything itself, it inherits from the
# modules that do the real work.  The only real thing it has to do is
# figure out which OS-specific module to pull in.  Many of the
# OS-specific modules don't do anything either - most of the work is
# done in Module::Build::Base.

use strict;
use File::Spec ();
use File::Path ();
use File::Basename ();

use Module::Build::Base;

use vars qw($VERSION @ISA);
@ISA = qw(Module::Build::Base);
$VERSION = '0.27_08';
$VERSION = eval $VERSION;

# Okay, this is the brute-force method of finding out what kind of
# platform we're on.  I don't know of a systematic way.  These values
# came from the latest (bleadperl) perlport.pod.

my %OSTYPES = qw(
		 aix       Unix
		 bsdos     Unix
		 dgux      Unix
		 dynixptx  Unix
		 freebsd   Unix
		 linux     Unix
		 hpux      Unix
		 irix      Unix
		 darwin    Unix
		 machten   Unix
		 next      Unix
		 openbsd   Unix
		 netbsd    Unix
		 dec_osf   Unix
		 svr4      Unix
		 svr5      Unix
		 sco_sv    Unix
		 unicos    Unix
		 unicosmk  Unix
		 solaris   Unix
		 sunos     Unix
		 cygwin    Unix
		 os2       Unix
		 
		 dos       Windows
		 MSWin32   Windows

		 os390     EBCDIC
		 os400     EBCDIC
		 posix-bc  EBCDIC
		 vmesa     EBCDIC

		 MacOS     MacOS
		 VMS       VMS
		 VOS       VOS
		 riscos    RiscOS
		 amigaos   Amiga
		 mpeix     MPEiX
		);

# Inserts the given module into the @ISA hierarchy between
# Module::Build and its immediate parent
sub _interpose_module {
  my ($self, $mod) = @_;
  eval "use $mod";
  die $@ if $@;

  no strict 'refs';
  my $top_class = $mod;
  while (@{"${top_class}::ISA"}) {
    last if ${"${top_class}::ISA"}[0] eq $ISA[0];
    $top_class = ${"${top_class}::ISA"}[0];
  }

  @{"${top_class}::ISA"} = @ISA;
  @ISA = ($mod);
}

if (grep {-e File::Spec->catfile($_, qw(Module Build Platform), $^O) . '.pm'} @INC) {
  __PACKAGE__->_interpose_module("Module::Build::Platform::$^O");

} elsif (exists $OSTYPES{$^O}) {
  __PACKAGE__->_interpose_module("Module::Build::Platform::$OSTYPES{$^O}");

} else {
  warn "Unknown OS type '$^O' - using default settings\n";
}

sub os_type { $OSTYPES{$^O} }

1;

__END__


=head1 NAME

Module::Build - Build and install Perl modules


=head1 SYNOPSIS

Standard process for building & installing modules:

  perl Build.PL
  ./Build
  ./Build test
  ./Build install

Or, if you're on a platform (like DOS or Windows) that doesn't require
the "./" notation, you can do this:

  perl Build.PL
  Build
  Build test
  Build install


=head1 DESCRIPTION

C<Module::Build> is a system for building, testing, and installing
Perl modules.  It is meant to be an alternative to
C<ExtUtils::MakeMaker>.  Developers may alter the behavior of the
module through subclassing in a much more straightforward way than
with C<MakeMaker>.  It also does not require a C<make> on your system
- most of the C<Module::Build> code is pure-perl and written in a very
cross-platform way.  In fact, you don't even need a shell, so even
platforms like MacOS (traditional) can use it fairly easily.  Its only
prerequisites are modules that are included with perl 5.6.0, and it
works fine on perl 5.005 if you can install a few additional modules.

See L<"MOTIVATIONS"> for more comparisons between C<ExtUtils::MakeMaker>
and C<Module::Build>.

To install C<Module::Build>, and any other module that uses
C<Module::Build> for its installation process, do the following:

  perl Build.PL       # 'Build.PL' script creates the 'Build' script
  ./Build             # Need ./ to ensure we're using this "Build" script
  ./Build test        # and not another one that happens to be in the PATH
  ./Build install

This illustrates initial configuration and the running of three
'actions'.  In this case the actions run are 'build' (the default
action), 'test', and 'install'.  Other actions defined so far include:

  build                          html        
  clean                          install     
  code                           manifest    
  config_data                    manpages    
  diff                           ppd         
  dist                           ppmdist     
  distcheck                      prereq_report
  distclean                      pure_install
  distdir                        realclean   
  distmeta                       skipcheck   
  distsign                       test        
  disttest                       testcover   
  docs                           testdb      
  fakeinstall                    testpod     
  help                           versioninstall


You can run the 'help' action for a complete list of actions.


=head1 GUIDE TO DOCUMENTATION

The documentation for C<Module::Build> is broken up into three sections:

=over

=item General Usage (L<Module::Build>)

This is the document you are currently reading. It describes basic
usage and background information.  Its main purpose is to assist the
user who wants to learn how to invoke and control C<Module::Build>
scripts at the command line.

=item Authoring Reference (L<Module::Build::Authoring>)

This document describes the C<Module::Build> API for authors who are
writing F<Build.PL> scripts for a distribution or controlling
C<Module::Build> processes programmatically.  It describes the
methods available as well as providing general information on
subclassing C<Module::Build> to alter and extend its behavior.  Also,
there is a section on controlling the Build process from other
scripts, including how to construct an object and how to invoke
actions through it from an external script.

=item Cookbook (L<Module::Build::Cookbook>)

This document demonstrates how to accomplish many common tasks.  It
covers general command line usage and authoring of F<Build.PL>
scripts.  Includes working examples.

=back


=head1 ACTIONS

There are some general principles at work here.  First, each task when
building a module is called an "action".  These actions are listed
above; they correspond to the building, testing, installing,
packaging, etc., tasks.

Second, arguments are processed in a very systematic way.  Arguments
are always key=value pairs.  They may be specified at C<perl Build.PL>
time (i.e. C<perl Build.PL destdir=/my/secret/place>), in which case
their values last for the lifetime of the C<Build> script.  They may
also be specified when executing a particular action (i.e.
C<Build test verbose=1>), in which case their values last only for the
lifetime of that command.  Per-action command line parameters take
precedence over parameters specified at C<perl Build.PL> time.

The build process also relies heavily on the C<Config.pm> module, and
all the key=value pairs in C<Config.pm> are available in

C<< $self->{config} >>.  If the user wishes to override any of the
values in C<Config.pm>, she may specify them like so:

  perl Build.PL --config cc=gcc --config ld=gcc

The following build actions are provided by default.

=over 4

=item build

If you run the C<Build> script without any arguments, it runs the
C<build> action, which in turn runs the C<code> and C<docs> actions.

This is analogous to the MakeMaker 'make all' target.

=item clean

This action will clean up any files that the build process may have
created, including the C<blib/> directory (but not including the
C<_build/> directory and the C<Build> script itself).

=item code

This action builds your codebase.

By default it just creates a C<blib/> directory and copies any C<.pm>
and C<.pod> files from your C<lib/> directory into the C<blib/>
directory.  It also compiles any C<.xs> files from C<lib/> and places
them in C<blib/>.  Of course, you need a working C compiler (probably
the same one that built perl itself) for the compilation to work
properly.

The C<code> action also runs any C<.PL> files in your F<lib/>
directory.  Typically these create other files, named the same but
without the C<.PL> ending.  For example, a file F<lib/Foo/Bar.pm.PL>
could create the file F<lib/Foo/Bar.pm>.  The C<.PL> files are
processed first, so any C<.pm> files (or other kinds that we deal
with) will get copied correctly.

=item config_data

...

=item diff

This action will compare the files about to be installed with their
installed counterparts.  For .pm and .pod files, a diff will be shown
(this currently requires a 'diff' program to be in your PATH).  For
other files like compiled binary files, we simply report whether they
differ.

A C<flags> parameter may be passed to the action, which will be passed
to the 'diff' program.  Consult your 'diff' documentation for the
parameters it will accept - a good one is C<-u>:

  ./Build diff flags=-u

=item dist

This action is helpful for module authors who want to package up their
module for source distribution through a medium like CPAN.  It will create a
tarball of the files listed in F<MANIFEST> and compress the tarball using
GZIP compression.

By default, this action will use the external C<tar> and C<gzip>
executables on Unix-like platforms, and the C<Archive::Tar> module
elsewhere.  However, you can force it to use whatever executable you
want by supplying an explicit C<tar> (and optional C<gzip>) parameter:

  ./Build dist --tar C:\path\to\tar.exe --gzip C:\path\to\zip.exe

=item distcheck

Reports which files are in the build directory but not in the
F<MANIFEST> file, and vice versa.  (See L<manifest> for details.)

=item distclean

Performs the 'realclean' action and then the 'distcheck' action.

=item distdir

Creates a "distribution directory" named C<$dist_name-$dist_version>
(if that directory already exists, it will be removed first), then
copies all the files listed in the F<MANIFEST> file to that directory.
This directory is what the distribution tarball is created from.

=item distmeta

Creates the F<META.yml> file that describes the distribution.

F<META.yml> is a file containing various bits of "metadata" about the
distribution.  The metadata includes the distribution name, version,
abstract, prerequisites, license, and various other data about the
distribution.  This file is created as F<META.yml> in YAML format, so
the C<YAML> module must be installed in order to create it.  The
F<META.yml> file must also be listed in F<MANIFEST> - if it's not, a
warning will be issued.

The current version of the F<META.yml> specification can be found at
L<http://module-build.sourceforge.net/META-spec-v1.2.html>

=item distsign

Uses C<Module::Signature> to create a SIGNATURE file for your
distribution, and adds the SIGNATURE file to the distribution's
MANIFEST.

=item disttest

Performs the 'distdir' action, then switches into that directory and
runs a C<perl Build.PL>, followed by the 'build' and 'test' actions in
that directory.

=item docs

This will generate documentation (e.g. Unix man pages and html
documents) for any installable items under B<blib/> that
contain POD.  If there are no C<bindoc> or C<libdoc> installation
targets defined (as will be the case on systems that don't support
Unix manpages) no action is taken for manpages.  If there are no
C<binhtml> or C<libhtml> installation targets defined no action is
taken for html documents.

=item fakeinstall

This is just like the C<install> action, but it won't actually do
anything, it will just report what it I<would> have done if you had
actually run the C<install> action.

=item help

This action will simply print out a message that is meant to help you
use the build process.  It will show you a list of available build
actions too.

With an optional argument specifying an action name (e.g. C<Build help
test>), the 'help' action will show you any POD documentation it can
find for that action.

=item html

This will generate HTML documentation for any binary or library files
under B<blib/> that contain POD.  The HTML documentation will only be
installed if the install paths can be determined from values in
C<Config.pm>.  You can also supply or override install paths on the
command line by specifying C<install_path> values for the C<binhtml>
and/or C<libhtml> installation targets.

=item install

This action will use C<ExtUtils::Install> to install the files from
C<blib/> into the system.  See L<INSTALL PATHS>
for details about how Module::Build determines where to install
things, and how to influence this process.

If you want the installation process to look around in C<@INC> for
other versions of the stuff you're installing and try to delete it,
you can use the C<uninst> parameter, which tells C<ExtUtils::Install> to
do so:

  ./Build install uninst=1

This can be a good idea, as it helps prevent multiple versions of a
module from being present on your system, which can be a confusing
situation indeed.

=item manifest

This is an action intended for use by module authors, not people
installing modules.  It will bring the F<MANIFEST> up to date with the
files currently present in the distribution.  You may use a
F<MANIFEST.SKIP> file to exclude certain files or directories from
inclusion in the F<MANIFEST>.  F<MANIFEST.SKIP> should contain a bunch
of regular expressions, one per line.  If a file in the distribution
directory matches any of the regular expressions, it won't be included
in the F<MANIFEST>.

The following is a reasonable F<MANIFEST.SKIP> starting point, you can
add your own stuff to it:

  ^_build
  ^Build$
  ^blib
  ~$
  \.bak$
  ^MANIFEST\.SKIP$
  CVS

See the L<distcheck> and L<skipcheck> actions if you want to find out
what the C<manifest> action would do, without actually doing anything.

=item manpages

This will generate man pages for any binary or library files under
B<blib/> that contain POD.  The man pages will only be installed if the
install paths can be determined from values in C<Config.pm>.  You can
also supply or override install paths by specifying there values on
the command line with the C<bindoc> and C<libdoc> installation
targets.

=item ppd

Build a PPD file for your distribution.

This action takes an optional argument C<codebase> which is used in
the generated ppd file to specify the (usually relative) URL of the
distribution.  By default, this value is the distribution name without
any path information.

Example:

  ./Build ppd --codebase "MSWin32-x86-multi-thread/Module-Build-0.21.tar.gz"

=item ppmdist

Generates a PPM binary distribution and a PPD description file.  This
action also invokes the 'ppd' action, so it can accept the same
C<codebase> argument described under that action.

This uses the same mechanism as the C<dist> action to tar & zip its
output, so you can supply C<tar> and/or C<gzip> parameters to affect
the result.

=item prereq_report

This action prints out a list of all prerequisites, the versions required, and
the versions actually installed.  This can be useful for reviewing the
configuration of your system prior to a build, or when compiling data to send
for a bug report.

=item pure_install

This action is identical to the C<install> action.  In the future,
though, if C<install> starts writing to the file file
F<$(INSTALLARCHLIB)/perllocal.pod>, C<pure_install> won't, and that
will be the only difference between them.

=item realclean

This action is just like the C<clean> action, but also removes the
C<_build> directory and the C<Build> script.  If you run the
C<realclean> action, you are essentially starting over, so you will
have to re-create the C<Build> script again.

=item skipcheck

Reports which files are skipped due to the entries in the
F<MANIFEST.SKIP> file (See L<manifest> for details)

=item test

This will use C<Test::Harness> to run any regression tests and report
their results.  Tests can be defined in the standard places: a file
called C<test.pl> in the top-level directory, or several files ending
with C<.t> in a C<t/> directory.

If you want tests to be 'verbose', i.e. show details of test execution
rather than just summary information, pass the argument C<verbose=1>.

If you want to run tests under the perl debugger, pass the argument
C<debugger=1>.

In addition, if a file called C<visual.pl> exists in the top-level
directory, this file will be executed as a Perl script and its output
will be shown to the user.  This is a good place to put speed tests or
other tests that don't use the C<Test::Harness> format for output.

To override the choice of tests to run, you may pass a C<test_files>
argument whose value is a whitespace-separated list of test scripts to
run.  This is especially useful in development, when you only want to
run a single test to see whether you've squashed a certain bug yet:

  ./Build test --test_files t/something_failing.t

You may also pass several C<test_files> arguments separately:

  ./Build test --test_files t/one.t --test_files t/two.t

or use a C<glob()>-style pattern:

  ./Build test --test_files 't/01-*.t'

=item testcover

Runs the C<test> action using C<Devel::Cover>, generating a
code-coverage report showing which parts of the code were actually
exercised during the tests.

To pass options to C<Devel::Cover>, set the C<$DEVEL_COVER_OPTIONS>
environment variable:

  DEVEL_COVER_OPTIONS=-ignore,Build ./Build testcover

=item testdb

This is a synonym for the 'test' action with the C<debugger=1>
argument.

=item testpod

This checks all the files described in the C<docs> action and 
produces C<Test::Harness>-style output.  If you are a module author,
this is useful to run before creating a new release.

=item versioninstall

** Note: since C<only.pm> is so new, and since we just recently added
support for it here too, this feature is to be considered
experimental. **

If you have the C<only.pm> module installed on your system, you can
use this action to install a module into the version-specific library
trees.  This means that you can have several versions of the same
module installed and C<use> a specific one like this:

  use only MyModule => 0.55;

To override the default installation libraries in C<only::config>,
specify the C<versionlib> parameter when you run the C<Build.PL> script:

  perl Build.PL --versionlib /my/version/place/

To override which version the module is installed as, specify the
C<versionlib> parameter when you run the C<Build.PL> script:

  perl Build.PL --version 0.50

See the C<only.pm> documentation for more information on
version-specific installs.

=back


=head1 OPTIONS

=head2 Command Line Options

The following options can be used during any invocation of C<Build.PL>
or the Build script, during any action.  For information on other
options specific to an action, see the documentation for the
respective action.

NOTE: There is some preliminary support for options to use the more
familiar long option style.  Most options can be preceded with the
C<--> long option prefix, and the underscores changed to dashes
(e.g. --use-rcfile).  Additionally, the argument to boolean options is
optional, and boolean options can be negated by prefixing them with
'no' or 'no-' (e.g. --noverbose or --no-verbose).

=over 4

=item quiet

Suppress informative messages on output.

=item use_rcfile

Load the F<~/.modulebuildrc> option file.  This option can be set to
false to prevent the custom resource file from being loaded.

=item verbose

Display extra information about the Build on output.

=back


=head2 Default Options File (F<.modulebuildrc>)

When Module::Build starts up, it will look for a file,
F<$ENV{HOME}/.modulebuildrc>.  If the file exists, the options
specified there will be used as defaults, as if they were typed on the
command line.  The defaults can be overridden by specifying new values
on the command line.

The action name must come at the beginning of the line, followed by any
amount of whitespace and then the options.  Options are given the same
as they would be on the command line.  They can be separated by any
amount of whitespace, including newlines, as long there is whitespace at
the beginning of each continued line.  Anything following a hash mark (C<#>)
is considered a comment, and is stripped before parsing.  If more than
one line begins with the same action name, those lines are merged into
one set of options.

Besides the regular actions, there are two special pseudo-actions: the
key C<*> (asterisk) denotes any global options that should be applied
to all actions, and the key 'Build_PL' specifies options to be applied
when you invoke C<perl Build.PL>.

  *        verbose=1   # global options
  diff     flags=-u
  install  --install_base /home/ken
           --install_path html=/home/ken/docs/html

If you wish to locate your resource file in a different location, you
can set the environment variable 'MODULEBUILDRC' to the complete
absolute path of the file containing your options.


=head1 INSTALL PATHS

When you invoke Module::Build's C<build> action, it needs to figure
out where to install things.  The nutshell version of how this works
is that default installation locations are determined from
F<Config.pm>, and they may be overridden by using the C<install_path>
parameter.  An C<install_base> parameter lets you specify an
alternative installation root like F</home/foo>, and a C<destdir> lets
you specify a temporary installation directory like F</tmp/install> in
case you want to create bundled-up installable packages.

Natively, Module::Build provides default installation locations for
the following types of installable items:

=over 4

=item lib

Usually pure-Perl module files ending in F<.pm>.

=item arch

"Architecture-dependent" module files, usually produced by compiling
XS, Inline, or similar code.

=item script

Programs written in pure Perl.  In order to improve reuse, try to make
these as small as possible - put the code into modules whenever
possible.

=item bin

"Architecture-dependent" executable programs, i.e. compiled C code or
something.  Pretty rare to see this in a perl distribution, but it
happens.

=item bindoc

Documentation for the stuff in C<script> and C<bin>.  Usually
generated from the POD in those files.  Under Unix, these are manual
pages belonging to the 'man1' category.

=item libdoc

Documentation for the stuff in C<lib> and C<arch>.  This is usually
generated from the POD in F<.pm> files.  Under Unix, these are manual
pages belonging to the 'man3' category.

=item binhtml

This is the same as C<bindoc> above, but applies to html documents.

=item libhtml

This is the same as C<bindoc> above, but applies to html documents.

=back

Four other parameters let you control various aspects of how
installation paths are determined:

=over 4

=item installdirs

The default destinations for these installable things come from
entries in your system's C<Config.pm>.  You can select from three
different sets of default locations by setting the C<installdirs>
parameter as follows:

                          'installdirs' set to:
                   core          site                vendor

              uses the following defaults from Config.pm:

  lib     => installprivlib  installsitelib      installvendorlib
  arch    => installarchlib  installsitearch     installvendorarch
  script  => installscript   installsitebin      installvendorbin
  bin     => installbin      installsitebin      installvendorbin
  bindoc  => installman1dir  installsiteman1dir  installvendorman1dir
  libdoc  => installman3dir  installsiteman3dir  installvendorman3dir
  binhtml => installhtml1dir installsitehtml1dir installvendorhtml1dir [*]
  libhtml => installhtml3dir installsitehtml3dir installvendorhtml3dir [*]

  * Under some OS (eg. MSWin32) the destination for html documents is
    determined by the C<Config.pm> entry C<installhtmldir>.

The default value of C<installdirs> is "site".  If you're creating
vendor distributions of module packages, you may want to do something
like this:

  perl Build.PL --installdirs vendor

or

  ./Build install --installdirs vendor

If you're installing an updated version of a module that was included
with perl itself (i.e. a "core module"), then you may set
C<installdirs> to "core" to overwrite the module in its present
location.

(Note that the 'script' line is different from MakeMaker -
unfortunately there's no such thing as "installsitescript" or
"installvendorscript" entry in C<Config.pm>, so we use the
"installsitebin" and "installvendorbin" entries to at least get the
general location right.  In the future, if C<Config.pm> adds some more
appropriate entries, we'll start using those.)

=item install_path

Once the defaults have been set, you can override them.

On the command line, that would look like this:

  perl Build.PL --install_path lib=/foo/lib --install_path arch=/foo/lib/arch

or this:

  ./Build install --install_path lib=/foo/lib --install_path arch=/foo/lib/arch

=item install_base

You can also set the whole bunch of installation paths by supplying the
C<install_base> parameter to point to a directory on your system.  For
instance, if you set C<install_base> to "/home/ken" on a Linux
system, you'll install as follows:

  lib     => /home/ken/lib/perl5
  arch    => /home/ken/lib/perl5/i386-linux
  script  => /home/ken/bin
  bin     => /home/ken/bin
  bindoc  => /home/ken/man/man1
  libdoc  => /home/ken/man/man3
  binhtml => /home/ken/html
  libhtml => /home/ken/html

Note that this is I<different> from how MakeMaker's C<PREFIX>
parameter works.  See L</"Why PREFIX is not recommended"> for more
details.  C<install_base> just gives you a default layout under the
directory you specify, which may have little to do with the
C<installdirs=site> layout.

The exact layout under the directory you specify may vary by system -
we try to do the "sensible" thing on each platform.

=item destdir

If you want to install everything into a temporary directory first
(for instance, if you want to create a directory tree that a package
manager like C<rpm> or C<dpkg> could create a package from), you can
use the C<destdir> parameter:

  perl Build.PL --destdir /tmp/foo

or

  ./Build install --destdir /tmp/foo

This will effectively install to "/tmp/foo/$sitelib",
"/tmp/foo/$sitearch", and the like, except that it will use
C<File::Spec> to make the pathnames work correctly on whatever
platform you're installing on.

=back

=head2 About PREFIX Support

First, it is necessary to understand the original idea behind
C<PREFIX>.  If, for example, the default installation locations for
your machine are F</usr/local/lib/perl5/5.8.5> for modules,
F</usr/local/bin> for executables, F</usr/local/man/man1> and
F</usr/local/man/man3> for manual pages, etc., then they all share the
same "prefix" F</usr/local>.  MakeMaker's C<PREFIX> mechanism was
intended as a way to change an existing prefix that happened to occur
in all those paths - essentially a C<< s{/usr/local}{/foo/bar} >> for
each path.

However, the real world is more complicated than that.  The C<PREFIX>
idea is fundamentally broken when your machine doesn't jibe with
C<PREFIX>'s worldview.


=over 4

=item Why PREFIX is not recommended

=over 4

=item *

Many systems have Perl configs that make little sense with PREFIX.
For example, OS X, where core modules go in
F</System/Library/Perl/...>, user-installed modules go in
F</Library/Perl/...>, and man pages go in F</usr/share/man/...>.  The
PREFIX is thus set to F</>.  Install L<Foo::Bar> on OS X with
C<PREFIX=/home/spurkis> and you get things like
F</home/spurkis/Library/Perl/5.8.1/Foo/Bar.pm> and
F</home/spurkis/usr/share/man/man3/Foo::Bar.3pm>.  Not too pretty.

The problem is not limited to Unix-like platforms, either - on Windows
builds (e.g. ActiveState perl 5.8.0), we have user-installed modules
going in F<C:\Perl\site\lib>, user-installed executables going in
F<C:\Perl\bin>, and PREFIX=F<C:\Perl\site>.  The prefix just doesn't
apply neatly to the executables.

=item *

The PREFIX logic is too complicated and hard to predict for the user.
It's hard to document what exactly is going to happen.  You can't give
a user simple instructions like "run perl Makefile.PL PREFIX=~ and
then set PERL5LIB=~/lib/perl5".

=item *

The results from PREFIX will change if your configuration of Perl
changes (for example, if you upgrade Perl).  This means your modules
will end up in different places.

=item *

The results from PREFIX can change with different releases of
MakeMaker.  The logic of PREFIX is subtle and it has been altered in
the past (mostly to limit damage in the many "edge cases" when its
behavior was undesirable).

=item *

PREFIX imposes decisions made by the person who configured Perl onto
the person installing a module.  The person who configured Perl could
have been you or it could have been some guy at Redhat.

=back


=item Alternatives to PREFIX

Module::Build offers L</install_base> as a simple, predictable, and
user-configurable alternative to ExtUtils::MakeMaker's C<PREFIX>.
What's more, MakeMaker will soon accept C<INSTALL_BASE> -- we strongly
urge you to make the switch.

Here's a quick comparison of the two when installing modules to your
home directory on a unix box:

MakeMaker [*]:

  % perl Makefile.PL PREFIX=/home/spurkis
  PERL5LIB=/home/spurkis/lib/perl5/5.8.5:/home/spurkis/lib/perl5/site_perl/5.8.5
  PATH=/home/spurkis/bin
  MANPATH=/home/spurkis/man

Module::Build:

  % perl Build.PL install_base=/home/spurkis
  PERL5LIB=/home/spurkis/lib/perl5
  PATH=/home/spurkis/bin
  MANPATH=/home/spurkis/man

[*] Note that MakeMaker's behaviour cannot be guaranteed in even this
common scenario, and differs among different versions of MakeMaker.

In short, using C<install_base> is similar to the following MakeMaker usage:

  perl Makefile.PL PREFIX=/home/spurkis LIB=/home/spurkis/lib/perl5

See L</INSTALL PATHS> for details on other
installation options available and how to configure them.

=back


=head1 MOTIVATIONS

There are several reasons I wanted to start over, and not just fix
what I didn't like about MakeMaker:

=over 4

=item *

I don't like the core idea of MakeMaker, namely that C<make> should be
involved in the build process.  Here are my reasons:

=over 4

=item +

When a person is installing a Perl module, what can you assume about
their environment?  Can you assume they have C<make>?  No, but you can
assume they have some version of Perl.

=item +

When a person is writing a Perl module for intended distribution, can
you assume that they know how to build a Makefile, so they can
customize their build process?  No, but you can assume they know Perl,
and could customize that way.

=back

For years, these things have been a barrier to people getting the
build/install process to do what they want.

=item *

There are several architectural decisions in MakeMaker that make it
very difficult to customize its behavior.  For instance, when using
MakeMaker you do C<use ExtUtils::MakeMaker>, but the object created in
C<WriteMakefile()> is actually blessed into a package name that's
created on the fly, so you can't simply subclass
C<ExtUtils::MakeMaker>.  There is a workaround C<MY> package that lets
you override certain MakeMaker methods, but only certain explicitly
preselected (by MakeMaker) methods can be overridden.  Also, the method
of customization is very crude: you have to modify a string containing
the Makefile text for the particular target.  Since these strings
aren't documented, and I<can't> be documented (they take on different
values depending on the platform, version of perl, version of
MakeMaker, etc.), you have no guarantee that your modifications will
work on someone else's machine or after an upgrade of MakeMaker or
perl.

=item *

It is risky to make major changes to MakeMaker, since it does so many
things, is so important, and generally works.  C<Module::Build> is an
entirely separate package so that I can work on it all I want, without
worrying about backward compatibility.

=item *

Finally, Perl is said to be a language for system administration.
Could it really be the case that Perl isn't up to the task of building
and installing software?  Even if that software is a bunch of stupid
little C<.pm> files that just need to be copied from one place to
another?  My sense was that we could design a system to accomplish
this in a flexible, extensible, and friendly manner.  Or die trying.

=back


=head1 TO DO

The current method of relying on time stamps to determine whether a
derived file is out of date isn't likely to scale well, since it
requires tracing all dependencies backward, it runs into problems on
NFS, and it's just generally flimsy.  It would be better to use an MD5
signature or the like, if available.  See C<cons> for an example.

 - append to perllocal.pod
 - add a 'plugin' functionality


=head1 AUTHOR

Ken Williams <kwilliams@cpan.org>

Development questions, bug reports, and patches should be sent to the
Module-Build mailing list at <module-build-general@lists.sourceforge.net>.

Bug reports are also welcome at
<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Module-Build>.

An anonymous CVS repository containing the latest development version
is available; see <http://sourceforge.net/cvs/?group_id=45731> for the
details of how to access it.


=head1 COPYRIGHT

Copyright (c) 2001-2005 Ken Williams.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 SEE ALSO

perl(1), Module::Build::Cookbook(3), Module::Build::Authoring(3),
ExtUtils::MakeMaker(3), YAML(3)

F<META.yml> Specification:
L<http://module-build.sourceforge.net/META-spec-v1.2.html>

L<http://www.dsmit.com/cons/>

=cut
