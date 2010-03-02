#!./perl -w

BEGIN 
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @: '../lib'


use File::Spec
my($blib, $blib_arch, $blib_lib, @blib_dirs)

sub _cleanup
    foreach ((reverse: @_))
        rmdir
    unlink: "stderr" unless $^OS_NAME eq 'MacOS'


sub _mkdirs
    for my $dir (@_)
        next if -d $dir
        mkdir: $dir or die: "Can't mkdir $dir: $^OS_ERROR" if ! -d $dir
    



BEGIN 
    if ($^OS_NAME eq 'MacOS')
        $MacPerl::Architecture = $MacPerl::Architecture # shhhhh
        $blib = ":blib:"
        $blib_lib = ":blib:lib:"
        $blib_arch = ":blib:lib:$MacPerl::Architecture:"
        @blib_dirs = @: $blib, $blib_lib, $blib_arch # order
    else
        $blib = "blib"
        $blib_arch = "blib/arch"
        $blib_lib = "blib/lib"
        @blib_dirs = @: $blib, $blib_arch, $blib_lib
    
    _cleanup:  < @blib_dirs 


use Test::More tests => 7

eval 'use blib;'
like:  $^EVAL_ERROR->message, qr/Cannot find blib/, 'Fails if blib directory not found' 

_mkdirs:  < @blib_dirs 

do
    my $warnings = ''
    local $^WARN_HOOK = sub (@< @_) { $warnings = (join: '', @_) }
    use_ok: 'blib'
    is:  $warnings, '',  'use blib is nice and quiet' 


is:  (nelems: $^INCLUDE_PATH), 3, '@INC now has 3 elements' 
is:  $^INCLUDE_PATH[2],    '../lib',       'blib added to the front of @INC' 

if ($^OS_NAME eq 'VMS')
    # Unix syntax is accepted going in but it's not what comes out
    # So we don't use catdir above
    $blib_arch = 'blib.arch]'
    $blib_lib = 'blib.lib]'
elsif ($^OS_NAME ne 'MacOS')
    $blib_arch = File::Spec->catdir: "blib","arch"
    $blib_lib  = File::Spec->catdir: "blib","lib"



ok:  (nelems: (grep: { m|\Q$blib_lib\E$| }, $^INCLUDE_PATH[[0..1]]))  == 1,     "  $blib_lib in \@INC"
ok:  (nelems: (grep: { m|\Q$blib_arch\E$| }, $^INCLUDE_PATH[[0..1]])) == 1,     "  $blib_arch in \@INC"

END { (_cleanup:  < @blib_dirs ); }
