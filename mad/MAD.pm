package MAD;

use strict;
use warnings;

use IPC::Open3;
use IO::Handle;
use Symbol qw|gensym|;

use Nomad;

sub dump_xml {
    my %options = ( switches => "",
                    @_
                  );

    `PERL_XMLDUMP='$options{output}' $ENV{madpath}/perl $options{switches} -I ../lib $options{input} 2> tmp.err`;
}

1;
