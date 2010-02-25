BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = (@:  '../lib' )
    


use Test::More tests => 99

#use Pod::Simple::Debug (10);

ok: 1

use Pod::Simple::DumpAsXML
use Pod::Simple::XMLOutStream
print: $^STDOUT, "# Pod::Simple version $Pod::Simple::VERSION\n"
sub e ($x, $y) { (Pod::Simple::DumpAsXML->_duo: $x, $y) }
my $x = 'Pod::Simple::XMLOutStream'

print: $^STDOUT, "##### Testing L codes via x class $x...\n"

$Pod::Simple::XMLOutStream::ATTR_PAD   = ' '
$Pod::Simple::XMLOutStream::SORT_ATTRS = 1 # for predictably testable output

print: $^STDOUT, "# Simple/moderate L<stuff> tests...\n"

is: ($x->_out: qq{=pod\n\nL<Net::Ping>\n})
    '<Document><Para><L content-implicit="yes" to="Net::Ping" type="pod">Net::Ping</L></Para></Document>'
   

is: ($x->_out: qq{=pod\n\nL<crontab(5)>\n})
    '<Document><Para><L content-implicit="yes" to="crontab(5)" type="man">crontab(5)</L></Para></Document>'
   

is:  ($x->_out: qq{=pod\n\nL<Net::Ping/Ping-pong>\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-pong&#34; in Net::Ping</L></Para></Document>'
    

is:  ($x->_out: qq{=pod\n\nL<Net::Ping/"Ping-pong">\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-pong&#34; in Net::Ping</L></Para></Document>'
    

is:  ($x->_out: qq{=pod\n\nL</"Object Methods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL</Object Methods>\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<"Object Methods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    


print: $^STDOUT, "# Complex L<stuff> tests...\n"
print: $^STDOUT, "#  Ents in the middle...\n"

is: ($x->_out: qq{=pod\n\nL<Net::Ping>\n})
    '<Document><Para><L content-implicit="yes" to="Net::Ping" type="pod">Net::Ping</L></Para></Document>'
   
is:  ($x->_out: qq{=pod\n\nL<Net::Ping/Ping-E<112>ong>\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-pong&#34; in Net::Ping</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<Net::Ping/"Ping-E<112>ong">\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-pong&#34; in Net::Ping</L></Para></Document>'
    

is:  ($x->_out: qq{=pod\n\nL</"Object E<77>ethods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL</Object E<77>ethods>\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<"Object E<77>ethods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    



print: $^STDOUT, "#  Ents in the middle and at the start...\n"

is: ($x->_out: qq{=pod\n\nL<E<78>et::Ping>\n})
    '<Document><Para><L content-implicit="yes" to="Net::Ping" type="pod">Net::Ping</L></Para></Document>'
   
is:  ($x->_out: qq{=pod\n\nL<E<78>et::Ping/Ping-E<112>ong>\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-pong&#34; in Net::Ping</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<E<78>et::Ping/"Ping-E<112>ong">\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-pong&#34; in Net::Ping</L></Para></Document>'
    

is:  ($x->_out: qq{=pod\n\nL</"E<79>bject E<77>ethods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL</E<79>bject E<77>ethods>\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<"E<79>bject E<77>ethods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    


print: $^STDOUT, "#  Ents in the middle and at the start and at the end...\n"

is: ($x->_out: qq{=pod\n\nL<E<78>et::PinE<103>>\n})
    '<Document><Para><L content-implicit="yes" to="Net::Ping" type="pod">Net::Ping</L></Para></Document>'
   
is:  ($x->_out: qq{=pod\n\nL<E<78>et::PinE<103>/Ping-E<112>onE<103>>\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-pong&#34; in Net::Ping</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<E<78>et::PinE<103>/"Ping-E<112>onE<103>">\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-pong&#34; in Net::Ping</L></Para></Document>'
    

is:  ($x->_out: qq{=pod\n\nL</"E<79>bject E<77>ethodE<115>">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL</E<79>bject E<77>ethodE<115>>\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<"E<79>bject E<77>ethodE<115>">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    


print: $^STDOUT, "# Even more complex L<stuff> tests...\n"


print: $^STDOUT, "#  Ents in the middle...\n"

is: ($x->_out: qq{=pod\n\nL<Net::Ping>\n})
    '<Document><Para><L content-implicit="yes" to="Net::Ping" type="pod">Net::Ping</L></Para></Document>'
   
is:  ($x->_out: qq{=pod\n\nL<Net::Ping/Ping-E<112>ong>\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-pong&#34; in Net::Ping</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<Net::Ping/"Ping-E<112>ong">\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-pong&#34; in Net::Ping</L></Para></Document>'
    

is:  ($x->_out: qq{=pod\n\nL</"Object E<77>ethods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL</Object E<77>ethods>\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<"Object E<77>ethods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;Object Methods&#34;</L></Para></Document>'
    


###########################################################################

print: $^STDOUT, "# VERY complex L sequences...\n"
print: $^STDOUT, "#  Ents in the middle and at the start...\n"


is: ($x->_out: qq{=pod\n\nL<Net::Ping>\n})
    '<Document><Para><L content-implicit="yes" to="Net::Ping" type="pod">Net::Ping</L></Para></Document>'
   
is:  ($x->_out: qq{=pod\n\nL<Net::Ping/Ping-B<E<112>ong>>\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-<B>pong</B>&#34; in Net::Ping</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<Net::Ping/"Ping-B<E<112>ong>">\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-<B>pong</B>&#34; in Net::Ping</L></Para></Document>'
    

is:  ($x->_out: qq{=pod\n\nL</"B<Object> E<77>ethods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;<B>Object</B> Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL</B<Object> E<77>ethods>\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;<B>Object</B> Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<"B<Object> E<77>ethods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;<B>Object</B> Methods&#34;</L></Para></Document>'
    



print: $^STDOUT, "#  Ents in the middle and at the start...\n"

is: ($x->_out: qq{=pod\n\nL<E<78>et::Ping>\n})
    '<Document><Para><L content-implicit="yes" to="Net::Ping" type="pod">Net::Ping</L></Para></Document>'
   
is:  ($x->_out: qq{=pod\n\nL<E<78>et::Ping/Ping-B<E<112>ong>>\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-<B>pong</B>&#34; in Net::Ping</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<E<78>et::Ping/"Ping-B<E<112>ong>">\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-<B>pong</B>&#34; in Net::Ping</L></Para></Document>'
    

is:  ($x->_out: qq{=pod\n\nL</"B<E<79>bject> E<77>ethods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;<B>Object</B> Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL</B<E<79>bject> E<77>ethods>\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;<B>Object</B> Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<"B<E<79>bject> E<77>ethods">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;<B>Object</B> Methods&#34;</L></Para></Document>'
    


print: $^STDOUT, "#  Ents in the middle and at the start and at the end...\n"

is: ($x->_out: qq{=pod\n\nL<E<78>et::PinE<103>>\n})
    '<Document><Para><L content-implicit="yes" to="Net::Ping" type="pod">Net::Ping</L></Para></Document>'
   
is:  ($x->_out: qq{=pod\n\nL<E<78>et::PinE<103>/Ping-B<E<112>onE<103>>>\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-<B>pong</B>&#34; in Net::Ping</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<E<78>et::PinE<103>/"Ping-B<E<112>onE<103>>">\n})
     '<Document><Para><L content-implicit="yes" section="Ping-pong" to="Net::Ping" type="pod">&#34;Ping-<B>pong</B>&#34; in Net::Ping</L></Para></Document>'
    

is:  ($x->_out: qq{=pod\n\nL</"B<E<79>bject> E<77>ethodE<115>">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;<B>Object</B> Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL</B<E<79>bject> E<77>ethodE<115>>\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;<B>Object</B> Methods&#34;</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<"B<E<79>bject> E<77>ethodE<115>">\n})
     '<Document><Para><L content-implicit="yes" section="Object Methods" type="pod">&#34;<B>Object</B> Methods&#34;</L></Para></Document>'
    


###########################################################################

print: $^STDOUT, "#\n# L<url> tests...\n"

is:  ($x->_out: qq{=pod\n\nL<news:comp.lang.perl.misc>\n})
     '<Document><Para><L content-implicit="yes" to="news:comp.lang.perl.misc" type="url">news:comp.lang.perl.misc</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<http://www.perl.com>\n})
     '<Document><Para><L content-implicit="yes" to="http://www.perl.com" type="url">http://www.perl.com</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<http://www.perl.com/CPAN/authors/id/S/SB/SBURKE/>\n})
     '<Document><Para><L content-implicit="yes" to="http://www.perl.com/CPAN/authors/id/S/SB/SBURKE/" type="url">http://www.perl.com/CPAN/authors/id/S/SB/SBURKE/</L></Para></Document>'
    

print: $^STDOUT, "# L<url> tests with entities...\n"

is:  ($x->_out: qq{=pod\n\nL<news:compE<46>lang.perl.misc>\n})
     '<Document><Para><L content-implicit="yes" to="news:comp.lang.perl.misc" type="url">news:comp.lang.perl.misc</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<http://wwwE<46>perl.com>\n})
     '<Document><Para><L content-implicit="yes" to="http://www.perl.com" type="url">http://www.perl.com</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<http://wwwE<46>perl.com/CPAN/authors/id/S/SB/SBURKE/>\n})
     '<Document><Para><L content-implicit="yes" to="http://www.perl.com/CPAN/authors/id/S/SB/SBURKE/" type="url">http://www.perl.com/CPAN/authors/id/S/SB/SBURKE/</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<http://wwwE<46>perl.com/CPAN/authors/id/S/SB/SBURKEE<47>>\n})
     '<Document><Para><L content-implicit="yes" to="http://www.perl.com/CPAN/authors/id/S/SB/SBURKE/" type="url">http://www.perl.com/CPAN/authors/id/S/SB/SBURKE/</L></Para></Document>'
    


###########################################################################


print: $^STDOUT, "# L<text|stuff> tests...\n"

is: ($x->_out: qq{=pod\n\nL<things|crontab(5)>\n})
    '<Document><Para><L to="crontab(5)" type="man">things</L></Para></Document>'
   
is: ($x->_out: qq{=pod\n\nL<things|crontab(5)/ENVIRONMENT>\n})
    '<Document><Para><L section="ENVIRONMENT" to="crontab(5)" type="man">things</L></Para></Document>'
   
is: ($x->_out: qq{=pod\n\nL<things|crontab(5)/"ENVIRONMENT">\n})
    '<Document><Para><L section="ENVIRONMENT" to="crontab(5)" type="man">things</L></Para></Document>'
   

is:  ($x->_out: qq{=pod\n\nL<Perl Error Messages|perldiag>\n})
     '<Document><Para><L to="perldiag" type="pod">Perl Error Messages</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<Perl\nError\nMessages|perldiag>\n})
     '<Document><Para><L to="perldiag" type="pod">Perl Error Messages</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<Perl\nError\t  Messages|perldiag>\n})
     '<Document><Para><L to="perldiag" type="pod">Perl Error Messages</L></Para></Document>'
    


is:  ($x->_out: qq{=pod\n\nL<SWITCH statements|perlsyn/"Basic BLOCKs and Switch Statements">\n})
     '<Document><Para><L section="Basic BLOCKs and Switch Statements" to="perlsyn" type="pod">SWITCH statements</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<SWITCH statements|perlsyn/Basic BLOCKs and Switch Statements>\n})
     '<Document><Para><L section="Basic BLOCKs and Switch Statements" to="perlsyn" type="pod">SWITCH statements</L></Para></Document>'
    


is:  ($x->_out: qq{=pod\n\nL<the various attributes|/"Member Data">\n})
     '<Document><Para><L section="Member Data" type="pod">the various attributes</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<the various attributes|/Member Data>\n})
     '<Document><Para><L section="Member Data" type="pod">the various attributes</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<the various attributes|"Member Data">\n})
     '<Document><Para><L section="Member Data" type="pod">the various attributes</L></Para></Document>'
    


print: $^STDOUT, "#\n# Now some very complex L<text|stuff> tests...\n"


is:  ($x->_out: qq{=pod\n\nL<Perl B<Error E<77>essages>|perldiag>\n})
     '<Document><Para><L to="perldiag" type="pod">Perl <B>Error Messages</B></L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<Perl\nB<Error\nE<77>essages>|perldiag>\n})
     '<Document><Para><L to="perldiag" type="pod">Perl <B>Error Messages</B></L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<Perl\nB<Error\t  E<77>essages>|perldiag>\n})
     '<Document><Para><L to="perldiag" type="pod">Perl <B>Error Messages</B></L></Para></Document>'
    


is:  ($x->_out: qq{=pod\n\nL<SWITCH B<E<115>tatements>|perlsyn/"Basic I<BLOCKs> and Switch StatementE<115>">\n})
     '<Document><Para><L section="Basic BLOCKs and Switch Statements" to="perlsyn" type="pod">SWITCH <B>statements</B></L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<SWITCH B<E<115>tatements>|perlsyn/Basic I<BLOCKs> and Switch StatementE<115>>\n})
     '<Document><Para><L section="Basic BLOCKs and Switch Statements" to="perlsyn" type="pod">SWITCH <B>statements</B></L></Para></Document>'
    


is:  ($x->_out: qq{=pod\n\nL<the F<various> attributes|/"Member Data">\n})
     '<Document><Para><L section="Member Data" type="pod">the <F>various</F> attributes</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<the F<various> attributes|/Member Data>\n})
     '<Document><Para><L section="Member Data" type="pod">the <F>various</F> attributes</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<the F<various> attributes|"Member Data">\n})
     '<Document><Para><L section="Member Data" type="pod">the <F>various</F> attributes</L></Para></Document>'
    


print: $^STDOUT, "#\n# Now some very complex L<text|stuff> tests with variant syntax...\n"


is:  ($x->_out: qq{=pod\n\nL<< Perl B<<< Error E<77>essages >>>|perldiag >>\n})
     '<Document><Para><L to="perldiag" type="pod">Perl <B>Error Messages</B></L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<< Perl\nB<<< Error\nE<77>essages >>>|perldiag >>\n})
     '<Document><Para><L to="perldiag" type="pod">Perl <B>Error Messages</B></L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<< Perl\nB<<< Error\t  E<77>essages >>>|perldiag >>\n})
     '<Document><Para><L to="perldiag" type="pod">Perl <B>Error Messages</B></L></Para></Document>'
    


is:  ($x->_out: qq{=pod\n\nL<< SWITCH B<<< E<115>tatements >>>|perlsyn/"Basic I<<<< BLOCKs >>>> and Switch StatementE<115>" >>\n})
     '<Document><Para><L section="Basic BLOCKs and Switch Statements" to="perlsyn" type="pod">SWITCH <B>statements</B></L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<< SWITCH B<<< E<115>tatements >>>|perlsyn/Basic I<<<< BLOCKs >>>> and Switch StatementE<115> >>\n})
     '<Document><Para><L section="Basic BLOCKs and Switch Statements" to="perlsyn" type="pod">SWITCH <B>statements</B></L></Para></Document>'
    


is:  ($x->_out: qq{=pod\n\nL<<< the F<< various >> attributes|/"Member Data" >>>\n})
     '<Document><Para><L section="Member Data" type="pod">the <F>various</F> attributes</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<<< the F<< various >> attributes|/Member Data >>>\n})
     '<Document><Para><L section="Member Data" type="pod">the <F>various</F> attributes</L></Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nL<<< the F<< various >> attributes|"Member Data" >>>\n})
     '<Document><Para><L section="Member Data" type="pod">the <F>various</F> attributes</L></Para></Document>'
    

###########################################################################

print: $^STDOUT, "#\n# Now some very complex L<text|stuff> tests with variant syntax and text around it...\n"


is:  ($x->_out: qq{=pod\n\nI like L<< Perl B<<< Error E<77>essages >>>|perldiag >>.\n})
     '<Document><Para>I like <L to="perldiag" type="pod">Perl <B>Error Messages</B></L>.</Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nI like L<< Perl\nB<<< Error\nE<77>essages >>>|perldiag >>.\n})
     '<Document><Para>I like <L to="perldiag" type="pod">Perl <B>Error Messages</B></L>.</Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nI like L<< Perl\nB<<< Error\t  E<77>essages >>>|perldiag >>.\n})
     '<Document><Para>I like <L to="perldiag" type="pod">Perl <B>Error Messages</B></L>.</Para></Document>'
    


is:  ($x->_out: qq{=pod\n\nI like L<< SWITCH B<<< E<115>tatements >>>|perlsyn/"Basic I<<<< BLOCKs >>>> and Switch StatementE<115>" >>.\n})
     '<Document><Para>I like <L section="Basic BLOCKs and Switch Statements" to="perlsyn" type="pod">SWITCH <B>statements</B></L>.</Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nI like L<< SWITCH B<<< E<115>tatements >>>|perlsyn/Basic I<<<< BLOCKs >>>> and Switch StatementE<115> >>.\n})
     '<Document><Para>I like <L section="Basic BLOCKs and Switch Statements" to="perlsyn" type="pod">SWITCH <B>statements</B></L>.</Para></Document>'
    


is:  ($x->_out: qq{=pod\n\nI like L<<< the F<< various >> attributes|/"Member Data" >>>.\n})
     '<Document><Para>I like <L section="Member Data" type="pod">the <F>various</F> attributes</L>.</Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nI like L<<< the F<< various >> attributes|/Member Data >>>.\n})
     '<Document><Para>I like <L section="Member Data" type="pod">the <F>various</F> attributes</L>.</Para></Document>'
    
is:  ($x->_out: qq{=pod\n\nI like L<<< the F<< various >> attributes|"Member Data" >>>.\n})
     '<Document><Para>I like <L section="Member Data" type="pod">the <F>various</F> attributes</L>.</Para></Document>'
    

ok:  ($x->_out: qq{=pod\n\nI like L<<< B<text>s|http://text.com >>>.\n})
     '<Document><Para>I like <L to="http://text.com" type="url"><B>text</B>s</L>.</Para></Document>'
    
ok:  ($x->_out: qq{=pod\n\nI like L<<< text|https://text.com/1/2 >>>.\n})
     '<Document><Para>I like <L to="https://text.com/1/2" type="url">text</L>.</Para></Document>'
    
ok:  ($x->_out: qq{=pod\n\nI like L<<< I<text>|http://text.com >>>.\n})
     '<Document><Para>I like <L to="http://text.com" type="url"><I>text</I></L>.</Para></Document>'
    
ok:  ($x->_out: qq{=pod\n\nI like L<<< C<text>|http://text.com >>>.\n})
     '<Document><Para>I like <L to="http://text.com" type="url"><C>text</C></L>.</Para></Document>'
    
ok:  ($x->_out: qq{=pod\n\nI like L<<< I<tI<eI<xI<t>>>>|mailto:earlE<64>text.com >>>.\n})
     '<Document><Para>I like <L to="mailto:earl@text.com" type="url"><I>t<I>e<I>x<I>t</I></I></I></I></L>.</Para></Document>'
    
ok:  ($x->_out: qq{=pod\n\nI like L<<< textZ<>|http://text.com >>>.\n})
     '<Document><Para>I like <L to="http://text.com" type="url">text</L>.</Para></Document>'
    


#
# TODO: S testing.
#

###########################################################################

print: $^STDOUT, "# Wrapping up... one for the road...\n"
ok: 1
print: $^STDOUT, "# --- Done with ", __FILE__, " --- \n"


