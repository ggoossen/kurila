
use Test::More
use File::Spec

BEGIN { (plan: tests => 1) }

use Pod::Parser

:SKIP
    do
    if (not try {require IO::String; 1})
        skip: 'no IO::String', 1
    
    do
        my $pod_string = 'some I<silly> text'
        my $handle = 'IO::String'->new:  \$pod_string 
        my $parser = 'Pod::Parser'->new
        $parser->parse_from_file:  $^PROGRAM_NAME, $handle 
    
    # free the reference
    do
        my $parser = 'Pod::Parser'->new
        $parser->parse_from_file:  $^PROGRAM_NAME, < 'File::Spec'->devnull 
    
    1


__END__

=head1 EXAMPLE

This test makes sure the parse_from_file is re-entrant

=cut

