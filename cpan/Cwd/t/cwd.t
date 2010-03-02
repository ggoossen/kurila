#!./perl -w

use Cwd

use Config
use File::Spec
use File::Path

use lib File::Spec->catdir: 't', 'lib'
use Test::More
require VMS::Filespec if $^OS_NAME eq 'VMS'

my $tests = 30
# _perl_abs_path() currently only works when the directory separator
# is '/', so don't test it when it won't work.
my $EXTRA_ABSPATH_TESTS = ((config_value: 'prefix') =~ m/\//) && $^OS_NAME ne 'cygwin'
$tests += 4 if $EXTRA_ABSPATH_TESTS
plan: tests => $tests

:SKIP do
    skip: "no need to check for blib/ in the core", 1 if env::var: 'PERL_CORE'
    like: $^INCLUDED{?'Cwd.pm'}, qr{blib}i, "Cwd should be loaded from blib/ during testing"


my $IsVMS = $^OS_NAME eq 'VMS'
my $IsMacOS = $^OS_NAME eq 'MacOS'

# check imports
can_ok: 'main', < qw(cwd getcwd fastcwd fastgetcwd)
ok:  !(exists: &chdir),           'chdir() not exported by default' 
ok:  !(exists: &abs_path),        '  nor abs_path()' 
ok:  !(exists: &fast_abs_path),   '  nor fast_abs_path()'

do
    my @fields = qw(PATH IFS CDPATH ENV BASH_ENV)
    my $before = grep: { defined (env::var: $_) }, @fields
    (cwd: )
    my $after = grep: { defined (env::var: $_) }, @fields
    is: (nelems: $before), (nelems: $after), "cwd() shouldn't create spurious entries in \%ENV"


# XXX force Cwd to bootsrap its XSUBs since we have set $^INCLUDE_PATH = "../lib"
# XXX and subsequent chdir()s can make them impossible to find
try { (fastcwd: )}

# Must find an external pwd (or equivalent) command.

my $pwd = $^OS_NAME eq 'MSWin32' ?? "cmd" !! "pwd"
my $pwd_cmd =
    ($^OS_NAME eq "NetWare") ??
    "cd" !!
    ($IsMacOS) ??
    "pwd" !!
    ((grep: { -x && -f }, (map: { "$_/$pwd$((config_value: 'exe_ext'))" },
                                    (split: m/$(config_value('path_sep'))/, (env::var: 'PATH')))))[0]

$pwd_cmd = 'SHOW DEFAULT' if $IsVMS
if ($^OS_NAME eq 'MSWin32')
    $pwd_cmd =~ s,/,\\,g
    $pwd_cmd = "$pwd_cmd /c cd"

$pwd_cmd =~ s=\\=/=g if ($^OS_NAME eq 'dos')

:SKIP do
    skip: "No native pwd command found to test against", 4 unless $pwd_cmd

    print: $^STDOUT, "# native pwd = '$pwd_cmd'\n"

    my %local_env_keys = %:< @+: map: { @: $_, (env::var: $_) }, qw[PATH IFS CDPATH ENV BASH_ENV]
    push: dynascope->{onleave}, sub (@< @_)
              for (keys %local_env_keys)
                  (env::var: $_) = %local_env_keys{$_}
    
    for (keys %local_env_keys)
        (env::var: $_) = undef
    my (@: $pwd_cmd_untainted) = @: $pwd_cmd =~ m/^(.+)$/ # Untaint.
    chomp: (my $start = `$pwd_cmd_untainted`)

    # Win32's cd returns native C:\ style
    $start =~ s,\\,/,g if ($^OS_NAME eq 'MSWin32' || $^OS_NAME eq "NetWare")
    # DCL SHOW DEFAULT has leading spaces
    $start =~ s/^\s+// if $IsVMS
    :SKIP do
        skip: "'$pwd_cmd' failed, nothing to test against", 4 if $^CHILD_ERROR
        skip: "/afs seen, paths unlikely to match", 4 if $start =~ m|/afs/|

        # Darwin's getcwd(3) (which Cwd.xs:bsd_realpath() uses which
        # Cwd.pm:getcwd uses) has some magic related to the PWD
        # environment variable: if PWD is set to a directory that
        # looks about right (guess: has the same (dev,ino) as the '.'?),
        # the PWD is returned.  However, if that path contains
        # symlinks, the path will not be equal to the one returned by
        # /bin/pwd (which probably uses the usual walking upwards in
        # the path -trick).  This situation is easy to reproduce since
        # /tmp is a symlink to /private/tmp.  Therefore we invalidate
        # the PWD to force getcwd(3) to (re)compute the cwd in full.
        # Admittedly fixing this in the Cwd module would be better
        # long-term solution but deleting $ENV{PWD} should not be
        # done light-heartedly. --jhi
        (env::var: 'PWD') = undef if $^OS_NAME eq 'darwin'

        my $cwd        = (cwd: )
        my $getcwd     = (getcwd: )
        my $fastcwd    = (fastcwd: )
        my $fastgetcwd = (fastgetcwd: )

        is: $cwd,        $start, 'cwd()'
        is: $getcwd,     $start, 'getcwd()'
        is: $fastcwd,    $start, 'fastcwd()'
        is: $fastgetcwd, $start, 'fastgetcwd()'
    


my @test_dirs = qw{_ptrslt_ _path_ _to_ _a_ _dir_}
my $Test_Dir     = File::Spec->catdir: < @test_dirs

mkpath: \(@: $Test_Dir), 0, 0777
Cwd::chdir:  $Test_Dir

foreach my $func (qw(cwd getcwd fastcwd fastgetcwd))
    my $result = eval "$func()"
    is: $^EVAL_ERROR, ''
    dir_ends_with:  $result, $Test_Dir, "$func()" 


do
    # Some versions of File::Path (e.g. that shipped with perl 5.8.5)
    # call getcwd() with an argument (perhaps by calling it as a
    # method?), so make sure that doesn't die.
    is: (getcwd: ), (getcwd: 'foo'), "Call getcwd() with an argument"


# Cwd::chdir should also update $ENV{PWD}
dir_ends_with:  (env::var: 'PWD'), $Test_Dir, 'Cwd::chdir() updates $ENV{PWD}' 
my $updir = File::Spec->updir

for (1..nelems @test_dirs)
    Cwd::chdir:  $updir
    print: $^STDOUT, "#$((env::var: 'PWD'))\n"


rmtree: @test_dirs[0], 0, 0

do
    my $check = ($IsVMS   ?? qr|\b((?i)Cwd)\]$| !!
                 $IsMacOS ?? qr|\bCwd:$| !!
                 qr|\bCwd$| )

    like: (env::var: 'PWD'), $check


do
    # Make sure abs_path() doesn't trample $ENV{PWD}
    my $start_pwd = env::var: 'PWD'
    mkpath: \(@: $Test_Dir), 0, 0777
    Cwd::abs_path: $Test_Dir
    is: (env::var: 'PWD'), $start_pwd
    rmtree: @test_dirs[0], 0, 0


:SKIP do
    skip: "no symlinks on this platform", 2+$EXTRA_ABSPATH_TESTS unless config_value: 'd_symlink'

    mkpath: \(@: $Test_Dir), 0, 0777
    symlink: $Test_Dir, "linktest"

    my $abs_path      =  Cwd::abs_path: "linktest"
    my $fast_abs_path =  Cwd::fast_abs_path: "linktest"
    my $want          =  quotemeta: 
        File::Spec->rel2abs: 
            (env::var: 'PERL_CORE') ?? $Test_Dir !! < File::Spec->catdir: 't', $Test_Dir
            
        

    like: $abs_path,      qr|$want$|i
    like: $fast_abs_path, qr|$want$|i
    like: (Cwd::_perl_abs_path: "linktest"), qr|$want$|i if $EXTRA_ABSPATH_TESTS

    rmtree: @test_dirs[0], 0, 0
    1 while unlink: "linktest"


if ((env::var: 'PERL_CORE'))
    chdir 't'
    unshift: $^INCLUDE_PATH, '../../../lib'


# Make sure we can run abs_path() on files, not just directories
my $path = 'cwd.t'
path_ends_with: (Cwd::abs_path: $path), 'cwd.t', 'abs_path() can be invoked on a file'
path_ends_with: (Cwd::fast_abs_path: $path), 'cwd.t', 'fast_abs_path() can be invoked on a file'
path_ends_with: (Cwd::_perl_abs_path: $path), 'cwd.t', '_perl_abs_path() can be invoked on a file'
    if $EXTRA_ABSPATH_TESTS

$path = File::Spec->catfile: File::Spec->updir, 't', $path
path_ends_with: (Cwd::abs_path: $path), 'cwd.t', 'abs_path() can be invoked on a file'
path_ends_with: (Cwd::fast_abs_path: $path), 'cwd.t', 'fast_abs_path() can be invoked on a file'
path_ends_with: (Cwd::_perl_abs_path: $path), 'cwd.t', '_perl_abs_path() can be invoked on a file'
    if $EXTRA_ABSPATH_TESTS



:SKIP do
    my $file
    do
        my $root = Cwd::abs_path: File::Spec->rootdir	# Add drive letter?
        opendir: my $fh, $root or skip: "Can't opendir($root): $^OS_ERROR", 2+$EXTRA_ABSPATH_TESTS
        (@: ?$file) = grep: {-f $_ and not -l $_}, map: { (File::Spec->catfile: $root, $_) }, @:  readdir $fh
        closedir $fh
    
    skip: "No plain file in root directory to test with", 2+$EXTRA_ABSPATH_TESTS unless $file

    $file = (VMS::Filespec::rmsexpand: $file) if $^OS_NAME eq 'VMS'
    is: (Cwd::abs_path: $file), $file, 'abs_path() works on files in the root directory'
    is: (Cwd::fast_abs_path: $file), $file, 'fast_abs_path() works on files in the root directory'
    is: (Cwd::_perl_abs_path: $file), $file, '_perl_abs_path() works on files in the root directory'
        if $EXTRA_ABSPATH_TESTS



#############################################
# These routines give us sort of a poor-man's cross-platform
# directory or path comparison capability.

sub bracketed_form_dir
    return join: '', map: { "[$_]" }, grep: { length }, File::Spec->splitdir: (File::Spec->canonpath:  (shift: ) )


sub dir_ends_with
    my (@: $dir, $expect) = @: shift, shift
    my $bracketed_expect = quotemeta bracketed_form_dir: $expect
    like:  (bracketed_form_dir: $dir), qr|$bracketed_expect$|i, ((nelems @_) ?? shift !! ()) 


sub bracketed_form_path
    return join: '', map: { "[$_]" }, grep: { length }, File::Spec->splitpath: (File::Spec->canonpath:  (shift: ) )


sub path_ends_with
    my (@: $dir, $expect) = @: shift, shift
    my $bracketed_expect = quotemeta bracketed_form_path: $expect
    like:  (bracketed_form_path: $dir), qr|$bracketed_expect$|i, ((nelems @_) ?? shift !! ()) 

