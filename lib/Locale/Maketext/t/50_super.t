
#sub Locale::Maketext::DEBUG () {10}
use Locale::Maketext;

use Test::More;
BEGIN { plan tests => 26 };
print $^STDOUT, "#\n# Testing tight insertion of super-ordinate language tags...\n#\n";

my @in = grep { m/\S/ }, split m/[\n\r]/, q{
 NIX => NIX
  sv => sv
  en => en
 hai => hai

          pt-br => pt-br pt
       pt-br fr => pt-br pt fr
    pt-br fr pt => pt-br fr pt

 pt-br fr pt de => pt-br fr pt de
 de pt-br fr pt => de pt-br fr pt
    de pt-br fr => de pt-br pt fr
   hai pt-br fr => hai pt-br pt fr

 # Now test multi-part complicateds:
          pt-br-janeiro => pt-br-janeiro pt-br pt
       pt-br-janeiro fr => pt-br-janeiro pt-br pt fr
    pt-br-janeiro de fr => pt-br-janeiro pt-br pt de fr
 pt-br-janeiro de pt fr => pt-br-janeiro pt-br de pt fr

          pt-br-janeiro pt-br-saopaolo => pt-br-janeiro pt-br pt pt-br-saopaolo
       pt-br-janeiro fr pt-br-saopaolo => pt-br-janeiro pt-br pt fr pt-br-saopaolo
    pt-br-janeiro de pt-br-saopaolo fr => pt-br-janeiro pt-br pt de pt-br-saopaolo fr
    pt-br-janeiro de pt-br fr pt-br-saopaolo => pt-br-janeiro de pt-br pt fr pt-br-saopaolo

 pt-br de en fr pt-br-janeiro => pt-br pt de en fr pt-br-janeiro
 pt-br de en fr               => pt-br pt de en fr

    ja    pt-br-janeiro fr => ja pt-br-janeiro pt-br pt fr
    ja pt-br-janeiro de fr => ja pt-br-janeiro pt-br pt de fr
 ja pt-br-janeiro de pt fr => ja pt-br-janeiro pt-br de pt fr

 pt-br-janeiro de pt-br fr => pt-br-janeiro de pt-br pt fr
# an odd case, since we don't filter for uniqueness in this sub
 
};

sub uniq { my %seen; return grep( {!(%seen{+$_}++) }, @_); }

foreach my $in ( @in) {
  $in =~ s/^\s+//s;
  $in =~ s/\s+$//s;
  $in =~ s/#.+//s;
  next unless $in =~ m/\S/;
  
  my(@in, @should);
  do {
    die "What kind of line is <$in>?!"
     unless $in =~ m/^(.+)=>(.+)$/s;
  
    my@($i,$s) = @($1, $2);
    @in     = @($i =~ m/(\S+)/g);
    @should = @($s =~ m/(\S+)/g);
    #print "{@in}{@should}\n";
  };
  my @out = uniq( < Locale::Maketext->_add_supers(
    ("$(join ' ',@in)" eq 'NIX') ?? () !! < @in
  ) );
  #print "O: ", join(' ', map "<$_>", @out), "\n";
  @out = @( 'NIX' ) unless (nelems @out);

  
  if( (nelems @out) == nelems @should
      and lc( join "\e", @out ) eq lc( join "\e", @should )
  ) {
    print $^STDOUT, "#     Happily got [$(join ' ',@out)] from [$in]\n";
    ok 1;
  } else {
    ok 0;
    print $^STDOUT, "#!!Got:         [$(join ' ',@out)]\n",
          "#!! but wanted: [$(join ' ',@should)]\n",
          "#!! from \"$in\"\n#\n";
  }
}

print $^STDOUT, "#\n#\n# Bye-bye!\n";
ok 1;

