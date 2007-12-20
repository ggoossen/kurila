use re 'debug';

$_ = 'foo bar baz bop fip fop';

m/foo/ and $count++;

{
    no re 'debug';
    m/bar/ and $count++;
    {
        use re 'debug';
        m/baz/ and $count++;
    }
    m/bop/ and $count++;
}

m/fip/ and $count++;

no re 'debug';

m/fop/ and $count++;

use re 'debug';
my $var='zoo|liz|zap';
m/($var)/ or $count++;

print "Count=$count\n";


