BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        use File::Spec;
        $^INCLUDE_PATH = (@: (File::Spec->rel2abs: '../lib') )
    



#sub Pod::Simple::Search::DEBUG () {5};

use Pod::Simple::Search
use Test::More tests => 6

print: $^STDOUT, "#  Test the scanning of the whole of \$^INCLUDE_PATH ...\n"

my $x = Pod::Simple::Search->new: 
die: "Couldn't make an object!?" unless ok: defined $x
ok: $x->inc:  # make sure inc=1 is the default
print: $^STDOUT, $x->_state_as_string: 
#$x->verbose(12);

use Pod::Simple
*pretty = \&Pod::Simple::BlackBox::pretty

my $found = 0
$x->callback: sub (@< @args)
                  print: $^STDOUT, "#  ", (join: "  ", (map: { "\{$_\}" }, @args)), "\n"
                  ++$found
                  return
             

print: $^STDOUT, "# \$^INCLUDE_PATH == $((join: ' ',$^INCLUDE_PATH))\n"

my $t = time: ;   my $name2where = $x->survey: 
$t = (time: ) - $t
ok: $found

print: $^STDOUT, "# Found $found items in $t seconds!\n# See...\n"

print: $^STDOUT, "# OK, making sure warnings and warnings.pm were in there...\n"
like:  ($name2where->{?'warnings'} || 'huh???'), qr/warnings\.(pod|pm)$/

my  $warningspath = $name2where->{?'warnings'}
if( $warningspath )
    my @x = (@: ($x->find: 'warnings')||'(nil)', $warningspath)
    print: $^STDOUT, "# Comparing \"@x[0]\" to \"@x[1]\"\n"
    for( @x) { s{[/\\]}{/}g; }
    print: $^STDOUT, "#        => \"@x[0]\" to \"@x[1]\"\n"
    is: @x[0], @x[1], " find('warnings') should match survey's name2where\{warnings\}"
else 
    ok: 0  # no 'thatpath/warnings.pm' means can't test find()


ok: 1
print: $^STDOUT, "# Byebye from ", __FILE__, "\n"
print: $^STDOUT, "# $((join: ' ',$^INCLUDE_PATH))\n"
__END__

