BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = (@:  '../lib' )
    


use Test::More
BEGIN { (plan: tests => 21) };

#use Pod::Simple::Debug (5);

ok: 1

use Pod::Simple::DumpAsXML
use Pod::Simple::XMLOutStream
print: $^STDOUT, "# Pod::Simple version $Pod::Simple::VERSION\n"
sub e ($x, $y) { (Pod::Simple::DumpAsXML->_duo: < @_) }

my $x = 'Pod::Simple::XMLOutStream'
$Pod::Simple::XMLOutStream::ATTR_PAD   = ' '
$Pod::Simple::XMLOutStream::SORT_ATTRS = 1 # for predictably testable output


sub moj     {(shift->accept_target:         'mojojojo')}
sub mojtext {(shift->accept_target_as_text: 'mojojojo')}
sub any     {(shift->accept_target:         '*'       )}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

is:  ($x->_out:  "=pod\n\nI like pie.\n\n=for mojojojo stuff\n\n=for !mojojojo bzarcho\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target="!mojojojo" target_matching="!"><Data xml:space="preserve">bzarcho</Data></for><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  "=pod\n\nI like pie.\n\n=for psketti,mojojojo,crunk stuff\n\n=for !psketti,mojojojo,crunk bzarcho\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target="!psketti,mojojojo,crunk" target_matching="!"><Data xml:space="preserve">bzarcho</Data></for><Para>Yup.</Para></Document>'
    

is:  ($x->_out:  "=pod\n\nI like pie.\n\n=for :mojojojo stuff\n\n=for :!mojojojo bzarcho\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target=":!mojojojo" target_matching="!"><Para>bzarcho</Para></for><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  "=pod\n\nI like pie.\n\n=for :psketti,mojojojo,crunk stuff\n\n=for :!psketti,mojojojo,crunk bzarcho\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target=":!psketti,mojojojo,crunk" target_matching="!"><Para>bzarcho</Para></for><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  "=pod\n\nI like pie.\n\n=for :mojojojo stuff\n\n=for :!mojojojo I<bzarcho>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target=":!mojojojo" target_matching="!"><Para><I>bzarcho</I></Para></for><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  "=pod\n\nI like pie.\n\n=for :psketti,mojojojo,crunk stuff\n\n=for :!psketti,mojojojo,crunk I<bzarcho>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target=":!psketti,mojojojo,crunk" target_matching="!"><Para><I>bzarcho</I></Para></for><Para>Yup.</Para></Document>'
    


print: $^STDOUT, "#   ( Now just swapping '!' and ':' )\n"
is:  ($x->_out:  "=pod\n\nI like pie.\n\n=for :mojojojo stuff\n\n=for !:mojojojo bzarcho\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target="!:mojojojo" target_matching="!"><Para>bzarcho</Para></for><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  "=pod\n\nI like pie.\n\n=for :psketti,mojojojo,crunk stuff\n\n=for !:psketti,mojojojo,crunk bzarcho\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target="!:psketti,mojojojo,crunk" target_matching="!"><Para>bzarcho</Para></for><Para>Yup.</Para></Document>'
    


print: $^STDOUT, "# Testing accept_target ...\n"

is:  ($x->_out:  &moj, "=pod\n\nI like pie.\n\n=for !mojojojo I<stuff>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  &moj, "=pod\n\nI like pie.\n\n=for !psketti,mojojojo,crunk I<stuff>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  &moj, "=pod\n\nI like pie.\n\n=for :!mojojojo I<stuff>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><Para>Yup.</Para></Document>'
    

print: $^STDOUT, "# Testing accept_target_as_text ...\n"

is:  ($x->_out:  &mojtext, "=pod\n\nI like pie.\n\n=for !mojojojo I<stuff>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  &mojtext, "=pod\n\nI like pie.\n\n=for !psketti,mojojojo,crunk I<stuff>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  &mojtext, "=pod\n\nI like pie.\n\n=for :!mojojojo I<stuff>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><Para>Yup.</Para></Document>'
    


print: $^STDOUT, "# Testing accept_target(*) ...\n"

is:  ($x->_out:  &any, "=pod\n\nI like pie.\n\n=for !mojojojo I<stuff>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target="!mojojojo" target_matching="!"><Data xml:space="preserve">I&#60;stuff&#62;</Data></for><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  &any, "=pod\n\nI like pie.\n\n=for !mojojojo I<stuff>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target="!mojojojo" target_matching="!"><Data xml:space="preserve">I&#60;stuff&#62;</Data></for><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  &any, "=pod\n\nI like pie.\n\n=for !psketti,mojojojo,crunk I<stuff>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target="!psketti,mojojojo,crunk" target_matching="!"><Data xml:space="preserve">I&#60;stuff&#62;</Data></for><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  &any, "=pod\n\nI like pie.\n\n=for !:mojojojo I<stuff>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target="!:mojojojo" target_matching="!"><Para><I>stuff</I></Para></for><Para>Yup.</Para></Document>'
    
is:  ($x->_out:  &any, "=pod\n\nI like pie.\n\n=for !:psketti,mojojojo,crunk I<stuff>\n\nYup.\n")
     '<Document><Para>I like pie.</Para><for target="!:psketti,mojojojo,crunk" target_matching="!"><Para><I>stuff</I></Para></for><Para>Yup.</Para></Document>'
    


print: $^STDOUT, "# Wrapping up... one for the road...\n"
ok: 1
print: $^STDOUT, "# --- Done with ", __FILE__, " --- \n"

