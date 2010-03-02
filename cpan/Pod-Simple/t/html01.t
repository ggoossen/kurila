# t/html-para.t

use Test::More tests => 8

#use Pod::Simple::Debug (10);

use Pod::Simple::HTML

sub x ($v) { (Pod::Simple::HTML->_out: 
        sub (@< @_){  @_[0]->bare_output: 1  }
        "=pod\n\n$v"
        ) }

is:  (x: 
                                                                                                                                                                                                        q{
=pod
 
This is a paragraph
 
=cut
})
     qq{\n<p>This is a paragraph</p>\n}
     "paragraph building"
    


is:  (x: qq{=pod\n\nThis is a paragraph})
     qq{\n<p>This is a paragraph</p>\n}
     "paragraph building"
    


is:  (x: qq{This is a paragraph})
     qq{\n<p>This is a paragraph</p>\n}
     "paragraph building"
    



like: x: 
          '=head1 This is a heading'
      => qr{\s*<h1><a[^<>]+>This\s+is\s+a\s+heading</a></h1>\s*$}
      "heading building"
     

like: x: 
          '=head2 This is a heading too'
      => qr{\s*<h2><a[^<>]+>This\s+is\s+a\s+heading\s+too</a></h2>\s*$}
      "heading building"
     

like: x: 
          '=head3 Also, this is a heading'
      => qr{\s*<h3><a[^<>]+>Also,\s+this\s+is\s+a\s+heading</a></h3>\s*$}
      "heading building"
     


like: x: 
          '=head4 This, too, is a heading'
      => qr{\s*<h4><a[^<>]+>This,\s+too,\s+is\s+a\s+heading</a></h4>\s*$}
      "heading building"
     


print: $^STDOUT, "# And one for the road...\n"
ok: 1

