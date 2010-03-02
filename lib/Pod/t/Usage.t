#!perl

use warnings
use File::Basename
use File::Spec
use Test::More
plan: tests => 7

use Pod::Usage

# Test verbose level 0
my $vbl_0 = << 'EOMSG'
Usage:
    The SYNOPSIS section is displayed with -verbose >= 0.

EOMSG
my $fake_out = \$('')
open: my $fake_out_fh, '>>', $fake_out
pod2usage: \(%:  verbose => 0, exit => 'noexit', output => $fake_out_fh )
is:  $fake_out->$, $vbl_0, 'Verbose level 0' 

my $msg = "Prefix message for pod2usage()"
$fake_out->$ = ''
pod2usage: \(%:  verbose => 0, exit => 'noexit', output => $fake_out_fh
                 message => $msg )
is:  $fake_out->$, "$msg\n$vbl_0", 'message parameter' 

:SKIP do
    my (@:  $file, $path, _ ) =  fileparse:  $^PROGRAM_NAME 
    skip:  'File in current directory', 2  if -e $file
    $fake_out->$ = ''
    try {
        (pod2usage: \(%:  verbose => 0, exit => 'noexit'
                          output => $fake_out_fh, input => $file ));
    }
    like:  $^EVAL_ERROR->message, qr/^Can't open $file/
           'File not found without -pathlist' 

    try {
        (pod2usage: \(%:  verbose => 0, exit => 'noexit'
                          output => $fake_out_fh, input => $file
                          pathlist => $path ));
    }
    is:  $fake_out->$, $vbl_0, '-pathlist parameter' 


:SKIP do # Test exit status from pod2usage()
    skip: "Exit status broken on Mac OS", 1 if $^OS_NAME eq 'MacOS'
    my $exit = ($^OS_NAME eq 'VMS' ?? 2 !! 42)
    my $dev_null = File::Spec->devnull
    my $args = join: ", ", @: "verbose => 0"
                              "exit    => $exit"
                              "output  => q\{$dev_null\}"
                              "input   => q\{$^PROGRAM_NAME\}"
    my $cq = (($^OS_NAME eq 'MSWin32'
               || $^OS_NAME eq 'NetWare'
               || $^OS_NAME eq 'VMS') ?? '"'
              !! "")
    my @params = @:  "$($cq)-I../lib$cq",  "$($cq)-MPod::Usage$cq", '-e' 
    my $prg = qq[$($cq)pod2usage(\\\%: $args )$cq]
    my @cmd = @:  $^EXECUTABLE_NAME, < @params, $prg 

    print: $^STDOUT, "# cmd = $((join: ' ',@cmd))\n"

    is:  (system:  < @cmd ) >> 8, $exit, 'Exit status of pod2usage()' 


# Test verbose level 1
my $vbl_1 = << 'EOMSG'
Usage:
    The SYNOPSIS section is displayed with -verbose >= 0.

Options:
    The OPTIONS section is displayed with -verbose >= 1.

Arguments:
    The ARGUMENTS section is displayed with -verbose >= 1.

EOMSG
$fake_out->$ = ''
pod2usage:  \(%:  verbose => 1, exit => 'noexit', output => $fake_out_fh ) 
is:  $fake_out->$, $vbl_1, 'Verbose level 1' 

# Test verbose level 2
$fake_out->$ = ''
require Pod::Text # Pod::Usage->isa( 'Pod::Text' )

( my $p2tp = Pod::Text->new )->parse_from_file:  $^PROGRAM_NAME, $fake_out_fh 
my $pod2text = $fake_out->$

$fake_out->$ = ''
pod2usage:  \(%:  verbose => 2, exit => 'noexit', output => $fake_out_fh ) 
my $pod2usage = $fake_out->$

is:  $pod2usage, $pod2text, 'Verbose level >= 2 eq pod2text' 


__END__

=head1 NAME

Usage.t - Tests for Pod::Usage

=head1 SYNOPSIS

The B<SYNOPSIS> section is displayed with -verbose >= 0.

=head1 DESCRIPTION

Testing Pod::Usage. This section is not displayed with -verbose < 2.

=head1 OPTIONS

The B<OPTIONS> section is displayed with -verbose >= 1.

=head1 ARGUMENTS

The B<ARGUMENTS> section is displayed with -verbose >= 1.

=head1 AUTHOR

20020105 Abe Timmerman <abe@ztreet.demon.nl>

=cut
