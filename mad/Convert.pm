package Convert;

use strict;
use warnings;

use Nomad;
use Encode;

$ENV{madpath} or die "No madpath specified";

sub convert {
    my ($input, $convert, %options) = @_;

    my $file = "tmp";

    # perl5 to xml
    open my $infile, "> $file.in" or die;
    $infile->print($input);
    close $infile or die;
    $options{switches} ||= '';
    if( $input =~ m/^[#][!].*?perl([^#\n]*)/) {
        $options{switches} .= " " . $1;
        $options{switches} =~ s/-\*-[^-]*-\*-//g;
    }

    # XML dump
    unlink "$file.xml";
    `PERL_XMLDUMP='$file.xml' $options{dumpcommand} $options{switches} $file.in 2> tmp.err`;
    if (not -s "$file.xml") {
        die "madskills failed. No XML dump";
    }

    # sanity Perl 5 to Perl 5 works.
    my $p5 = Nomad::xml_to_p5( input => "$file.xml", version => $options{from} );
    if ($p5 ne $input) {
        use Text::Diff;
        warn diff(\$input, \$p5);
        die "Perl 5 translation was not identical. Aborting conversion";
    }

    # transform XML
    if ($convert) {
        rename "$file.xml", "$file.xml.org";
        (system "cat $file.xml.org | $convert > $file.xml") == 0
          or die "Failed converting";
    }

    # XML back to Perl 5
    return Nomad::xml_to_p5( input => "$file.xml", version => $options{to} );
}

1;
