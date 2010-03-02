# t/html-para.t

use Test::More
BEGIN { (plan: tests => 7) };

#use Pod::Simple::Debug (10);

use Pod::Simple::HTML

sub x ($x) { (Pod::Simple::HTML->_out: 
        #sub{  $_[0]->bare_output(1)  },
        "=pod\n\n$x"
        ) }


# make sure empty file => empty output

ok: 1
is:  (x: ''),'', "Contentlessness" 
ok:  (x: qq{=pod\n\nThis is a paragraph}) =~ m{<title></title>}i 
ok:  (x: qq{This is a paragraph}) =~ m{<title></title>}i 
ok:  (x: qq{=head1 Prok\n\nThis is a paragraph}) =~ m{<title>Prok</title>}i 
like:  (x: qq{=head1 NAME\n\nProk -- stuff\n\nThis}), q{/<title>Prok</title>/} 

print: $^STDOUT, "# And one for the road...\n"
ok: 1

