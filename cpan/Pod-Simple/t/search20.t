BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = (@:  '../lib' )
    


use Pod::Simple::Search
use Test::More
BEGIN { (plan: tests => 7) }

print: $^STDOUT, "# ", __FILE__
       ": Testing the scanning of several (well, two) docroots...\n"

my $x = Pod::Simple::Search->new
die: "Couldn't make an object!?" unless ok: defined $x

$x->inc: 0

$x->callback: sub (@< @args)
                  print: $^STDOUT, "#  ", (join: "  ", (map: { "\{$_\}" }, @args)), "\n"
                  return
             

use File::Spec
use Cwd
my $cwd = (cwd: )
print: $^STDOUT, "# CWD: $cwd\n"

sub source_path
    my $file = shift
    if ((env::var: 'PERL_CORE'))
        my $updir = File::Spec->updir
        my $dir = (File::Spec->catdir: $updir, 'lib', 'Pod', 'Simple', 't')
        return (File::Spec->catdir : $dir, $file)
    else 
        return $file
    


my($here1, $here2)
if(        -e ($here1 = (source_path: 'testlib1')))
    die: "But where's $here2?"
        unless -e ($here2 = (source_path: 'testlib2'))
elsif(   -e ($here1 = (File::Spec->catdir: $cwd, 't', 'testlib1'      )))
    die: "But where's $here2?"
        unless -e ($here2 = (File::Spec->catdir: $cwd, 't', 'testlib2'))
else 
    die: "Can't find the test corpora"

print: $^STDOUT, "# OK, found the test corpora\n#  as $here1\n# and $here2\n"
ok: 1

print: $^STDOUT, $x->_state_as_string
#$x->verbose(12);

use Pod::Simple
*pretty = \&Pod::Simple::BlackBox::pretty

print: $^STDOUT, "# OK, starting run...\n# [[\n"
my(@: $name2where, $where2name) = @: ($x->survey: $here1, $here2), $x->path2name
print: $^STDOUT, "# ]]\n#OK, run done.\n"

my $p =( pretty:  $where2name, $name2where )."\n"
$p =~ s/, +/,\n/g
$p =~ s/^/#  /mg
print: $^STDOUT, $p

:SKIP do 
    my $names = join: "|", sort: values $where2name->%
    skip: '-- case may or may not be preserved', 1 if $^OS_NAME eq 'VMS'
    is: $names
        "Blorm|Suzzle|Zonk::Pronk|hinkhonk::Glunk|hinkhonk::Vliff|perlflif|perlthng|perlzuk|squaa|squaa::Glunk|squaa::Vliff|squaa::Wowo|zikzik"


:SKIP do 
    my $names = join: "|", sort: keys $name2where->%
    skip: '-- case may or may not be preserved', 1 if $^OS_NAME eq 'VMS'
    is: $names
        "Blorm|Suzzle|Zonk::Pronk|hinkhonk::Glunk|hinkhonk::Vliff|perlflif|perlthng|perlzuk|squaa|squaa::Glunk|squaa::Vliff|squaa::Wowo|zikzik"


like:  ($name2where->{?'squaa'} || 'huh???'), '/squaa\.pm$/'

is: (nelems: (grep:  { m/squaa\.pm/ }, keys $where2name->%) ), 1

ok: 1

__END__

