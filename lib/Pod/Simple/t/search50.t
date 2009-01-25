BEGIN {
    if( env::var('PERL_CORE') ) {
        chdir 't';
        use File::Spec;
        $^INCLUDE_PATH = @(File::Spec->rel2abs('../lib') );
    }
}


#sub Pod::Simple::Search::DEBUG () {5};

use Pod::Simple::Search;
use Test::More tests => 6;

print "#  Test the scanning of the whole of \@INC ...\n";

my $x = Pod::Simple::Search->new;
die "Couldn't make an object!?" unless ok defined $x;
ok $x->inc; # make sure inc=1 is the default
print $x->_state_as_string;
#$x->verbose(12);

use Pod::Simple;
*pretty = \&Pod::Simple::BlackBox::pretty;

my $found = 0;
$x->callback(sub {
  print "#  ", join("  ", map "\{$_\}", @_), "\n";
  ++$found;
  return;
});

print "# \@INC == $(join ' ',$^INCLUDE_PATH)\n";

my $t = time();   my $name2where = $x->survey();
$t = time() - $t;
ok $found;

print "# Found $found items in $t seconds!\n# See...\n";

print "# OK, making sure warnings and warnings.pm were in there...\n";
like( ($name2where->{?'warnings'} || 'huh???'), qr/warnings\.(pod|pm)$/);

my  $warningspath = $name2where->{?'warnings'};
if( $warningspath ) {
  my @x = @($x->find('warnings')||'(nil)', $warningspath);
  print "# Comparing \"@x[0]\" to \"@x[1]\"\n";
  for( @x) { s{[/\\]}{/}g; }
  print "#        => \"@x[0]\" to \"@x[1]\"\n";
  is @x[0], @x[1], " find('warnings') should match survey's name2where\{warnings\}";
} else {
  ok 0;  # no 'thatpath/warnings.pm' means can't test find()
}

ok 1;
print "# Byebye from ", __FILE__, "\n";
print "# $(join ' ',$^INCLUDE_PATH)\n";
__END__

