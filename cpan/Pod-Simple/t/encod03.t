
use Test::More
BEGIN { (plan: tests => 4) };

#use Pod::Simple::Debug (5);

ok: 1

use Pod::Simple::DumpAsXML
use Pod::Simple::XMLOutStream
print: $^STDOUT, "# Pod::Simple version $Pod::Simple::VERSION\n"

do
    my @output_lines = split: m/[\cm\cj]+/, Pod::Simple::XMLOutStream->_out:  q{

=encoding koi8-r

=head1 NAME

Bippitty Boppity Boo -- Yormp

=cut

} 


    if((grep: { m/Unknown directive/i }, @output_lines) )
        ok: 0
        print: $^STDOUT, "# I saw an Unknown directive warning here! :\n"
               < (map:  {"#==> $_\n" }, @output_lines), "#\n#\n"
    else
        ok: 1
    



# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
print: $^STDOUT, "# Now a control group, to make sure that =fishbladder DOES\n"
       "#  cause an 'unknown directive' error...\n"

do
    my @output_lines = split: m/[\cm\cj]+/, Pod::Simple::XMLOutStream->_out:  q{

=fishbladder

=head1 NAME

Fet's "When you were reading"

=cut

} 


    if((grep: { m/Unknown directive/i }, @output_lines) )
        ok: 1
    else
        ok: 0
        print: $^STDOUT, "# But I didn't see an Unknows directive warning here! :\n"
               < (map:  {"#==> $_\n" }, @output_lines), "#\n#\n"
    





print: $^STDOUT, "#\n# And one for the road...\n"
ok: 1

