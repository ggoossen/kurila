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

    `PERL_XMLDUMP='$options{output}' ../perl $options{switches} -I ../lib $options{input} 2> tmp.err`;
}

sub convert {
    my ($input, $convert) = @_;

    my $file = "tmp";

    # perl5 to xml
    open my $infile, "> $file.in";
    $infile->print($input);
    close $infile;
    my $options = "";
    if( $input =~ m/^[#][!].*perl(.*)/) {
        $options = $1;
    }

    dump_xml( input => "$file.in", output => "$file.xml");

    if ($convert) {
        # convert
        rename "$file.xml", "$file.xml.org";
        system "cat $file.xml.org | $convert > $file.xml" and die "Failed converting";
    }

    return Nomad::xml_to_p5("$file.xml");
}

1;
