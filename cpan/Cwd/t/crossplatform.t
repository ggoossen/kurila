#!/usr/bin/perl -w


use File::Spec
use lib File::Spec->catfile: 't', 'lib'
use Test::More
local $^OUTPUT_AUTOFLUSH =1

my @platforms = qw(Cygwin Epoc Mac OS2 Unix VMS Win32)
my $tests_per_platform = 10

plan: tests => 1 + (nelems @platforms) * $tests_per_platform

my %volumes = %:
    Mac => 'Macintosh HD'
    OS2 => 'A:'
    Win32 => 'A:'
    VMS => 'v'
    
my %other_vols = %:
    Mac => 'Mounted Volume'
    OS2 => 'B:'
    Win32 => 'B:'
    VMS => 'w'
    

ok: 1, "Loaded"

foreach my $platform ( @platforms)
    my $module = "File::Spec::$platform"

    :SKIP
        do
        eval "require $module; 1"

        skip: "Can't load $module", $tests_per_platform
            if $^EVAL_ERROR

        my $v = %volumes{?$platform} || ''
        my $other_v = %other_vols{?$platform} || ''

        # Fake out the environment on MacOS and Win32
        my $save_w = $^WARNING
        $^WARNING = 0
        local (Symbol::fetch_glob: "File::Spec::Mac::rootdir")->* = sub (@< @_) { "Macintosh HD:" }
        local (Symbol::fetch_glob: "File::Spec::Win32::_cwd")->*  = sub (@< @_) { "C:\\foo" }
        $^WARNING = $save_w



        my ($file, $base, $result)

        $base = $module->catpath: $v, ($module->catdir: '', 'foo'), ''
        $base = $module->catdir: ($module->rootdir: ), 'foo'

        is: ($module->file_name_is_absolute: $base), 1, "$base is absolute on $platform"

        # splitdir('') -> ()
        my @result = $module->splitdir: ''
        is:  (nelems @result), 0, "$platform->splitdir('') -> ()"

        # canonpath() -> undef
        $result = $module->canonpath: 
        is: $result, undef, "$platform->canonpath() -> undef"

        # canonpath(undef) -> undef
        $result = $module->canonpath: undef
        is: $result, undef, "$platform->canonpath(undef) -> undef"

        # abs2rel('A:/foo/bar', 'A:/foo')    ->  'bar'
        $file = $module->catpath: $v, ($module->catdir: ($module->rootdir: ), 'foo', 'bar'), 'file'
        $base = $module->catpath: $v, ($module->catdir: ($module->rootdir: ), 'foo'), ''
        $result = $module->catfile: 'bar', 'file'
        is: ($module->abs2rel: $file, $base), $result, "$platform->abs2rel($file, $base)"

        # abs2rel('A:/foo/bar', 'B:/foo')    ->  'A:/foo/bar'
        $base = $module->catpath: $other_v, ($module->catdir: ($module->rootdir: ), 'foo'), ''
        $result = (volumes_differ: $module, $file, $base) ?? $file !! $module->catfile: 'bar', 'file'
        is: ($module->abs2rel: $file, $base), $result, "$platform->abs2rel($file, $base)"

        # abs2rel('A:/foo/bar', '/foo')      ->  'A:/foo/bar'
        $base = $module->catpath: '', ($module->catdir: ($module->rootdir: ), 'foo'), ''
        $result = (volumes_differ: $module, $file, $base) ?? $file !! $module->catfile: 'bar', 'file'
        is: ($module->abs2rel: $file, $base), $result, "$platform->abs2rel($file, $base)"

        # abs2rel('/foo/bar/file', 'A:/foo')    ->  '/foo/bar'
        $file = $module->catpath: '', ($module->catdir: ($module->rootdir: ), 'foo', 'bar'), 'file'
        $base = $module->catpath: $v, ($module->catdir: ($module->rootdir: ), 'foo'), ''
        $result = (volumes_differ: $module, $file, $base) ?? ($module->rel2abs: $file) !! $module->catfile: 'bar', 'file'
        is: ($module->abs2rel: $file, $base), $result, "$platform->abs2rel($file, $base)"

        # abs2rel('/foo/bar', 'B:/foo')    ->  '/foo/bar'
        $base = $module->catpath: $other_v, ($module->catdir: ($module->rootdir: ), 'foo'), ''
        $result = (volumes_differ: $module, $file, $base) ?? ($module->rel2abs: $file) !! $module->catfile: 'bar', 'file'
        is: ($module->abs2rel: $file, $base), $result, "$platform->abs2rel($file, $base)"

        # abs2rel('/foo/bar', '/foo')      ->  'bar'
        $base = $module->catpath: '', ($module->catdir: ($module->rootdir: ), 'foo'), ''
        $result = $module->catfile: 'bar', 'file'
        is: ($module->abs2rel: $file, $base), $result, "$platform->abs2rel($file, $base)"
    


sub volumes_differ($module, $one, $two)
    my (@: $one_v, ...) =  $module->splitpath:  ($module->rel2abs: $one) 
    my (@: $two_v, ...) =  $module->splitpath:  ($module->rel2abs: $two) 
    return $one_v ne $two_v

