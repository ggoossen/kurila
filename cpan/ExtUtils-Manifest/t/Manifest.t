#!/usr/bin/perl -w

use Test::More tests => 71
use Cwd

use File::Spec
use File::Path
use File::Find
use Config

my $Is_VMS = $^OS_NAME eq 'VMS'

# We're going to be chdir'ing and modules are sometimes loaded on the
# fly in this test, so we need an absolute $^INCLUDE_PATH.
$^INCLUDE_PATH = map: { (File::Spec->rel2abs: $_) }, $^INCLUDE_PATH

# keep track of everything added so it can all be deleted
my %Files
sub add_file
    my (@: $file, ?$data) =  @_
    $data ||= 'foo'
    1 while unlink: $file  # or else we'll get multiple versions on VMS
    open:  my $t, ">", ''.$file or return
    print: $t, $data
    ++%Files{+$file}
    close $t

sub read_manifest
    open:  my $m, "<", 'MANIFEST'  or return
    chomp: ( my @files = (@:  ~< $m->* )) 
    close $m
    return @files


sub catch_warning
    my $warn = ''
    local $^WARN_HOOK = sub (@< @_) { $warn .= @_[0]->{?description} }
    return @:(  @_[0]->& <: ), $warn 


sub remove_dir
    for (@_)
        ok:  (rmdir:  $_ ), "remove $_ directory" 


# use module, import functions
BEGIN 
    use_ok:  'ExtUtils::Manifest', <
                     qw( mkmanifest manicheck filecheck fullcheck 
                maniread manicopy skipcheck maniadd maniskip) 

my $cwd = (Cwd::getcwd: )

# Just in case any old files were lying around.
rmtree: 'mantest'

ok:  (mkdir:  'mantest', 0777 ), 'make mantest directory' 
ok:  (chdir:  'mantest' ), 'chdir() to mantest' 
ok:  (add_file: 'foo'), 'add a temporary file' 

# This ensures the -x check for manicopy means something
# Some platforms don't have chmod or an executable bit, in which case
# this call will do nothing or fail, but on the platforms where chmod()
# works, we test the executable bit is copied
chmod:  0744, 'foo' if config_value: 'chmod'

# there shouldn't be a MANIFEST there
my (@: $res, $warn) =  catch_warning:  \&mkmanifest 
# Canonize the order.
$warn = join: "", (map: { "$_|" },
                            (sort: { (lc: $a) cmp (lc: $b) }, (split: m/\r?\n/, $warn)))
is:  $warn, "Added to MANIFEST: foo|Added to MANIFEST: MANIFEST|"
     "mkmanifest() displayed its additions" 

# and now you see it
ok:  -e 'MANIFEST', 'create MANIFEST file' 

my @list = (read_manifest: )
is:  (nelems @list), 2, 'check files in MANIFEST' 
ok:  ! (ExtUtils::Manifest::filecheck: ), 'no additional files in directory' 

# after adding bar, the MANIFEST is out of date
ok:  (add_file:  'bar' ), 'add another file' 
ok:  ! (manicheck: ), 'MANIFEST now out of sync' 

# it reports that bar has been added and throws a warning
(@: $res, $warn) =  catch_warning:  \&filecheck 

like:  $warn, qr/^Not in MANIFEST: bar/, 'warning that bar has been added' 
is_deeply:  $res, (@: 'bar'), 'bar reported as new' 

# now quiet the warning that bar was added and test again
(@: $res, $warn) = do { local $ExtUtils::Manifest::Quiet = 1;
    catch_warning:  \&skipcheck 
}
is:  $warn, '', 'disabled warnings' 

# add a skip file with a rule to skip itself (and the nonexistent glob '*baz*')
add_file:  'MANIFEST.SKIP', "baz\n.SKIP" 

# this'll skip the new file
(@: $res, $warn) =  catch_warning:  \&skipcheck 
like:  $warn, qr/^Skipping MANIFEST\.SKIP/i, 'got skipping warning' 

my @skipped
catch_warning:  sub (@< @_)
                    @skipped = (skipcheck: )
               

is:  (join:  ' ', @skipped ), 'MANIFEST.SKIP', 'listed skipped files' 

do
    local $ExtUtils::Manifest::Quiet = 1
    is:  (join: ' ', (filecheck: ) ), 'bar', 'listing skipped with filecheck()' 


# add a subdirectory and a file there that should be found
ok:  (mkdir:  'moretest', 0777 ), 'created moretest directory' 
add_file:  (File::Spec->catfile: 'moretest', 'quux'), 'quux' 
ok:  (exists:  (ExtUtils::Manifest::manifind: )->{'moretest/quux'} )
     "manifind found moretest/quux" 

# only MANIFEST and foo are in the manifest
$_ = 'foo'
my $files = (maniread: )
is:  nkeys $files->%, 2, 'two files found' 
is:  (join: ' ', (sort: { (lc: $a) cmp (lc: $b) }, keys $files->%)), 'foo MANIFEST'
     'both files found' 
is:  $_, 'foo', q{maniread() doesn't clobber $_} 

ok:  (mkdir:  'copy', 0777 ), 'made copy directory' 

# Check that manicopy copies files.
manicopy:  $files, 'copy', 'cp' 
my @copies = $@
find:  sub (@< @_) { push: @copies, $_ if -f }, 'copy' 
@copies = (map: { s/\.$//; $_ }, @copies) if $Is_VMS  # VMS likes to put dots on
# the end of files.
# Have to compare insensitively for non-case preserving VMS
is_deeply:  \((sort: (map: { lc }, @copies))), \((sort: (map: { lc }, keys $files->%))) 

# cp would leave files readonly, so check permissions.
foreach my $orig ( @copies)
    my $copy = "copy/$orig"
    ok:  -r $copy,               "$copy: must be readable" 
    is:  -w $copy, -w $orig,     "       writable if original was" 
    is:  -x $copy, -x $orig,     "       executable if original was" 

rmtree: 'copy'


# poison the manifest, and add a comment that should be reported
add_file:  'MANIFEST', 'none #none' 
is:  (ExtUtils::Manifest::maniread: )->{?none}, '#none'
     'maniread found comment' 

ok:  (mkdir:  'copy', 0777 ), 'made copy directory' 
$files = (maniread: )
try { (@: _, $warn) =  catch_warning:  sub (@< @_) { (manicopy:  $files, 'copy', 'cp' ) } 
}
like:  $^EVAL_ERROR->{?description}, qr/^Can't read none: /, 'croaked about none' 

# a newline comes through, so get rid of it
chomp: $warn

# the copy should have given one warning and one error
like: $warn, qr/^Skipping MANIFEST.SKIP/i, 'warned about MANIFEST.SKIP' 

# tell ExtUtils::Manifest to use a different file
do
    local $ExtUtils::Manifest::MANIFEST = 'albatross'
    (@: $res, $warn) =  catch_warning:  \&mkmanifest 
    like:  $warn, qr/Added to albatross: /, 'using a new manifest file' 

    # add the new file to the list of files to be deleted
    %Files{+'albatross'}++



# Make sure MANIFEST.SKIP is using complete relative paths
add_file:  'MANIFEST.SKIP' => "^moretest/q\n" 

# This'll skip moretest/quux
(@: $res, $warn) =  catch_warning:  \&skipcheck 
like:  $warn, qr{^Skipping moretest/quux$}i, 'got skipping warning again' 


# There was a bug where entries in MANIFEST would be blotted out
# by MANIFEST.SKIP rules.
add_file:  'MANIFEST.SKIP' => 'foo' 
add_file:  'MANIFEST'      => "foobar\n"   
add_file:  'foobar'        => '123' 
(@: $res, $warn) =  catch_warning:  \&manicheck 
is_deeply:  $res,  $@,      'MANIFEST overrides MANIFEST.SKIP' 
is:  $warn, '',   'MANIFEST overrides MANIFEST.SKIP, no warnings' 

$files = (maniread: )
ok:  !$files->{?wibble},     'MANIFEST in good state' 
maniadd: \(%:  wibble => undef )
maniadd: \(%:  yarrow => "hock" )
$files = (maniread: )
is:  $files->{?wibble}, '',    'maniadd() with undef comment' 
is:  $files->{?yarrow}, 'hock','          with comment' 
is:  $files->{?foobar}, '',    '          preserved old entries' 

my %funky_files
# test including a filename with a space
:SKIP do
    add_file:  'foo bar' => "space" 
        or skip: "couldn't create spaced test file", 2
    local $ExtUtils::Manifest::MANIFEST = "albatross"
    maniadd:  \%: 'foo bar' => "contains space" 
    is:  (maniread: )->{'foo bar'}, "contains space"
         'spaced manifest filename' 
    add_file:  'albatross.bak', '' 
    @: $res, $warn = catch_warning:  \&mkmanifest 
    like:  $warn, qr/\A(Added to.*\n)+\z/m
           'no warnings about funky filename' 
    %funky_files{+'space'} = 'foo bar'

# test including a filename with a space and a quote
:SKIP do
    add_file:  "foo\' baz\'quux" => "quote" 
        or skip: "couldn't create quoted test file", 1
    local $ExtUtils::Manifest::MANIFEST = "albatross"
    maniadd:  \%: "foo\' baz\'quux" => "contains quote" 
    is:  (maniread: )->{"foo\' baz\'quux"}, "contains quote"
         'quoted manifest filename' 
    %funky_files{+'space_quote'} = "foo\' baz\'quux"

# test including a filename with a space and a backslash
:SKIP do
    add_file:  'foo bar\\baz' => "backslash" 
        or skip: "couldn't create backslash test file", 1
    local $ExtUtils::Manifest::MANIFEST = "albatross"
    maniadd:  \%: "foo bar\\baz" => "contains backslash" 
    is:  (maniread: )->{'foo bar\baz'}, "contains backslash"
         'backslashed manifest filename' 
    %funky_files{+'space_backslash'} = "foo bar\\baz"

# test including a filename with a space, quote, and a backslash
:SKIP do
    add_file:  "foo bar\\baz\'quux" => "backslash/quote" 
        or skip: "couldn't create backslash/quote test file", 1
    local $ExtUtils::Manifest::MANIFEST = "albatross"
    maniadd:  \%: "foo bar\\baz\'quux" => "backslash and quote" 
    is:  (maniread: )->{"foo bar\\baz\'quux"}, "backslash and quote"
         'backslashed and quoted manifest filename' 
    %funky_files{+'space_quote_backslash'} = "foo bar\\baz\'quux"

my @funky_keys = qw(space space_quote space_backslash space_quote_backslash)
# test including an external manifest.skip file in MANIFEST.SKIP
do
    maniadd: \(%:  foo => undef , albatross => undef
                   'mymanifest.skip' => undef, 'mydefault.skip' => undef)
    add_file: 'mymanifest.skip' => "^foo\n"
    add_file: 'mydefault.skip'  => "^my\n"
    $ExtUtils::Manifest::DEFAULT_MSKIP =
        File::Spec->catfile: $cwd, < qw(mantest mydefault.skip)
    my $skip = File::Spec->catfile: $cwd, < qw(mantest mymanifest.skip)
    add_file: 'MANIFEST.SKIP' =>
              "albatross\n#!include $skip\n#!include_default"
    my (@: $res, $warn) =  catch_warning:  \&skipcheck 
    for (qw(albatross foo foobar mymanifest.skip mydefault.skip))
        like:  $warn, qr/Skipping \b$_\b/
               "Skipping $_" 
    
    (@: $res, $warn) =  catch_warning:  \&mkmanifest 
    for (qw(albatross foo foobar mymanifest.skip mydefault.skip))
        like:  $warn, qr/Removed from MANIFEST: \b$_\b/
               "Removed $_ from MANIFEST" 
    
    my $files = (maniread: )
    ok:  ! exists $files->{albatross}, 'albatross excluded via MANIFEST.SKIP' 
    ok:  exists $files->{yarrow},      'yarrow included in MANIFEST' 
    ok:  exists $files->{bar},         'bar included in MANIFEST' 
    ok:  ! exists $files->{foobar},    'foobar excluded via mymanifest.skip' 
    ok:  ! exists $files->{foo},       'foo excluded via mymanifest.skip' 
    ok:  ! exists $files->{'mymanifest.skip'}
         'mymanifest.skip excluded via mydefault.skip' 
    ok:  ! exists $files->{'mydefault.skip'}
         'mydefault.skip excluded via mydefault.skip' 
    my $extsep = $Is_VMS ?? '_' !! '.'
    for (@: 'MANIFEST', "MANIFEST$($extsep)SKIP")
        %Files{+"$_.bak"}++


add_file: 'MANIFEST'   => 'Makefile.PL'
maniadd: \(%:  foo  => 'bar' )
$files = (maniread: )
# VMS downcases the MANIFEST.  We normalize it here to match.
$files->% = %:  < @+: map: { (@: lc $_ => $files->{?$_}) }, keys $files->% 
my %expect = %:  'makefile.pl' => ''
                 'foo'    => 'bar'
    
is_deeply:  $files, \%expect, 'maniadd() vs MANIFEST without trailing newline'

#add_file('MANIFEST'   => 'Makefile.PL');
#maniadd(\%: foo => 'bar' );

:SKIP do
    chmod:  0400, 'MANIFEST' 
    skip: "Can't make MANIFEST read-only", 2 if -w 'MANIFEST'

    try {
        (maniadd: \(%:  'foo' => 'bar' ));
    }
    is:  $^EVAL_ERROR, '',  "maniadd() won't open MANIFEST if it doesn't need to" 

    try {
        (maniadd: \(%:  'grrrwoof' => 'yippie' ));
    }
    like:  $^EVAL_ERROR->{?description}, qr/^\Qmaniadd() could not open MANIFEST:\E/
           "maniadd() dies if it can't open the MANIFEST" 

    chmod:  0600, 'MANIFEST' 



END 
    is:  (unlink:  < keys %Files ), nkeys %Files, 'remove all added files' 
    remove_dir:  'moretest', 'copy' 

    # now get rid of the parent directory
    ok:  (chdir:  $cwd ), 'return to parent directory' 
    remove_dir:  'mantest' 


