use Perl6::Form;

my @data = @( split "\n", <<EODATA );
**********
*************
***************
************************
********
****************
*****
************
*************
******
EODATA

my $cols  = '_'xnelems @data;
my $axis  = '-'xnelems @data;
my $label = '{|{'.nelems @data.'}|}';

print < form \%(interleave=>1, single=>\@('_','=')), <<EOGRAPH,

   ^
 = | $cols
   +-$axis->
     $label
EOGRAPH
"Frequency", < @data, "Score";

