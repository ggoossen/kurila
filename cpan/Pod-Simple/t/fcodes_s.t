BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = (@:  '../lib' )
    


use Test::More
BEGIN
    plan: tests => 14

#use Pod::Simple::Debug (6);

ok: 1

use Pod::Simple::XMLOutStream
print: $^STDOUT, "# Pod::Simple version $Pod::Simple::VERSION\n"
my $x = 'Pod::Simple::XMLOutStream'
sub e ($x, $y) { ($x->_duo: $x, $y) }

$Pod::Simple::XMLOutStream::ATTR_PAD   = ' '
$Pod::Simple::XMLOutStream::SORT_ATTRS = 1 # for predictably testable output


print: $^STDOUT, "# S as such...\n"

is:  ($x->_out: "=pod\n\nI like S<bric-a-brac>.\n")
     =>  '<Document><Para>I like <S>bric-a-brac</S>.</Para></Document>' 
is:  ($x->_out: "=pod\n\nI like S<bric-a-brac a gogo >.\n")
     =>  '<Document><Para>I like <S>bric-a-brac a gogo </S>.</Para></Document>' 
is:  ($x->_out: "=pod\n\nI like S<< bric-a-brac a gogo >>.\n")
     =>  '<Document><Para>I like <S>bric-a-brac a gogo</S>.</Para></Document>' 

my $unless_ascii = ((chr: 65) eq 'A') ?? '' !!
    "Skip because not in ASCIIland"

:SKIP do 
    skip: $unless_ascii, 3 if $unless_ascii
    is: ($x->_out:  sub { @_[0]->nbsp_for_S: 1 }
                    "=pod\n\nI like S<bric-a-brac a gogo>.\n")
        '<Document><Para>I like bric-a-brac&#160;a&#160;gogo.</Para></Document>'
    is: ($x->_out:  sub { @_[0]->nbsp_for_S: 1 }
                    qq{=pod\n\nI like S<L</"bric-a-brac a gogo">>.\n})
        '<Document><Para>I like <L content-implicit="yes" section="bric-a-brac a gogo" type="pod">&#34;bric-a-brac&#160;a&#160;gogo&#34;</L>.</Para></Document>'

    is: ($x->_out:  sub { @_[0]->nbsp_for_S: 1 }
                    qq{=pod\n\nI like S<L<Stuff like that|/"bric-a-brac a gogo">>.\n})
        '<Document><Para>I like <L section="bric-a-brac a gogo" type="pod">Stuff&#160;like&#160;that</L>.</Para></Document>'

    is: ($x->_out:  sub { @_[0]->nbsp_for_S: 1 }
                    qq{=pod\n\nI like S<L<Stuff I<like that>|/"bric-a-brac a gogo">>.\n})
        '<Document><Para>I like <L section="bric-a-brac a gogo" type="pod">Stuff&#160;<I>like&#160;that</I></L>.</Para></Document>'



is:  < ($x->_duo:  sub { @_[0]->nbsp_for_S: 1 }
                   "=pod\n\nI like S<bric-a-brac a gogo>.\n"
                   "=pod\n\nI like bric-a-bracE<160>aE<160>gogo.\n"
         )
is: 
  < (map: { my $z = $_; $z =~ s/content-implicit="yes" //g; $z },
            ($x->_duo:  sub { @_[0]->nbsp_for_S: 1 }
                        qq{=pod\n\nI like S<L</"bric-a-brac a gogo">>.\n}
                        qq{=pod\n\nI like L<"bric-a-bracE<160>aE<160>gogo"|/"bric-a-brac a gogo">.\n}
            ))
is:  < ($x->_duo:  sub { @_[0]->nbsp_for_S: 1 }
                   qq{=pod\n\nI like S<L<Stuff like that|"bric-a-brac a gogo">>.\n}
                   qq{=pod\n\nI like L<StuffE<160>likeE<160>that|"bric-a-brac a gogo">.\n}
         )
is: 
  < (map: {my $z = $_; $z =~ s/content-implicit="yes" //g; $z },
            ($x->_duo:  sub { @_[0]->nbsp_for_S: 1 }
                        qq{=pod\n\nI like S<L<Stuff I<like that>|"bric-a-brac a gogo">>.\n}
                        qq{=pod\n\nI like L<StuffE<160>I<likeE<160>that>|"bric-a-brac a gogo">.\n}
            ))

use Pod::Simple::Text
$x = (Pod::Simple::Text->new: )
($x->preserve_whitespace: 1)
# RT#25679
ok: 
  ($x->_out: <<END
=head1 The Tk::mega manpage showed me how C<< SE<lt> E<gt> foo >> is being rendered

Both pod2text and pod2man S<    > lose the rest of the line

=head1 Do they always S<    > lose the rest of the line?

=cut
END
    )
  <<END
The Tk::mega manpage showed me how S< > foo is being rendered

    Both pod2text and pod2man      lose the rest of the line

Do they always      lose the rest of the line?

END
  

print: $^STDOUT, "# Wrapping up... one for the road...\n"
ok: 1
print: $^STDOUT, "# --- Done with ", __FILE__, " --- \n"

