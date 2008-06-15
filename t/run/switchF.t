 @( )#!./perl -anFx+

BEGIN {
    print "1..2\n";
    *ARGV = *DATA;
}
print "{join ' ', <@F}";

__DATA__
okx1
okxxx2
