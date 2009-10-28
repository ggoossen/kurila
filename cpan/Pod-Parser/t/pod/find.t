# Testing of Pod::Find
# Author: Marek Rouchal <marek@saftsack.fs.uni-bayreuth.de>

$^OUTPUT_AUTOFLUSH = 1

use Test::More

BEGIN 
    plan: tests => 4
    use File::Spec


use Pod::Find < qw(pod_find pod_where)
use File::Spec

# load successful
ok: 1

require Cwd
my $THISDIR = (Cwd::cwd: )
my $VERBOSE = (env::var: 'PERL_CORE') ?? 0 !! ((env::var: 'TEST_VERBOSE') || 0)
my $lib_dir = 'File::Spec'->catdir: 't', 'pod', 'testpods', 'lib'
our $Qlib_dir
if ($^OS_NAME eq 'VMS')
    $lib_dir = VMS::Filespec::unixify:  <('File::Spec'->catdir: 't', 'pod', 'testpods', 'lib')
    $Qlib_dir = $lib_dir
    $Qlib_dir =~ s#\/#::#g


print: $^STDOUT, "### searching $lib_dir\n"
my %pods = %:  < pod_find: $lib_dir 
my $result = join: ',', (sort: values %pods)
print: $^STDOUT, "### found $result\n"
my $compare = (env::var: 'PERL_CORE') ??
    join: ',', sort: qw(
    Pod::Stuff
)
    !! join: ',', sort: qw(
    Pod::Checker
    Pod::Find
    Pod::InputObjects
    Pod::ParseUtils
    Pod::Parser
    Pod::PlainText
    Pod::Select
    Pod::Usage
)
if ($^OS_NAME eq 'VMS')
    $compare = lc: $compare
    my $undollared = $Qlib_dir
    $undollared =~ s/\$/\\\$/g
    $undollared =~ s/\-/\\\-/g
    $result =~ s/$undollared/pod::/g
    $result =~ s/\$//g
    my $count = 0
    my @result = split: m/,/,$result
    my @compare = split: m/,/,$compare
    foreach( @compare)
        $count += grep: {m/$_/}, @result
    
    is: $count/(((nelems @result)-1)+1)-1,((nelems @compare)-1)
elsif (('File::Spec'->case_tolerant: ) || $^OS_NAME eq 'dos')
    is: lc $result,lc $compare
else
    is: $result,$compare


print: $^STDOUT, "### searching for File::Find\n"
$result = pod_where: \(%:  inc => 1, verbose => $VERBOSE ), 'File::Find'
    || 'undef - pod not found!'
print: $^STDOUT, "### found $result\n"

require Config
if ($^OS_NAME eq 'VMS') # privlib is perl_root:[lib] OK but not under mms
    $compare = "lib.File]Find.pm"
    $result =~ s/perl_root:\[\-?\.?//i
    $result =~ s/\[\-?\.?//i # needed under `mms test`
    is: $result,$compare
else
    $compare = 'File::Spec'->catfile:  (File::Spec->updir: ), ('File::Spec'->updir: ), 'lib','File','Find.pm'
    is: (_canon: $result),(_canon: $compare)

# Search for a documentation pod rather than a module
my $searchpod = 'Stuff'
print: $^STDOUT, "### searching for $searchpod.pod\n"
$result = pod_where: 
  \(%:  dirs => \(@: ('File::Spec'->catdir: 't', 'pod', 'testpods', 'lib', 'Pod') )
        verbose => $VERBOSE ), $searchpod
    || "undef - $searchpod.pod not found!"
print: $^STDOUT, "### found $result\n"

$compare = 'File::Spec'->catfile:  't', 'pod', 'testpods', 'lib', 'Pod' ,'Stuff.pm'
is: (_canon: $result),(_canon: $compare)

# make the path as generic as possible
sub _canon
    my (@: $path) =  @_
    $path = 'File::Spec'->canonpath: $path
    my @comp = 'File::Spec'->splitpath: $path
    my @dir = 'File::Spec'->splitdir: @comp[1]
    @comp[1] = 'File::Spec'->catdir: < @dir
    $path = 'File::Spec'->catpath: < @comp
    $path = (uc: $path) if 'File::Spec'->case_tolerant: 
    print: $^STDOUT, "### general path: $path\n" if $VERBOSE
    $path


