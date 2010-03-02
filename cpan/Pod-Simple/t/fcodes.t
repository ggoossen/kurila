BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = (@:  '../lib' )
    


use Test::More
BEGIN { (plan: tests => 18) };

#use Pod::Simple::Debug (5);

ok: 1

use Pod::Simple::DumpAsXML
use Pod::Simple::XMLOutStream
print: $^STDOUT, "# Pod::Simple version $Pod::Simple::VERSION\n"
sub e ($x, $y) { (Pod::Simple::DumpAsXML->_duo: $x, $y) }

print: $^STDOUT, "# With weird leading whitespace...\n"
# With weird whitespace
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nI<foo>\n")
     '<Document><Para><I>foo</I></Para></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nB< foo>\n")
     '<Document><Para><B> foo</B></Para></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nB<\tfoo>\n")
     '<Document><Para><B> foo</B></Para></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nB<\nfoo>\n")
     '<Document><Para><B> foo</B></Para></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nB<foo>\n")
     '<Document><Para><B>foo</B></Para></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nB<foo\t>\n")
     '<Document><Para><B>foo </B></Para></Document>'
                             
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nB<foo\n>\n")
     '<Document><Para><B>foo </B></Para></Document>'
                             


print: $^STDOUT, "#\n# Tests for wedges outside of formatting codes...\n"
is:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nX < 3 and N > 19\n")
     Pod::Simple::XMLOutStream->_out: "=pod\n\nX E<lt> 3 and N E<gt> 19\n"
                             


print: $^STDOUT, "# A complex test with internal whitespace...\n"
ok:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nI<foo>B< bar>C<baz >F< quux\t?>\n")
     '<Document><Para><I>foo</I><B> bar</B><C>baz </C><F> quux ?</F></Para></Document>'
                             


print: $^STDOUT, "# Without any nesting...\n"
ok:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nF<a>C<b>I<c>B<d>X<e>\n")
     '<Document><Para><F>a</F><C>b</C><I>c</I><B>d</B><X>e</X></Para></Document>'
                             

print: $^STDOUT, "# Without any nesting, but with Z's...\n"
ok:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nZ<>F<a>C<b>I<c>B<d>X<e>\n")
     '<Document><Para><F>a</F><C>b</C><I>c</I><B>d</B><X>e</X></Para></Document>'
                             


print: $^STDOUT, "# With lots of nesting, and Z's...\n"
ok:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nZ<>F<C<Z<>foo> I<bar>> B<X<thingZ<>>baz>\n")
     '<Document><Para><F><C>foo</C> <I>bar</I></F> <B><X>thing</X>baz</B></Para></Document>'
                             



print: $^STDOUT, "#\n# *** Now testing different numbers of wedges ***\n"
print: $^STDOUT, "# Without any nesting...\n"
ok:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nF<< a >>C<<< b >>>I<<<< c >>>>B<< d >>X<< e >>\n")
     '<Document><Para><F>a</F><C>b</C><I>c</I><B>d</B><X>e</X></Para></Document>'
                             

print: $^STDOUT, "# Without any nesting, but with Z's, and odder whitespace...\n"
ok:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nF<< aZ<> >>C<<< Z<>b >>>I<<<< c  >>>>B<< d \t >>X<<\ne >>\n")
     '<Document><Para><F>a</F><C>b</C><I>c</I><B>d</B><X>e</X></Para></Document>'
                             

print: $^STDOUT, "# With nesting and Z's, and odder whitespace...\n"
ok:  (Pod::Simple::XMLOutStream->_out: "=pod\n\nF<< aZ<> >>C<<< Z<>bZ<>B<< d \t >>X<<\ne >> >>>I<<<< c  >>>>\n")
     '<Document><Para><F>a</F><C>b<B>d</B><X>e</X></C><I>c</I></Para></Document>'
                             


print: $^STDOUT, "# Misc...\n"
ok:  (Pod::Simple::XMLOutStream->_out: 
                             "=pod\n\nI like I<PIE> with B<cream> and Stuff and N < 3 and X<< things >> hoohah\n"
                                 ."And I<pie is B<also> a happy time>.\n"
                                 ."And B<I<<< I like pie >>>.>\n"
         ) =>
     "<Document><Para>I like <I>PIE</I> with <B>cream</B> and Stuff and N &#60; 3 and <X>things</X> hoohah "
         ."And <I>pie is <B>also</B> a happy time</I>. "
         ."And <B><I>I like pie</I>.</B></Para></Document>"
                             





print: $^STDOUT, "# Wrapping up... one for the road...\n"
ok: 1
print: $^STDOUT, "# --- Done with ", __FILE__, " --- \n"


