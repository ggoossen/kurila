
use Test;
use File::Spec;

BEGIN { plan tests => 1 }

use Pod::Parser;

try {require IO::String;};
skip($^EVAL_ERROR ?? 'no IO::String' !! '', sub {
  do {
    my $pod_string = 'some I<silly> text';
    my $handle = 'IO::String'->new( \$pod_string );
    my $parser = 'Pod::Parser'->new();
    $parser->parse_from_file( $^PROGRAM_NAME, $handle );
  };
  # free the reference
  do {
    my $parser = 'Pod::Parser'->new();
    $parser->parse_from_file( $^PROGRAM_NAME, < 'File::Spec'->devnull );
  };
  1;
});

exit 0;

__END__

=head1 EXAMPLE

This test makes sure the parse_from_file is re-entrant

=cut

