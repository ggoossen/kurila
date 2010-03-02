BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = (@:  '../lib' )
    


use Pod::Simple::Search
use Test::More
BEGIN { (plan: tests => 7) }

print: $^STDOUT, "# ", __FILE__
       ": Testing the surveying of the current directory...\n"

my $x = Pod::Simple::Search->new
die: "Couldn't make an object!?" unless ok: defined $x

$x->inc: 0

use File::Spec
use Cwd
my $cwd = (cwd: )
print: $^STDOUT, "# CWD: $cwd\n"

sub source_path
    my $file = shift
    if ((env::var: 'PERL_CORE'))
        require File::Spec
        my $updir = File::Spec->updir
        my $dir = (File::Spec->catdir: $updir, 'lib', 'Pod', 'Simple', 't')
        return (File::Spec->catdir : $dir, $file)
    else 
        return $file
    


my $here
if(     -e ($here = (source_path: 'testlib1')))
    chdir $here
elsif(-e ($here = (File::Spec->catdir: $cwd, 't', 'testlib1')))
    chdir $here
else 
    die: "Can't find the test corpus"

print: $^STDOUT, "# OK, found the test corpus as $here\n"
ok: 1

print: $^STDOUT, $x->_state_as_string
#$x->verbose(12);

use Pod::Simple
*pretty = \&Pod::Simple::BlackBox::pretty

my(@: $name2where, $where2name) = @: ($x->survey: '.'), $x->path2name

my $p =( pretty:  $where2name, $name2where )."\n"
$p =~ s/, +/,\n/g
$p =~ s/^/#  /mg
print: $^STDOUT, $p

do 
    my $names = join: "|", sort: values $where2name->%
    is: $names, "Blorm|Zonk::Pronk|hinkhonk::Glunk|hinkhonk::Vliff|perlflif|perlthng|squaa|squaa::Glunk|squaa::Vliff|zikzik"


do 
    my $names = join: "|", sort: keys $name2where->%
    is: $names, "Blorm|Zonk::Pronk|hinkhonk::Glunk|hinkhonk::Vliff|perlflif|perlthng|squaa|squaa::Glunk|squaa::Vliff|zikzik"


like:  ($name2where->{?'squaa'} || 'huh???'), '/squaa\.pm$/'

is: (nelems:  (grep:  { m/squaa\.pm/ }, keys $where2name->%) ), 1

ok: 1

__END__

