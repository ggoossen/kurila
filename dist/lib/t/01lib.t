#!./perl -w

our @OrigINC
BEGIN 
    @OrigINC = $^INCLUDE_PATH


use Test::More tests => 13
use Config
use File::Spec
use File::Path

#set up files and directories
my @lib_dir
my $Lib_Dir
my $Arch_Dir
my $Auto_Dir
my $Module
BEGIN 
    # lib.pm is documented to only work with Unix filepaths.
    @lib_dir  =qw(stuff moo)
    $Lib_Dir  = join: "/",@lib_dir
    $Arch_Dir = join: "/", @:  <@lib_dir, config_value: "archname"

    # create the auto/ directory and a module
    $Auto_Dir = File::Spec->catdir: <@lib_dir, (config_value: "archname"),'auto'
    $Module   = File::Spec->catfile: <@lib_dir, 'Yup.pm'

    mkpath: \@: $Auto_Dir

    (open: my $mod, ">", "$Module") || $^OS_ERROR-> DIE: 
    print: $mod ,<<'MODULE'
package Yup;
our $Plan = 9;
return '42';
MODULE

    close $mod


END 
    # cleanup the auto/ directory we created.
    rmtree: @lib_dir[0]



use lib $Lib_Dir
use lib $Lib_Dir

BEGIN { (use_ok: 'Yup') }

BEGIN 
    if ($^OS_NAME eq 'MacOS')
        for ((@: $Lib_Dir, $Arch_Dir))
            s|/|:|g
            $_ .= ":" unless m/:$/
            $_ = ":$_" unless m/^:/ # we know this path is relative
        
    
    is:  $^INCLUDE_PATH[1], $Lib_Dir,          'lib adding at end of $^INCLUDE_PATH' 
    is:  $^INCLUDE_PATH[0], $Arch_Dir,        '    auto/ dir in front of that' 
    is:  (nelems: (grep:  {m/^\Q$Lib_Dir\E$/ },$^INCLUDE_PATH)), 1,   '    no duplicates' 

    # Yes, $^INCLUDED uses Unixy filepaths.
    # Not on Mac OS, it doesn't ... it never has, at least.
    my $path = join: "/", (@: $Lib_Dir, 'Yup.pm')
    if ($^OS_NAME eq 'MacOS')
        $path = $Lib_Dir . 'Yup.pm'
    
    is:  $^INCLUDED{?'Yup.pm'}, $path,    '$^INCLUDED set properly' 

    is:  try { evalfile 'Yup.pm'  }, 42,  'do() works' 
    ok:  try { require Yup; },      '   require()' 
    ok:  eval "use Yup; 1;",         '   use()' 
    is:  $^EVAL_ERROR, '' 

    is_deeply: \@OrigINC, \@lib::ORIG_INCLUDE_PATH,    '@lib::ORIG_INC' 


no lib $Lib_Dir

unlike:  do { eval 'use lib config_value("installsitelib");'; $^EVAL_ERROR || '' }
         qr/::Config is read-only/, 'lib handles readonly stuff' 

BEGIN 
    is:  (nelems: (grep:  {m/stuff/ },$^INCLUDE_PATH)), 0, 'no lib' 
    ok:  !evalfile 'Yup.pm',           '   do() effected' 

