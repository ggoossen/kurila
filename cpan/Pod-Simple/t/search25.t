
#sub Pod::Simple::Search::DEBUG () {5};

use Pod::Simple::Search
use Test::More tests => 10

print: $^STDOUT, "# ", __FILE__
       ": Testing limit_glob ...\n"

my $x = Pod::Simple::Search->new: 
die: "Couldn't make an object!?" unless ok: defined $x

$x->inc: 0
$x->shadows: 1

use File::Spec
use Cwd
my $cwd = (cwd: )
print: $^STDOUT, "# CWD: $cwd\n"
my $dir
sub source_path
    my $file = shift
    if ((env::var: 'PERL_CORE'))
        my $updir = File::Spec->updir: 
        $dir = File::Spec->catdir: $updir, 'lib', 'Pod', 'Simple', 't'
        return File::Spec->catdir : $dir, $file
    else
        return $file
    


my($here1, $here2, $here3)

if(        -e ($here1 = (source_path:  'testlib1'      )))
    die: "But where's $here2?"
        unless -e ($here2 = (source_path:  'testlib2'))
    die: "But where's $here3?"
        unless -e ($here3 = (source_path:  'testlib3'))

elsif(   -e ($here1 = (File::Spec->catdir: $cwd, 't', 'testlib1'      )))
    die: "But where's $here2?"
        unless -e ($here2 = (File::Spec->catdir: $cwd, 't', 'testlib2'))
    die: "But where's $here3?"
        unless -e ($here3 = (File::Spec->catdir: $cwd, 't', 'testlib3'))

else
    die: "Can't find the test corpora: $dir"

print: $^STDOUT, "# OK, found the test corpora\n#  as $here1\n# and $here2\n# and $here3\n#\n"
ok: 1

print: $^STDOUT, $x->_state_as_string: 
#$x->verbose(12);

use Pod::Simple
*pretty = \&Pod::Simple::BlackBox::pretty

my $glob = 'squaa::*'
print: $^STDOUT, "# Limiting to $glob\n"
$x->limit_glob: $glob

my(@: $name2where, $where2name) = @: ($x->survey: $here1, $here2, $here3), $x->path2name: 

my $p =( pretty:  $where2name, $name2where )."\n"
$p =~ s/, +/,\n/g
$p =~ s/^/#  /mg
print: $^STDOUT, $p

do
    my $names = join: "|", sort: keys $name2where->%
    is: $names, "squaa::Glunk|squaa::Vliff|squaa::Wowo"


do
    my $names = join: "|", sort: values $where2name->%
    is: $names, "squaa::Glunk|squaa::Vliff|squaa::Vliff|squaa::Vliff|squaa::Wowo"

    my %count
    for(values $where2name->%) { ++%count{+$_} };
    #print pretty(\%count), "\n\n";
    delete %count{[ (grep: { %count{?$_} +< 2 }, keys %count) ]}
    my $shadowed = join: "|", sort: keys %count
    is: $shadowed, "squaa::Vliff"

    sub thar { (print: $^STDOUT, "# Seen @_[0] :\n", < (map: { "#  \{$_\}\n" }, (sort: (grep: { $where2name->{?$_} eq @_[0] },keys $where2name->%)))); return; }

    is: %count{?'squaa::Vliff'}, 3
    thar: 'squaa::Vliff'



ok: ! $name2where->{?'squaa'}  # because squaa.pm isn't squaa::*

like:  ($name2where->{?'squaa::Vliff'} || 'huh???'), qr/[^\^]testlib1/ 

like:  ($name2where->{?'squaa::Wowo'}  || 'huh???'), qr/testlib2/ 


print: $^STDOUT, "# OK, bye from ", __FILE__, "\n"
ok: 1

__END__

