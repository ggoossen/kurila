
use Test::More
BEGIN { (plan: tests => 31) };

#use Pod::Simple::Debug (6);

ok: 1

use Pod::Simple::DumpAsXML
use Pod::Simple::XMLOutStream
print: $^STDOUT, "# Pod::Simple version $Pod::Simple::VERSION\n"
sub e { (Pod::Simple::DumpAsXML->_duo: < @_) }

is:  < (e: "", "") 
is:  < (e: "\n", "",) 




ok:  < (e: "\n=pod\n\n foo bar baz", "\n=pod\n\n foo bar baz") 
ok:  < (e: "\n=pod\n\n foo bar baz", "\n=pod\n\n foo bar baz\n") 


ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n")
     qq{<Document><Verbatim\nxml:space="preserve"> foo bar baz</Verbatim></Document>}
                             
ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n quux\n")
     qq{<Document><Verbatim\nxml:space="preserve"> foo bar baz\n quux</Verbatim></Document>}
                             
ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\nquux\n")
     qq{<Document><Verbatim\nxml:space="preserve"> foo bar baz\nquux</Verbatim></Document>}
                             

print: $^STDOUT, "# Contiguous verbatims...\n"
ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n quux\n")
     qq{<Document><Verbatim\nxml:space="preserve"> foo bar baz\n\n quux</Verbatim></Document>}
                             
ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n\n quux\n")
     qq{<Document><Verbatim\nxml:space="preserve"> foo bar baz\n\n\n quux</Verbatim></Document>}
                             

print: $^STDOUT, "# Testing =cut...\n"
ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n=cut\n quux\n")
     qq{<Document><Verbatim\nxml:space="preserve"> foo bar baz</Verbatim></Document>}
                             


# . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

do
    my $it =
        qq{<Document><Verbatim\nxml:space="preserve"> foo bar baz</Verbatim><head1>Foo</head1><Verbatim\nxml:space="preserve"> quux\nquum</Verbatim></Document>}
    


    print: $^STDOUT, "# Various \\n-(in)significance sanity checks...\n"

    print: $^STDOUT, "#  verbatim/cut/head/verbatim sanity zero...\n"

    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n=head1 Foo\n\n quux\nquum\n"), $it
    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n=cut\nsome code here...\n=head1 Foo\n\n quux\nquum\n"), $it
    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n=cut\nsome code here...\n\n=head1 Foo\n\n quux\nquum\n"), $it

    print: $^STDOUT, "#  verbatim/cut/head/verbatim sanity one...\n"

    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n=cut\n\nsome code here...\n=head1 Foo\n\n quux\nquum\n"), $it
    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n=cut\nsome code here...\n=head1 Foo\n\n quux\nquum\n"), $it
    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n=cut\n\nsome code here...\n=head1 Foo\n\n quux\nquum\n"), $it

    print: $^STDOUT, "#  verbatim/cut/head/verbatim sanity two...\n"

    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n=cut\n\nsome code here...\n\n=head1 Foo\n\n quux\nquum\n"), $it
    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n=cut\nsome code here...\n\n=head1 Foo\n\n quux\nquum\n"), $it
    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n=cut\n\n\nsome code here...\n\n=head1 Foo\n\n quux\nquum\n"), $it

    print: $^STDOUT, "#  verbatim/cut/head/verbatim sanity three...\n"

    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n=cut\n\nsome code here...\n\n\n=head1 Foo\n\n quux\nquum\n"), $it
    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n=cut\nsome code here...\n\n\n=head1 Foo\n\n quux\nquum\n"), $it
    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n=cut\n\nsome code here...\n\n\n=head1 Foo\n\n quux\nquum\n"), $it

    print: $^STDOUT, "#  verbatim/cut/head/verbatim sanity four...\n"

    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n\n\n\n=cut\n\nsome code here...\n\n\n=head1 Foo\n\n quux\nquum\n"), $it
    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n\n\n\n\n=cut\nsome code here...\n\n\n=head1 Foo\n\n quux\nquum\n"), $it
    ok:  (Pod::Simple::XMLOutStream->_out: "\n=pod\n\n foo bar baz\n\n\n\n\n\n=cut\n\nsome code here...\n\n\n=head1 Foo\n\n quux\nquum\n"), $it



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

print: $^STDOUT, "# Testing tab expansion...\n"

ok:  < e: 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              q{=pod

 here we go now
a
 b
  c
   d
    e
     f
      g
       h
        i
         j
          k
           l
            m
             n
              o
               p
                q
                 r
                  s
                   t
                    u
                     v
                      w
                       x
                        y
                         z
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              q{=pod

 here we go now
a
 b
  c
   d
    e
     f
      g
       h
        i
         j
          k
           l
            m
             n
              o
               p
                q
                 r
                  s
                   t
                    u
                     v
                      w
                       x
                        y
                         z
}
     

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ok:  < e: 
                                                                                           q{=pod

 here we go now
a
.b
. c
.  d
.   e
.    f
.     g
.      h
.       i
.        j
.         k
.          l
.           m
.            n
.             o
.              p
.               q
.                r
.                 s
.                  t
.                   u
.                    v
.                     w
.                      x
.                       y
.                        z
}
                                                                                           q{=pod

 here we go now
a
.b
. c
.  d
.   e
.    f
.     g
.      h
.       i
.        j
.         k
.          l
.           m
.            n
.             o
.              p
.               q
.                r
.                 s
.                  t
.                   u
.                    v
.                     w
.                      x
.                       y
.                        z
}
     

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ok:  < e: 
                                                                                           q{=pod

 here we go now
a
.b
..c
.. d
..  e
..   f
..    g
..     h
..      i
..       j
..        k
..         l
..          m
..           n
..            o
..             p
..              q
..               r
..                s
..                 t
..                  u
..                   v
..                    w
..                     x
..                      y
..                       z
}
                                                                                           q{=pod

 here we go now
a
.b
..c
.. d
..  e
..   f
..    g
..     h
..      i
..       j
..        k
..         l
..          m
..           n
..            o
..             p
..              q
..               r
..                s
..                 t
..                  u
..                   v
..                    w
..                     x
..                      y
..                       z
}
     


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ok:  < e: 
                                                                                            q{=pod

 here we go now
a
.b
..c
.. d
..  e
..   f
..    g
..     h
..      i
..      .j
..      . k
..      .  l
..      .   m
..      .    n
..      .     o
..      .      p
..      .       q
..      .        r
..      .         s
..      .          t
..      .           u
..      .            v
..      .             w
..      .              x
..      .               y
..      .                z
}
                                                                                            q{=pod

 here we go now
a
.b
..c
.. d
..  e
..   f
..    g
..     h
..      i
..      .j
..      . k
..      .  l
..      .   m
..      .    n
..      .     o
..      .      p
..      .       q
..      .        r
..      .         s
..      .          t
..      .           u
..      .            v
..      .             w
..      .              x
..      .               y
..      .                z
}
     

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# TODO: long-line splitting?


print: $^STDOUT, "# Wrapping up... one for the road...\n"
ok: 1
print: $^STDOUT, "# --- Done with ", __FILE__, " --- \n"


