package MAD;

my $top = "/home/gerard/perl/bleadgerardmad";

use strict;
use warnings;

use IPC::Open3;
use IO::Handle;
use Symbol qw|gensym|;

use Nomad;

BEGIN {
    do "./test.pl";
}

sub dump_xml {
    my %options = ( switches => "",
                    @_
                  );

    my ($inputfh, $outputfh, $errorfh);
    $errorfh = gensym;
    my $pid = open3($inputfh, $outputfh, $errorfh, 
                    "PERL_XMLDUMP='$options{output}' ../perl $options{switches} -I ../lib -I lib/compress -I t/lib $options{input}");
    $inputfh->close;

    my $error = "";
    while (my $x = $outputfh->getline) { }
    while (my $x = $errorfh->getline) { $error .= $x; }
    waitpid $pid, 0;
    while (my $x = $outputfh->getline) { }
    while (my $x = $errorfh->getline) { $error .= $x; }

    if (-z $options{output}) {
        warn "mad error: $error";
    }
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

    return Nomad::convert("$file.xml");
}

1;
