BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = (@:  '../lib' )
    


use Test::More
BEGIN { (plan: tests => 3) };

my $d
#use Pod::Simple::Debug (\$d,0);
#use Pod::Simple::Debug (10);

ok: 1

use Pod::Simple::DumpAsXML
use Pod::Simple::XMLOutStream
print: $^STDOUT, "# Pod::Simple version $Pod::Simple::VERSION\n"
sub e     ($x, $y) { (Pod::Simple::XMLOutStream->_duo: &nowhine, $x, $y) }

sub nowhine
    #  $_[0]->{'no_whining'} = 1;
    @_[0]->accept_targets: "*"


is:  < e: 
         "=begin :foo\n\n=begin :bar\n\nZaz\n\n"
         "=begin :foo\n\n=begin :bar\n\nZaz\n\n=end :bar\n\n=end :foo\n\n"


print: $^STDOUT, "# Ending ", __FILE__, "\n"
ok: 1

__END__


