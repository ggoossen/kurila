#!perl

use strict;
use warnings;
use Getopt::Long;
use File::Basename;

Getopt::Long::Configure('no_ignore_case');

our $LastUpdate = -M $0;

sub handle_file {
    my $opts    = shift;
    my $file    = shift or die "Need file\n". usage();
    my $outfile = shift || '';
    my $mode    = (stat($file))[2] & 07777;

    open my $fh, "<", $file
        or die "Could not open input file $file: $!";
    binmode $fh;
    my $str = do { local $/; <$fh> };

    ### unpack?
    my $outstr;
    if( $opts->{u} ) {
        if( !$outfile ) {
            $outfile = $file;
            $outfile =~ s/\.packed//;
        }
        my ($head, $body) = split /__UU__\n/, $str;
        die "Can't unpack malformed data in '$file'\n"
            if !$head;
        $outstr = unpack 'u', $body;

    } else {
        $outfile ||= $file . '.packed';

        my $me = basename($0);

        $outstr = <<"EOFBLURB" . pack 'u', $str;
#########################################################################
This is a binary file that was packed with the 'uupacktool.pl' which
is included in the Perl distribution.

To unpack this file use the following command:

     $me -u $outfile $file

To recreate it use the following command:

     $me -p $file $outfile

Created at @{[scalar localtime]}
#########################################################################
__UU__
EOFBLURB
    }

    ### output the file
    if( $opts->{'s'} ) {
        print STDOUT $outstr;
    } else {
        print "Writing $file into $outfile\n" if $opts->{'v'};
        open my $outfh, ">", $outfile
            or die "Could not open $outfile for writing: $!";
        binmode $outfh;
        ### $outstr might be empty, if the file was empty
        print $outfh $outstr if $outstr;
        close $outfh;

        chmod $mode, $outfile;
    }

    ### delete source file?
    if( $opts->{'D'} and $file ne $outfile ) {
        1 while unlink $file;
    }
}

sub bulk_process {
    my $opts = shift;
    my $Manifest = $opts->{'m'};

    open my $fh, "<", $Manifest or die "Could not open '$Manifest':$!";

    print "Reading $Manifest\n"
            if $opts->{'v'};

    my $count = 0;
    my $lines = 0;
    while( my $line = <$fh> ) {
        chomp $line;
        my ($file) = split /\s+/, $line;

        $lines++;

        next unless $file =~ /\.packed/;

        $count++;

        my $out = $file;
        $out =~ s/\.packed//;

        ### unpack
        if( !$opts->{'c'} ) {
            ( $out, $file ) = ( $file, $out ) if $opts->{'p'};
            if (-e $out) {
                my $changed = -M _;
                if ($changed < $LastUpdate and $changed < -M $file) {
                    print "Skipping '$file' as '$out' is up-to-date.\n"
                        if $opts->{'v'};
                    next;
                }
            }
            handle_file($opts, $file, $out);
            print "Converted '$file' to '$out'\n"
                if $opts->{'v'};

        ### clean up
        } else {

            ### file exists?
            unless( -e $out ) {
                print "File '$file' was not unpacked into '$out'. Can not remove.\n";

            ### remove it
            } else {
                print "Removing '$out'\n";
                1 while unlink $out;
            }
        }
    }
    print "Found $count files to process out of $lines in '$Manifest'\n"
            if $opts->{'v'};
}

sub usage {
    return qq[
Usage: $^X $0 [-d dir] [-v] [-c] [-D] -p|-u [orig [packed|-s] | -m [manifest]]

    Handle binary files in source tree. Can be used to pack or
    unpack files individiually or as specified by a manifest file.

Options:
    -u  Unpack files (defaults to -u unless -p is specified)
    -p  Pack files
    -c  Clean up all unpacked files. Implies -m

    -D  Delete source file after encoding/decoding

    -s  Output to STDOUT rather than OUTPUT_FILE
    -m  Use manifest file, if none is explicitly provided defaults to 'MANIFEST'

    -d  Change directory to dir before processing

    -v  Run verbosely
    -h  Display this help message
];
}

my $opts = {};
GetOptions($opts,'u','p','c', 'D', 'm:s','s','d=s','v','h');

die "Can't pack and unpack at the same time!\n", usage()
    if $opts->{'u'} && $opts->{'p'};
die usage() if $opts->{'h'};

if ( $opts->{'d'} ) {
    chdir $opts->{'d'}
        or die "Failed to chdir to '$opts->{'d'}':$!";
}
$opts->{'u'} = 1 if !$opts->{'p'};
binmode STDOUT if $opts->{'s'};
if ( exists $opts->{'m'} or exists $opts->{'c'} ) {
    $opts->{'m'} ||= "MANIFEST";
    bulk_process($opts);
    exit(0);
} else {
    if (@ARGV) {
        handle_file($opts, @ARGV);
    } else {
        die "No file to process specified!\n", usage();
    }
    exit(0);
}


die usage();
