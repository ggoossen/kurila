#!./perl

use Config

use Test::More tests => 14
BEGIN {(use_ok: 'File::Glob', ':glob')};
use Cwd ()

# look for the contents of the current directory
(env::var: 'PATH' ) = "/bin"
for (qw(BASH_ENV CDPATH ENV IFS))
    (env::var: $_) = undef
my @correct = $@
if ((opendir: my $d, $^OS_NAME eq "MacOS" ?? ":" !! "."))
    @correct = grep: { !m/^\./ }, sort: @:  readdir: $d
    closedir $d

my @a = File::Glob::bsd_glob: "*", 0
@a = sort: @a
if ((GLOB_ERROR: ))
    fail: (GLOB_ERROR: )
else
    is_deeply: \@a, \@correct


# look up the user's home directory
# should return a list with one item, and not set ERROR
:SKIP do
    my ($name, $home)
    skip: $^OS_NAME, 1 if $^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare' || $^OS_NAME eq 'VMS'
      || $^OS_NAME eq 'os2' || $^OS_NAME eq 'beos'
    skip: "Can't find user for $^EUID: $^EVAL_ERROR", 1 unless try {
        (@: $name, $home) =  (@: (getpwuid: $^EUID))[[@:0,7]];
        1;
    }
    skip: "$^EUID has no home directory", 1
        unless defined $home && defined $name && -d $home

    @a = bsd_glob: "~$name", GLOB_TILDE

    if ((GLOB_ERROR: ))
        fail: (GLOB_ERROR: )
    else
        is_deeply: \@a, \(@: $home)
    


# check backslashing
# should return a list with one item, and not set ERROR
@a = bsd_glob: 'TEST', GLOB_QUOTE
if ((GLOB_ERROR: ))
    fail: (GLOB_ERROR: )
else
    is_deeply: \@a, \(@: 'TEST')


# check nonexistent checks
# should return an empty list
# XXX since errfunc is NULL on win32, this test is not valid there
@a = bsd_glob: "asdfasdf", 0
:SKIP do
    skip: $^OS_NAME, 1 if $^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare'
    is_deeply: \@a, \$@


# check bad protections
# should return an empty list, and set ERROR
:SKIP do
    skip: $^OS_NAME, 2 if $^OS_NAME eq 'mpeix' or $^OS_NAME eq 'MSWin32' or $^OS_NAME eq 'NetWare'
      or $^OS_NAME eq 'os2' or $^OS_NAME eq 'VMS' or $^OS_NAME eq 'cygwin'
    skip: "AFS", 2 if (Cwd::cwd: ) =~ m#^$((config_value: 'afsroot'))#s
    skip: "running as root", 2 if not $^EUID

    my $dir = "pteerslo"
    mkdir: $dir, 0
    @a = bsd_glob: "$dir/*", GLOB_ERR
    rmdir $dir
    local $TODO = 'hit VOS bug posix-956' if $^OS_NAME eq 'vos'

    isnt: (GLOB_ERROR: ), 0
    is_deeply: \@a, \$@


# check for csh style globbing
@a = bsd_glob: '{a,b}', GLOB_BRACE ^|^ GLOB_NOMAGIC
is_deeply: \@a, \(@: 'a', 'b')

@a = bsd_glob: 
    '{TES?,doesntexist*,a,b}'
    GLOB_BRACE ^|^ GLOB_NOMAGIC ^|^ ($^OS_NAME eq 'VMS' ?? GLOB_NOCASE !! 0)
    

# Working on t/TEST often causes this test to fail because it sees Emacs temp
# and RCS files.  Filter them out, and .pm files too, and patch temp files.
@a = grep: { !m/(,v$|~$|\.(pm|ori?g|rej)$)/ }, @a
@a = (grep: { !m/test.pl/ }, @a) if $^OS_NAME eq 'VMS'

print: $^STDOUT, "# $((join: ' ',@a))\n"

is_deeply: \@a, \(@: ($^OS_NAME eq 'VMS'?? 'test.' !! 'TEST'), 'a', 'b')

# "~" should expand to $ENV{HOME}
(env::var: 'HOME' ) = "sweet home"
@a = bsd_glob: '~', GLOB_TILDE ^|^ GLOB_NOMAGIC
:SKIP do
    skip: $^OS_NAME, 1 if $^OS_NAME eq "MacOS"
    is_deeply: \@a, \(@: (env::var: 'HOME'))


# GLOB_ALPHASORT (default) should sort alphabetically regardless of case
mkdir: "pteerslo", 0777
chdir "pteerslo"

my @f_names = sort: qw(Ax.pl Bx.pl Cx.pl aY.pl bY.pl cY.pl)
my @f_alpha = qw(Ax.pl aY.pl Bx.pl bY.pl Cx.pl cY.pl)
if ($^OS_NAME eq 'VMS') # VMS is happily caseignorant
    @f_alpha = qw(ax.pl ay.pl bx.pl by.pl cx.pl cy.pl)
    @f_names = @f_alpha


for ( @f_names)
    open: my $t, ">", "$_"
    close $t


my $pat = "*.pl"

my @g_names = bsd_glob: $pat, 0
print: $^STDOUT, "# f_names = $((join: ' ',@f_names))\n"
print: $^STDOUT, "# g_names = $((join: ' ',@g_names))\n"
is_deeply: \@g_names, \@f_names

my @g_alpha = bsd_glob: $pat
print: $^STDOUT, "# f_alpha = $((join: ' ',@f_alpha))\n"
print: $^STDOUT, "# g_alpha = $((join: ' ',@g_alpha))\n"
is_deeply: \@g_alpha, \@f_alpha

unlink: < @f_names
chdir ".."
rmdir "pteerslo"

# this can panic if PL_glob_index gets passed as flags to bsd_glob
(glob: "*"; glob: "*"
pass: "Don't panic"

do
    use File::Temp < qw(tempdir)
    use File::Spec qw()

    my $dir = tempdir: CLEANUP => 1
        or die: "Could not create temporary directory"
    for my $file (qw(a_dej a_ghj a_qej))
        open: my $fh, ">", File::Spec->catfile: $dir, $file
            or die: "Could not create file $dir/$file: $^OS_ERROR"
        close $fh
    
    my $cwd = (Cwd::cwd: )
    chdir $dir
        or die: "Could not chdir to $dir: $^OS_ERROR"
    my @glob_files = glob: 'a*{d[e]}j'
    local $TODO = "home-made glob doesn't do regexes" if $^OS_NAME eq 'VMS'
    is_deeply: \@glob_files, \(@: 'a_dej')
    chdir $cwd
        or die: "Could not chdir back to $cwd: $^OS_ERROR"

