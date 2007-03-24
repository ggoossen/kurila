package Convert;

use strict;
use warnings;

use Nomad;

sub convert {
    my ($input, $convert) = @_;

    my $file = "tmp";

    # perl5 to xml
    open my $infile, "> $file.in" or die;
    $infile->print($input);
    close $infile or die;
    my $options = "";
    if( $input =~ m/^[#][!].*perl(.*)/) {
        $options = $1;
    }

    # XML dump
    unlink "$file.xml";
    use File::Basename;
    my (undef, $dir, undef) = File::Basename::fileparse($file);
    my $lib = "-I ../lib -I ../t/lib/compress -I $dir";
    `PERL_XMLDUMP='$file.xml' $ENV{madpath}/perl $lib $file.in 2> tmp.err`;
    if (not -s "$file.xml") {
        die "madskills failed. No XML dump";
    }

    # sanity Perl 5 to Perl 5 works.
    my $p5 = Nomad::xml_to_p5( input => "$file.xml" );
    if ($p5 ne $input) {
        # use Text::Diff;
        # warn diff($p5, $input);
        die "Perl 5 translation was not identical. Aborting conversion";
    }

    # transform XML
    if ($convert) {
        rename "$file.xml", "$file.xml.org";
        system "cat $file.xml.org | $convert > $file.xml" and die "Failed converting";
    }

    # XML back to Perl 5
    return Nomad::xml_to_p5( input => "$file.xml" );
}

1;
