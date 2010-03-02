use re 'debug'

$_ = 'foo bar baz bop fip fop'

our $count

m/foo/ and $count++

do
    no re 'debug'
    m/bar/ and $count++
    do
        use re 'debug'
        m/baz/ and $count++
    
    m/bop/ and $count++


m/fip/ and $count++

no re 'debug'

m/fop/ and $count++

use re 'debug'
my $var='zoo|liz|zap'
m/($var)/ or $count++

print: $^STDOUT, "Count=$count\n"


