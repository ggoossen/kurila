BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = (@:  '../lib' )
    


#use Pod::Simple::Debug (2);

use Test::More
BEGIN { (plan: tests => 11) };


ok: 1

use Pod::Simple::DumpAsXML
use Pod::Simple::XMLOutStream
print: $^STDOUT, "# Pod::Simple version $Pod::Simple::VERSION\n"
sub e ($x, $y) { (Pod::Simple::DumpAsXML->_duo: $x, $y) }

is:  (Pod::Simple::XMLOutStream->_out: "=head1 =head1")
     '<Document><head1>=head1</head1></Document>'
                             

is:  (Pod::Simple::XMLOutStream->_out: "\n=head1 =head1")
     '<Document><head1>=head1</head1></Document>'
                             

is:  (Pod::Simple::XMLOutStream->_out: "\n=head1 =head1\n")
     '<Document><head1>=head1</head1></Document>'
                             

is:  (Pod::Simple::XMLOutStream->_out: "\n=head1 =head1\n\n")
     '<Document><head1>=head1</head1></Document>'
                             

is:  <e: "\n=head1 =head1\n\n" , "\n=head1 =head1\n\n"

is:  <e: "\n=head1\n=head1\n\n", "\n=head1 =head1\n\n"

is:  <e: "\n=pod\n\nCha cha cha\n\n" , "\n=pod\n\nCha cha cha\n\n"
is:  <e: "\n=pod\n\nCha\tcha  cha\n\n" , "\n=pod\n\nCha cha cha\n\n"
is:  <e: "\n=pod\n\nCha\ncha  cha\n\n" , "\n=pod\n\nCha cha cha\n\n"

print: $^STDOUT, "# Wrapping up... one for the road...\n"
ok: 1
print: $^STDOUT, "# --- Done with ", __FILE__, " --- \n"

