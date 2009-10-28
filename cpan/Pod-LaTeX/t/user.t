#!perl

# Purpose: test UserPreamble and UserPostamble
# It's a minor variation of 'pod2latex.t',
# subject to the same limitations.
#   Variant provided by
#       Adriano Rodrigues Ferreira <ferreira@triang.com.br>

use Test::More


BEGIN { (plan: tests => 17) }

use Pod::LaTeX

# The link parsing changed between v0.22 and v0.30 of Pod::ParseUtils
use Pod::ParseUtils
my $linkver = $Pod::ParseUtils::VERSION

# Set up an END block to remove the test output file
END 
    unlink: "test.tex"
;

ok: 1

# First thing to do is to read the expected output from
# the DATA filehandle and store it in a scalar.
# Do this until we read an =pod
my @reference
while (my $line = ~< $^DATA)
    last if $line =~ m/^=pod/
    push: @reference,$line


my $user_preamble = <<PRE

\\documentclass\{article\}

\\begin\{document\}
PRE

my $user_postamble = <<POST
\\end\{document\}

POST

# Create a new parser
my %params = %:
    UserPreamble => $user_preamble
    UserPostamble => $user_postamble
    

my $parser = Pod::LaTeX->new: < %params
ok: $parser

# Create an output file
open: my $outfh, ">", "test.tex"  or die: "Unable to open test tex file: $^OS_ERROR\n"

# Read from the DATA filehandle and write to a new output file
# Really want to write this to a scalar
$parser->parse_from_filehandle: $^DATA, $outfh

close: $outfh or die: "Error closing OUTFH test.tex: $^OS_ERROR\n"

# Now read in OUTFH and compare
open: my $infh, "<", "test.tex" or die: "Unable to read test tex file: $^OS_ERROR\n"
my @output = @:  ~< $infh 

is: (nelems @output), nelems @reference

for my $i (0..((nelems @reference)-1))
    next if @reference[$i] =~ m/^%%/ # skip timestamp comments
    is: @output[$i], @reference[$i]


close: $infh or die: "Error closing INFH test.tex: $^OS_ERROR\n"


__DATA__

\documentclass{article}

\begin{document}

%%  Latex generated from POD in document (unknown)
%%  Using the perl module Pod::LaTeX
%%  Converted on Wed Jan 14 19:04:22 2004

%%  Preamble supplied by user.

\section{POD\label{POD}\index{POD}}


This is a POD file, very simple. \textit{Bye}.

\end{document}

=pod

=head1 POD

This is a POD file, very simple. I<Bye>.

