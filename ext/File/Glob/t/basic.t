#!./perl

BEGIN {
    require Config; Config->import;
    if (%Config{'extensions'} !~ m/\bFile\/Glob\b/i) {
        print "1..0\n";
        exit 0;
    }
}
use strict;
use Test::More tests => 14;
BEGIN {use_ok('File::Glob', ':glob')};
use Cwd ();

# look for the contents of the current directory
%ENV{PATH} = "/bin";
delete %ENV{[qw(BASH_ENV CDPATH ENV IFS)]};
my @correct = ();
if (opendir(D, $^O eq "MacOS" ? ":" : ".")) {
   @correct = grep { !m/^\./ } sort readdir(D);
   closedir D;
}
my @a = File::Glob::glob("*", 0);
@a = sort @a;
if (GLOB_ERROR) {
    fail(GLOB_ERROR);
} else {
    is_deeply(\@a, \@correct);
}

# look up the user's home directory
# should return a list with one item, and not set ERROR
SKIP: {
    my ($name, $home);
    skip $^O, 1 if $^O eq 'MSWin32' || $^O eq 'NetWare' || $^O eq 'VMS'
	|| $^O eq 'os2' || $^O eq 'beos';
    skip "Can't find user for $>: $@", 1 unless eval {
	($name, $home) = (getpwuid($>))[[0,7]];
	1;
    };
    skip "$> has no home directory", 1
	unless defined $home && defined $name && -d $home;

    @a = bsd_glob("~$name", GLOB_TILDE);

    if (GLOB_ERROR) {
	fail(GLOB_ERROR);
    } else {
	is_deeply (\@a, \@($home));
    }
}

# check backslashing
# should return a list with one item, and not set ERROR
@a = bsd_glob('TEST', GLOB_QUOTE);
if (GLOB_ERROR) {
    fail(GLOB_ERROR);
} else {
    is_deeply(\@a, \@('TEST'));
}

# check nonexistent checks
# should return an empty list
# XXX since errfunc is NULL on win32, this test is not valid there
@a = bsd_glob("asdfasdf", 0);
SKIP: {
    skip $^O, 1 if $^O eq 'MSWin32' || $^O eq 'NetWare';
    is_deeply(\@a, \@());
}

# check bad protections
# should return an empty list, and set ERROR
SKIP: {
    skip $^O, 2 if $^O eq 'mpeix' or $^O eq 'MSWin32' or $^O eq 'NetWare'
	or $^O eq 'os2' or $^O eq 'VMS' or $^O eq 'cygwin';
    skip "AFS", 2 if Cwd::cwd() =~ m#^%Config{'afsroot'}#s;
    skip "running as root", 2 if not $>;

    my $dir = "pteerslo";
    mkdir $dir, 0;
    @a = bsd_glob("$dir/*", GLOB_ERR);
    rmdir $dir;
    local $TODO = 'hit VOS bug posix-956' if $^O eq 'vos';

    isnt(GLOB_ERROR, 0);
    is_deeply(\@a, \@());
}

# check for csh style globbing
@a = bsd_glob('{a,b}', GLOB_BRACE ^|^ GLOB_NOMAGIC);
is_deeply(\@a, \@('a', 'b'));

@a = bsd_glob(
    '{TES?,doesntexist*,a,b}',
    GLOB_BRACE ^|^ GLOB_NOMAGIC ^|^ ($^O eq 'VMS' ? GLOB_NOCASE : 0)
);

# Working on t/TEST often causes this test to fail because it sees Emacs temp
# and RCS files.  Filter them out, and .pm files too, and patch temp files.
@a = grep !m/(,v$|~$|\.(pm|ori?g|rej)$)/, @a;
@a = (grep !m/test.pl/, @a) if $^O eq 'VMS';

print "# @a\n";

is_deeply(\@a, \@(($^O eq 'VMS'? 'test.' : 'TEST'), 'a', 'b'));

# "~" should expand to $ENV{HOME}
%ENV{HOME} = "sweet home";
@a = bsd_glob('~', GLOB_TILDE ^|^ GLOB_NOMAGIC);
SKIP: {
    skip $^O, 1 if $^O eq "MacOS";
    is_deeply(\@a, \@(%ENV{HOME}));
}

# GLOB_ALPHASORT (default) should sort alphabetically regardless of case
mkdir "pteerslo", 0777;
chdir "pteerslo";

my @f_names = sort qw(Ax.pl Bx.pl Cx.pl aY.pl bY.pl cY.pl);
my @f_alpha = qw(Ax.pl aY.pl Bx.pl bY.pl Cx.pl cY.pl);
if ($^O eq 'VMS') { # VMS is happily caseignorant
    @f_alpha = qw(ax.pl ay.pl bx.pl by.pl cx.pl cy.pl);
    @f_names = @f_alpha;
}

for (@f_names) {
    open T, ">", "$_";
    close T;
}

my $pat = "*.pl";

my @g_names = bsd_glob($pat, 0);
print "# f_names = @f_names\n";
print "# g_names = @g_names\n";
is_deeply(\@g_names, \@f_names);

my @g_alpha = bsd_glob($pat);
print "# f_alpha = @f_alpha\n";
print "# g_alpha = @g_alpha\n";
is_deeply(\@g_alpha, \@f_alpha);

unlink @f_names;
chdir "..";
rmdir "pteerslo";

# this can panic if PL_glob_index gets passed as flags to bsd_glob
glob("*"); glob("*");
pass("Don't panic");

{
    use File::Temp qw(tempdir);
    use File::Spec qw();

    my($dir) = tempdir(CLEANUP => 1)
	or die "Could not create temporary directory";
    for my $file (qw(a_dej a_ghj a_qej)) {
	open my $fh, ">", File::Spec->catfile($dir, $file)
	    or die "Could not create file $dir/$file: $!";
	close $fh;
    }
    my $cwd = Cwd::cwd();
    chdir $dir
	or die "Could not chdir to $dir: $!";
    my(@glob_files) = glob('a*{d[e]}j');
    local $TODO = "home-made glob doesn't do regexes" if $^O eq 'VMS';
    is_deeply(\@glob_files, \@('a_dej'));
    chdir $cwd
	or die "Could not chdir back to $cwd: $!";
}
