BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = (@:  '../lib' )
    


use Test::More
BEGIN { (plan: tests => 20) };

#use Pod::Simple::Debug (6);

ok: 1

use Pod::Simple::DumpAsXML
use Pod::Simple::XMLOutStream

print: $^STDOUT, "# Pod::Simple version $Pod::Simple::VERSION\n"

print: $^STDOUT, "# Pod::Escapes version $Pod::Escapes::VERSION\n"
    if $Pod::Escapes::VERSION
# Presumably that's the library being used


sub e ($x, $y) { (Pod::Simple::DumpAsXML->_duo: $x, $y) }

is:  < (e: "", "") 
is:  < (e: "\n", "",) 


print: $^STDOUT, "# Testing some basic mnemonic E sequences...\n"

is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<lt>2\n")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1<2"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<gt>2\n")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1>2"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<verbar>2\n")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1|2"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<sol>2\n")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1/2\n"
                             


print: $^STDOUT, "# Testing some more mnemonic E sequences...\n"

is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<apos>2\n")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1'2"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<quot>2\n")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1\"2"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1&2")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<amp>2\n"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<eacute>2")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<233>2\n"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<infin>2")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<8734>2\n"
                             

is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<lchevron>2")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<171>2\n"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<rchevron>2")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<187>2\n"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<laquo>2")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<171>2\n"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<raquo>2")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<187>2\n"
                             



print: $^STDOUT, "# Testing numeric E sequences...\n"
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<0101>2\n")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1A2"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<65>2\n")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1A2"
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\n1E<0x41>2\n")
     Pod::Simple::XMLOutStream->_out: "=pod\n\n1A2"
                             



print: $^STDOUT, "# Wrapping up... one for the road...\n"
ok: 1
print: $^STDOUT, "# --- Done with ", __FILE__, " --- \n"


