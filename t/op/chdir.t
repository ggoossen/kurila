#!./perl -w

use Config
require "./test.pl"
plan: tests => 48

my $IsVMS   = $^OS_NAME eq 'VMS'
my $IsMacOS = $^OS_NAME eq 'MacOS'

# For an op regression test, I don't want to rely on "use constant" working.
my $has_fchdir = ((config_value: "d_fchdir") || "") eq "define"

# Might be a little early in the testing process to start using these,
# but I can't think of a way to write this test without them.
use File::Spec::Functions < qw(:DEFAULT splitdir rel2abs splitpath)

# Can't use Cwd::abs_path() because it has different ideas about
# path separators than File::Spec.
sub abs_path
    my $d = rel2abs: (curdir: )

    $d = (uc: $d) if $IsVMS
    $d = (lc: $d) if $^OS_NAME =~ m/^uwin/
    $d


my $Cwd = (abs_path: )

# Let's get to a known position
:SKIP do
    my (@: $vol,$dir, ...) =  splitpath: (abs_path: ),1
    my $test_dir = $IsVMS ?? 'T' !! 't'
    skip: "Already in t/", 2 if ((splitdir: $dir))[-1] eq $test_dir

    ok:  (chdir: $test_dir),     'chdir($test_dir)'
    is:  < (abs_path: ), < (catdir: $Cwd, $test_dir),    '  abs_path() agrees' 


$Cwd = (abs_path: )

:SKIP do
    skip: "no fchdir", 16 unless $has_fchdir
    my $has_dirfd = (config_value: "d_dirfd"
                     || (config_value: "d_dir_dd_fd") || "") eq "define"
    ok: (opendir: my $dh, "."), "opendir ."
    ok: (open: my $fh, "<", "op"), "open op"
    ok: (chdir: $fh), "fchdir op"
    ok: -f "chdir.t", "verify that we are in op"
    if ($has_dirfd)
        ok: (chdir: $dh), "fchdir back"
    else
        try { (chdir: $dh); }
        like: $^EVAL_ERROR->{?description}, qr/^The dirfd function is unimplemented at/, "dirfd is unimplemented"
        chdir ".." or die: $^OS_ERROR
    

    # same with bareword file handles
    no warnings 'once'
    *DH = $dh->*{IO}
    *FH = $fh->*{IO}
    ok: chdir *FH, "fchdir op bareword"
    ok: -f "chdir.t", "verify that we are in op"
    if ($has_dirfd)
        ok: chdir *DH, "fchdir back bareword"
    else
        try { (chdir: *DH); }
        like: $^EVAL_ERROR->{?description}, qr/^The dirfd function is unimplemented at/, "dirfd is unimplemented"
        chdir ".." or die: $^OS_ERROR
    
    ok: -d "op", "verify that we are back"

    # And now the ambiguous case
    my $h
    do
        no warnings < qw<io deprecated>
        ok: (opendir: $h, "op"), "opendir op" or $^OS_ERROR-> diag: 
        ok: (open: $h, "<", "base"), "open base" or $^OS_ERROR-> diag: 
    
    if ($has_dirfd)
        ok: (chdir: $h), "fchdir to op"
        ok: -f "chdir.t", "verify that we are in 'op'"
        chdir ".." or die: $^OS_ERROR
    else
        try { (chdir: $h); }
        like: $^EVAL_ERROR->{?description}, qr/^The dirfd function is unimplemented at/
              "dirfd is unimplemented"
        :SKIP do
            skip: "dirfd is unimplemented"
        
    
    ok: (closedir: $h), "closedir"
    ok: (chdir: $h), "fchdir to base"
    ok: -f "cond.t", "verify that we are in 'base'"
    chdir ".." or die: $^OS_ERROR


:SKIP do
    skip: "has fchdir", 1 if $has_fchdir
    opendir: my $dh, "op"
    try { (chdir: $dh); }
    like: $^EVAL_ERROR->{?description}, qr/^The fchdir function is unimplemented at/, "fchdir is unimplemented"


# The environment variables chdir() pays attention to.
my @magic_envs = qw(HOME LOGDIR SYS$LOGIN)

sub check_env
    my(@: $key) =  @_

    # Make sure $ENV{'SYS$LOGIN'} is only honored on VMS.
    if( $key eq 'SYS$LOGIN' && !$IsVMS && !$IsMacOS )
        ok:  !(chdir: ),         "chdir() on $^OS_NAME ignores only \$ENV\{$key\} set" 
        is:  (abs_path: ), $Cwd,   '  abs_path() did not change' 
        for (1..7)
            pass:  "  no need to test SYS\$LOGIN on $^OS_NAME" 
    else
        ok:  (chdir: ),              "chdir() w/ only \$ENV\{$key\} set" 
        is:  (abs_path: ), (env::var: $key), '  abs_path() agrees' 
        chdir: $Cwd
        is:  (abs_path: ), $Cwd,       '  and back again' 

        my $warning = ''
        local $^WARN_HOOK = sub (@< @_) { $warning .= @_[0]->{?description} . "\n" }


        # Check the deprecated chdir(undef) feature.
        ok:  (chdir: undef),           "chdir(undef) w/ only \$ENV\{$key\} set" 
        is:  (abs_path: ), (env::var: $key),   '  abs_path() agrees' 
        is:  $warning,  <<WARNING,   '  got uninit & deprecation warning' 
Use of uninitialized value in chdir
Use of chdir('') or chdir(undef) as chdir() is deprecated
WARNING

        chdir: $Cwd

        # Ditto chdir('').
        $warning = ''
        ok:  (chdir: ''),              "chdir('') w/ only \$ENV\{$key\} set" 
        is:  (abs_path: ), (env::var: $key),   '  abs_path() agrees' 
        is:  $warning,  <<WARNING,   '  got deprecation warning' 
Use of chdir('') or chdir(undef) as chdir() is deprecated
WARNING

        chdir: $Cwd
    


my %Saved_Env = $%
sub clean_env
    foreach my $env ( @magic_envs)
        %Saved_Env{+$env} = env::var: $env

        # Can't actually delete SYS$ stuff on VMS.
        next if $IsVMS && $env eq 'SYS$LOGIN'
        next if $IsVMS && $env eq 'HOME' && ! config_value: 'd_setenv'

        unless ($IsMacOS) # ENV on MacOS is "special" :-)
            # On VMS, %ENV is many layered.
            (env::var: $env) = undef while defined env::var: $env
        
    

    # The following means we won't really be testing for non-existence,
    # but in Perl we can only delete from the process table, not the job
    # table.
    (env::var: 'SYS$LOGIN' ) = '' if $IsVMS


END 
    no warnings 'uninitialized'

    # Restore the environment for VMS (and doesn't hurt for anyone else)
    for my $key (@magic_envs)
        (env::var: $key) = %Saved_Env{$key}

    # On VMS this must be deleted or process table is wrong on exit
    # when this script is run interactively.
    (env::var: 'SYS$LOGIN') = undef if $IsVMS



foreach my $key ( @magic_envs)
    # We're going to be using undefs a lot here.
    no warnings 'uninitialized'

    (clean_env: )
    (env::var: $key ) = catdir: $Cwd, ($IsVMS ?? 'OP' !! 'op')

    check_env: $key


do
    (clean_env: )
    if (($IsVMS || $IsMacOS) && ! (config_value: 'd_setenv'))
        pass: "Can't reset HOME, so chdir() test meaningless"
    else
        ok:  !(chdir: ),                   'chdir() w/o any ENV set' 
    
    is:  (abs_path: ), $Cwd,             '  abs_path() agrees' 

