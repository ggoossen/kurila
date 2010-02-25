BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = (@:  '../lib' )
    


use Test::More
BEGIN { (plan: tests => 11) };

#use Pod::Simple::Debug (6);

print: $^STDOUT, "# Hi, I'm ", __FILE__, "\n"
ok: 1

use Pod::Simple
use Pod::Simple::DumpAsXML
use Pod::Simple::XMLOutStream
print: $^STDOUT, "# Pod::Simple version $Pod::Simple::VERSION\n"
sub e ($x, $y) { (Pod::Simple::DumpAsXML->_duo: $x, $y) }

is:  < (e: "", "") 
is:  < (e: "\n", "",) 

die: unless ok:  ! ! (Pod::Simple::XMLOutStream->can: 'fullstop_space_harden')
sub harden { @_[0]->fullstop_space_harden: 1 }

print: $^STDOUT, "# Test that \".  \" always compacts without the hardening on...\n"

is:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\nShe set me a message about the M.D.  I\ncalled back!\n")
     qq{<Document><Para>She set me a message about the M.D. I called back!</Para></Document>}
                             
is:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\nShe set me a message about the M.D. I called back!\n")
     qq{<Document><Para>She set me a message about the M.D. I called back!</Para></Document>}
                             
is:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\nShe set me a message about the M.D.\nI called back!\n")
     qq{<Document><Para>She set me a message about the M.D. I called back!</Para></Document>}
                             


print: $^STDOUT, "# Now testing with the hardening on...\n"

is:  (Pod::Simple::XMLOutStream->_out: &harden, "\n=pod\n\nShe set me a message about the M.D.  I\ncalled back!\n")
     qq{<Document><Para>She set me a message about the M.D.&#160; I called back!</Para></Document>}
                             
is:  (Pod::Simple::XMLOutStream->_out: &harden, "\n=pod\n\nShe set me a message about the M.D. I called back!\n")
     qq{<Document><Para>She set me a message about the M.D. I called back!</Para></Document>}
                             
is:  (Pod::Simple::XMLOutStream->_out: &harden, "\n=pod\n\nShe set me a message about the M.D.\nI called back!\n")
     qq{<Document><Para>She set me a message about the M.D. I called back!</Para></Document>}
                             


print: $^STDOUT, "# Byebye\n"
ok: 1

