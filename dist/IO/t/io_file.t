#!./perl -w


use bytes
require "../../t/test.pl"
plan: tests => ($^OS_NAME =~ m/MSWin32/ ?? 9 !! 6)

my $Class       = 'IO::File'
my $All_Chars   = join: '', @:  "\r\n", < (map:  { chr }, 1..255 ), "zzz\n\r"
my $File        = 'bin.'.$^PID
my $Expect      = quotemeta $All_Chars

use_ok:  $Class 
can_ok:  $Class,                 "binmode" 

### file the file with binary data;
### use standard open to make sure we can compare binmodes
### on both.
do {   my $tmp;
    open: $tmp, ">", "$File" or die: "Could not open '$File': $^OS_ERROR";
    binmode: $tmp;
    print: $tmp, $All_Chars;
    close $tmp;
}

### now read in the file, once without binmode, once with.
### without binmode should fail at least on win32...
if( $^OS_NAME =~ m/MSWin32/ )
    my $fh = $Class->new

    isa_ok:  $fh,                $Class 
    ok:  < ($fh->open: $File),       "   Opened '$File'" 

    my $cont = do { local $^INPUT_RECORD_SEPARATOR = undef; ~< $fh }
    unlike:  $cont, qr/$Expect/, "   Content match fails without binmode" 


### now with binmode, it must pass
do {   my $fh = $Class->new;

    isa_ok:  $fh,                $Class ;
    ok:  ($fh->open: $File),       "   Opened '$File' $^OS_ERROR" ;
    ok:  $fh->binmode,           "   binmode enabled" ;

    my $cont = do { local $^INPUT_RECORD_SEPARATOR = undef; ~< $fh };
    like:  $cont, qr/$Expect/,   "   Content match passes with binmode" ;
}

unlink: $File    
