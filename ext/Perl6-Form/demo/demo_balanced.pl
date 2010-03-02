use Perl6::Form

my $a = "a " x 100
my $b = "b " x 100
my $c = "c " x 100
my $d = "d " x 100
my $e = "e " x 100
my $f = "f " x 100

print: $^STDOUT, < form: 
           '{:[[[[} {:[[[[} {:[[[[} {:[[[[[[[[[} {:[[[[[[[[[} {:[[[[}'
           $a,	  $b,     $c,	  $a,	       $b,          $a
