BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = (@:  '../lib' )
    


use Test::More
BEGIN { (plan: tests => 19) };

#use Pod::Simple::Debug (6);

ok: 1

use Pod::Simple::DumpAsXML
use Pod::Simple::XMLOutStream
print: $^STDOUT, "# Pod::Simple version $Pod::Simple::VERSION\n"
sub e ($x, $y) { (Pod::Simple::DumpAsXML->_duo: $x, $y) }


print: $^STDOUT, "# Simple tests for head1 - head4...\n"
is:  (Pod::Simple::XMLOutStream->_out: "\n=head1 Chacha\n\n")
     '<Document><head1>Chacha</head1></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "\n=head2 Chacha\n\n")
     '<Document><head2>Chacha</head2></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "\n=head3 Chacha\n\n")
     '<Document><head3>Chacha</head3></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "\n=head4 Chacha\n\n")
     '<Document><head4>Chacha</head4></Document>'
                             

print: $^STDOUT, "# Testing whitespace equivalence...\n"

is:  <e: "\n=head1 Chacha\n\n", "\n=head1       Chacha\n\n"
is:  <e: "\n=head1 Chacha\n\n", "\n=head1\tChacha\n\n"
is:  <e: "\n=head1 Chacha\n\n", "\n=head1\tChacha      \n\n"



is:  (Pod::Simple::XMLOutStream->_out: "=head1     Chachacha")
     '<Document><head1>Chachacha</head1></Document>'
                             


print: $^STDOUT, "# Testing whitespace variance ...\n"
is:  (Pod::Simple::XMLOutStream->_out: "=head1     Cha cha cha   \n")
     '<Document><head1>Cha cha cha</head1></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "=head1     Cha   cha\tcha   \n")
     '<Document><head1>Cha cha cha</head1></Document>'
                             




print: $^STDOUT, "# Testing head2, head3, head4 more...\n"

is:  (Pod::Simple::XMLOutStream->_out: "=head2     Cha   cha\tcha   \n")
     '<Document><head2>Cha cha cha</head2></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "=head3     Cha   cha\tcha   \n")
     '<Document><head3>Cha cha cha</head3></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "=head4     Cha   cha\tcha   \n")
     '<Document><head4>Cha cha cha</head4></Document>'
                             

print: $^STDOUT, "# Testing entity expansion...\n"

is:  (Pod::Simple::XMLOutStream->_out: "=head4 fooE<64>bar!\n")
     (Pod::Simple::XMLOutStream->_out: "\n=head4  foo\@bar!\n\n")
                             

# TODO: a mode so that DumpAsXML can ask for all contiguous string
#  sequences to be fused?
# is( e "=head4 fooE<64>bar!\n", "\n=head4  foo\@bar!\n\n");

print: $^STDOUT, "# Testing formatting sequences...\n"

# True only if the sequences resolve, as they should...
is:  < e: "=head4 C<foobar!>\n", "\n=head4 C<< foobar!    >>\n\n"
is:  < e: "=head4 C<foobar!>\n", "\n\n=head4 C<<<  foobar! >>>\n"
is:  < e: "=head4 C<foobar!>\n", "\n=head4 C<< foobar!\n\t>>\n\n"

print: $^STDOUT, "# Wrapping up... one for the road...\n"
ok: 1
print: $^STDOUT, "# --- Done with ", __FILE__, " --- \n"

