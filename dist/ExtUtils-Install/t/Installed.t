#!/usr/bin/perl -w

my $Is_VMS = $^OS_NAME eq 'VMS'

use Config < qw|config_keys config_value|
use Cwd
use File::Path
use File::Basename
use File::Spec

use Test::More tests => 51

BEGIN { (use_ok:  'ExtUtils::Installed' ) }

my $mandirs = ! ! (config_value: "man1direxp") + ! ! config_value: "man3direxp"

# saves having to qualify package name for class methods
my $ei = bless:  \$%, 'ExtUtils::Installed' 

# Make sure meta info is available
$ei->{+':private:'}{+Config} = %+:
    map: { (%: $_ => (config_value: $_)) }, (config_keys: )
$ei->{':private:'}{+INC} = $^INCLUDE_PATH

# _is_prefix
ok:  ($ei->_is_prefix: 'foo/bar', 'foo')
     '_is_prefix() should match valid path prefix' 
ok:  !($ei->_is_prefix: '\foo\bar', '\bar')
     '... should not match wrong prefix' 

# _is_type
ok:  ($ei->_is_type: 0, 'all'), '_is_type() should be true for type of "all"' 

foreach my $path (qw( man1dir man3dir ))
    :SKIP do
        my $dir = config_value: $path.'exp'
        skip: "no man directory $path on this system", 2  unless $dir

        my $file = $dir . '/foo'
        ok:  ($ei->_is_type: $file, 'doc'),   "... should find doc file in $path" 
        ok:  !($ei->_is_type: $file, 'prog'), "... but not prog file in $path" 
    


# VMS 5.6.1 doesn't seem to have $Config{prefixexp}
my $prefix = (config_value: "prefix") || config_value: "prefixexp"

# You can concatenate /foo but not foo:, which defaults in the current
# directory
$prefix = (VMS::Filespec::unixify: $prefix) if $Is_VMS

# ActivePerl 5.6.1/631 has $Config{prefixexp} as 'p:' for some reason
$prefix = (config_value: "prefix") if $prefix eq 'p:' && $^OS_NAME eq 'MSWin32'

ok:  ($ei->_is_type:  (File::Spec->catfile: $prefix, 'bar'), 'prog')
     "... should find prog file under $prefix" 

:SKIP do
    skip: 'no man directories on this system', 1 unless $mandirs
    is:  ($ei->_is_type: 'bar', 'doc'), 0
         '... should not find doc file outside path' 


ok:  !($ei->_is_type: 'bar', 'prog')
     '... nor prog file outside path' 
ok:  !($ei->_is_type: 'whocares', 'someother'), '... nor other type anywhere' 

# _is_under
ok:  ($ei->_is_under: 'foo'), '_is_under() should return true with no dirs' 

my @under = qw( boo bar baz )
ok:  !($ei->_is_under: 'foo', < @under), '... should find no file not under dirs'
ok:  ($ei->_is_under: 'baz', < @under),  '... should find file under dir' 


rmtree: 'auto/FakeMod'
ok:  (mkpath: 'auto/FakeMod') 
END { (rmtree: 'auto') }

ok: (open: my $packlist, ">", 'auto/FakeMod/.packlist')
print: $packlist, 'list'
close $packlist

ok: (open: my $fakemod, ">", 'auto/FakeMod/FakeMod.pm')

print: $fakemod, <<'FAKE'
package FakeMod;
use vars qw( $VERSION );
$VERSION = '1.1.1';
1;
FAKE

close $fakemod

my $fake_mod_dir = File::Spec->catdir: (cwd: ), 'auto', 'FakeMod'

# Do the same thing as the last block, but with overrides for
# %Config and $^INCLUDE_PATH.
do
    my $config_override = %+:
        map: { %: $_ => (Config::config_value: $_) },
                 (Config::config_keys: )
    $config_override{+archlibexp} = (cwd: )
    $config_override{+sitearchexp} = $fake_mod_dir
    $config_override{+version} = 'fake_test_version'

    my @inc_override = @: < $^INCLUDE_PATH, $fake_mod_dir

    my $realei = ExtUtils::Installed->new: 
        'config_override' => $config_override
        'inc_override' => \@inc_override
        
    isa_ok:  $realei, 'ExtUtils::Installed' 
    isa_ok:  $realei->{Perl}{?packlist}, 'ExtUtils::Packlist' 
    is:  $realei->{Perl}{?version}, 'fake_test_version'
         'new(config_override => HASH) overrides %Config' 

    ok:  exists $realei->{FakeMod}, 'new() with overrides should find modules with .packlists'
    isa_ok:  $realei->{FakeMod}{?packlist}, 'ExtUtils::Packlist' 
    is:  $realei->{FakeMod}{?version}, '1.1.1'
         '... should find version in modules' 


push: $^INCLUDE_PATH, $fake_mod_dir

# Check if extra_libs works.
do
    my $realei = ExtUtils::Installed->new: 
        'extra_libs' => \(@:  (cwd: ) )
        
    isa_ok:  $realei, 'ExtUtils::Installed' 
    isa_ok:  $realei->{Perl}{?packlist}, 'ExtUtils::Packlist' 
    ok:  exists $realei->{FakeMod}
         'new() with extra_libs should find modules with .packlists'

    #{ use Data::Dumper; local $realei->{':private:'}{Config};
    #  warn Dumper($realei); }

    isa_ok:  $realei->{FakeMod}{?packlist}, 'ExtUtils::Packlist' 
    is:  $realei->{FakeMod}{?version}, '1.1.1'
         '... should find version in modules' 


# modules
for (qw( abc def ghi ))
    $ei->{+$_} = 1
is:  (join: ' ', $ei->modules), 'abc def ghi'
     'modules() should return sorted keys' 

# This didn't work for a long time due to a sort in scalar context oddity.
is:  (nelems $ei->modules), 3,    'modules() in scalar context' 

# files
$ei->{+goodmod} = \%:
    packlist => \ %:
        ((config_value: "man1direxp") ??
         ((File::Spec->catdir: (config_value: "man1direxp"), 'foo') => 1) !!
         ())
        ((config_value: "man3direxp") ??
         ((File::Spec->catdir: (config_value: "man3direxp"), 'bar') => 1) !!
         ())
        (File::Spec->catdir: $prefix, 'foobar') => 1
        foobaz  => 1

dies_like:  sub (@< @_) { ($ei->files: 'badmod') }
            qr/badmod is not installed/,'files() should croak given bad modname'
dies_like:  sub (@< @_) { ($ei->files: 'goodmod', 'badtype' ) }
            qr/type must be/,'files() should croak given bad type' 

my @files
:SKIP do
    skip: 'no man directory man1dir on this system', 2
        unless config_value: "man1direxp"
    @files = $ei->files: 'goodmod', 'doc', (config_value: "man1direxp")
    is:  scalar nelems @files, 1, '... should find doc file under given dir' 
    is:  (nelems: (grep: { m/foo$/ }, @files)), 1, '... checking file name' 

:SKIP do
    skip: 'no man directories on this system', 1 unless $mandirs
    @files = $ei->files: 'goodmod', 'doc'
    is:  scalar nelems @files, $mandirs, '... should find all doc files with no dir' 


@files = $ei->files: 'goodmod', 'prog', 'fake', 'fake2'
is:  scalar nelems @files, 0, '... should find no doc files given wrong dirs' 
@files = $ei->files: 'goodmod', 'prog'
is:  scalar nelems @files, 1, '... should find doc file in correct dir' 
like:  @files[0], qr/foobar[>\]]?$/, '... checking file name' 
@files = $ei->files: 'goodmod'
is:  scalar nelems @files, 2 + $mandirs, '... should find all files with no type specified' 
my %dirnames = %+: map: { %: (lc: $_) => (dirname: $_) }, @files 

# directories
my @dirs = $ei->directories: 'goodmod', 'prog', 'fake'
is:  scalar nelems @dirs, 0, 'directories() should return no dirs if no files found' 

:SKIP do
    skip: 'no man directories on this system', 1 unless $mandirs
    @dirs = $ei->directories: 'goodmod', 'doc'
    is:  scalar nelems @dirs, $mandirs, '... should find all files files() would' 

@dirs = $ei->directories: 'goodmod'
is:  scalar nelems @dirs, 2 + $mandirs, '... should find all files files() would, again' 
@files = sort: map: { exists %dirnames{(lc: $_)} ?? %dirnames{?(lc: $_)} !! '' }, @files
is:  (join: ' ', @files), (join: ' ', @dirs), '... should sort output' 

# directory_tree
my $expectdirs =
      ($mandirs == 2) &&
    ((dirname: (config_value: "man1direxp")) eq (dirname: (config_value: "man3direxp")))
    ?? 3 !! 2

:SKIP do
    skip: 'no man directories on this system', 1 unless $mandirs
    @dirs = $ei->directory_tree: 'goodmod', 'doc', (config_value: "man1direxp") ??
                                     (dirname: (config_value: "man1direxp")) !! (dirname: (config_value: "man3direxp"))
    is:  scalar nelems @dirs, $expectdirs
         'directory_tree() should report intermediate dirs to those requested' 


my $fakepak = Fakepak->new: 102

$ei->{+yesmod} = \%:
    version         => 101
    packlist        => $fakepak

# these should all croak
foreach my $sub (qw( validate packlist version ))
    dies_like:  sub (@< @_) {( $ei->?$sub: 'nomod') }
                qr/nomod is not installed/
                "$sub() should croak when asked about uninstalled module" 


# validate
is:  ($ei->validate: 'yesmod'), 'validated'
     'validate() should return results of packlist validate() call' 

# packlist
is:   ($ei->packlist: 'yesmod')->$, 102
      'packlist() should report installed mod packlist' 

# version
is:  ($ei->version: 'yesmod'), 101
     'version() should report installed mod version' 


package Fakepak

sub new
    my $class = shift
    bless: \(my $scalar = shift), $class


sub validate
    return 'validated'

