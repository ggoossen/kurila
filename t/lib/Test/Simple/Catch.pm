# For testing Test::Simple;
package Test::Simple::Catch

use Symbol

my ($out, $err)
$out = \$('')
$err = \$('')
open: my $out_fh, '>>', $out or die: 
open: my $err_fh, '>>', $err or die: 

use Test::Builder
my $t = 'Test::Builder'->new
$t->output: $out_fh
$t->failure_output: $err_fh
$t->todo_output: $err_fh

sub caught { return (@: $out, $err) }

1
