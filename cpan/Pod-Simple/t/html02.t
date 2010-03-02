# t/html-styles.t

#use Pod::Simple::Debug (10);

use Test::More
BEGIN { (plan: tests => 7)};
use Pod::Simple::HTML

sub x ($v) { (Pod::Simple::HTML->_out: 
        sub (@< @_){  @_[0]->bare_output: 1 }
        "=pod\n\n$v"
        ) }

ok: 1

my @pairs = @:
    \(@:  "I<italicized>"   => qq{\n<p><i>italicized</i></p>\n} )
    \(@:  'B<bolded>'       => qq{\n<p><b>bolded</b></p>\n}           )
    \(@:  'C<code>'         => qq{\n<p><code>code</code></p>\n} )
    \(@:  'F</tmp/foo>'     => qq{\n<p><em>/tmp/foo</em></p>\n} )
    \(@:  'F</tmp/foo>'     => qq{\n<p><em>/tmp/foo</em></p>\n} )
    


foreach(  @pairs )
    print: $^STDOUT, "# Testing pod source $_->[0] ...\n" unless $_->[0] =~ m/\n/
    is:  (x: $_->[0]), $_->[1] 

print: $^STDOUT, "# And one for the road...\n"
ok: 1


