BEGIN {
    if (%ENV{PERL_CORE}) {
	push @INC, "lib/compress";
    }
}

use lib qw(t t/compress);
use strict;
use warnings;
use bytes;

use Test::More ;
use CompTestUtils;
use Symbol;

BEGIN 
{ 
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if try { require Test::NoWarnings ;  Test::NoWarnings->import(); 1 };

    my $count = 401 ;


    plan tests => $count + $extra ;

    use_ok('Compress::Zlib', 2) ;
    use_ok('IO::Compress::Gzip::Constants') ;

    use_ok('IO::Compress::Gzip', qw($GzipError)) ;
}


my $hello = <<EOM ;
hello world
this is a test
EOM

my $len   = length $hello ;

# Check zlib_version and ZLIB_VERSION are the same.
is Compress::Zlib::zlib_version, ZLIB_VERSION, 
    "ZLIB_VERSION matches Compress::Zlib::zlib_version" ;

# generate a long random string
my $contents = '' ;
foreach (1 .. 5000)
  { $contents .= chr int rand 256 }

my $x ;
my $fil;

# compress/uncompress tests
# =========================

try { compress(\@(1)); };
ok $@->{description} =~ m#not a scalar reference#
    or print "# $@\n" ;;

try { uncompress(\@(1)); };
ok $@->{description} =~ m#not a scalar reference#
    or print "# $@\n" ;;

$hello = "hello mum" ;
my $keep_hello = $hello ;

my $compr = compress($hello) ;
ok $compr ne "" ;

my $keep_compr = $compr ;

my $uncompr = uncompress ($compr) ;

ok $hello eq $uncompr ;

ok $hello eq $keep_hello ;
ok $compr eq $keep_compr ;

# compress a number
$hello = 7890 ;
$keep_hello = $hello ;

$compr = compress($hello) ;
ok $compr ne "" ;

$keep_compr = $compr ;

$uncompr = uncompress ($compr) ;

ok $hello eq $uncompr ;

ok $hello eq $keep_hello ;
ok $compr eq $keep_compr ;

# bigger compress

$compr = compress ($contents) ;
ok $compr ne "" ;

$uncompr = uncompress ($compr) ;

ok $contents eq $uncompr ;

# buffer reference

$compr = compress(\$hello) ;
ok $compr ne "" ;


$uncompr = uncompress (\$compr) ;
ok $hello eq $uncompr ;

# bad level
$compr = compress($hello, 1000) ;
ok ! defined $compr;

# change level
$compr = compress($hello, Z_BEST_COMPRESSION) ;
ok defined $compr;
$uncompr = uncompress (\$compr) ;
ok $hello eq $uncompr ;

# corrupt data
$compr = compress(\$hello) ;
ok $compr ne "" ;

substr($compr,0, 1, "\x[FF]");
ok !defined uncompress (\$compr) ;


title 'memGzip & memGunzip';
{
    my $name = "test.gz" ;
    my $buffer = <<EOM;
some sample 
text

EOM

    my $len = length $buffer ;
    my ($x, $uncomp) ;


    # create an in-memory gzip file
    my $dest = Compress::Zlib::memGzip($buffer) ;
    ok length $dest ;

    # write it to disk
    ok open(FH, ">", "$name") ;
    binmode(FH);
    print FH $dest ;
    close FH ;

    # uncompress with gzopen
    ok my $fil = gzopen($name, "rb") ;
 
    is $fil->gzread($uncomp, 0), 0 ;
    ok (($x = $fil->gzread($uncomp)) == $len) ;
 
    ok ! $fil->gzclose ;

    ok $uncomp eq $buffer ;
 
    1 while unlink $name ;

    # now check that memGunzip can deal with it.
    my $ungzip = Compress::Zlib::memGunzip($dest) ;
    ok defined $ungzip ;
    ok $buffer eq $ungzip ;
 
    # now do the same but use a reference 

    $dest = Compress::Zlib::memGzip(\$buffer) ; 
    ok length $dest ;

    # write it to disk
    ok open(FH, ">", "$name") ;
    binmode(FH);
    print FH $dest ;
    close FH ;

    # uncompress with gzopen
    ok $fil = gzopen($name, "rb") ;
 
    ok (($x = $fil->gzread($uncomp)) == $len) ;
 
    ok ! $fil->gzclose ;

    ok $uncomp eq $buffer ;
 
    # now check that memGunzip can deal with it.
    my $keep = $dest;
    $ungzip = Compress::Zlib::memGunzip(\$dest) ;
    ok defined $ungzip ;
    ok $buffer eq $ungzip ;

    # check memGunzip can cope with missing gzip trailer
    my $minimal = substr($keep, 0, -1) ;
    $ungzip = Compress::Zlib::memGunzip(\$minimal) ;
    ok defined $ungzip ;
    ok $buffer eq $ungzip ;

    $minimal = substr($keep, 0, -2) ;
    $ungzip = Compress::Zlib::memGunzip(\$minimal) ;
    ok defined $ungzip ;
    ok $buffer eq $ungzip ;

    $minimal = substr($keep, 0, -3) ;
    $ungzip = Compress::Zlib::memGunzip(\$minimal) ;
    ok defined $ungzip ;
    ok $buffer eq $ungzip ;

    $minimal = substr($keep, 0, -4) ;
    $ungzip = Compress::Zlib::memGunzip(\$minimal) ;
    ok defined $ungzip ;
    ok $buffer eq $ungzip ;

    $minimal = substr($keep, 0, -5) ;
    $ungzip = Compress::Zlib::memGunzip(\$minimal) ;
    ok defined $ungzip ;
    ok $buffer eq $ungzip ;

    $minimal = substr($keep, 0, -6) ;
    $ungzip = Compress::Zlib::memGunzip(\$minimal) ;
    ok defined $ungzip ;
    ok $buffer eq $ungzip ;

    $minimal = substr($keep, 0, -7) ;
    $ungzip = Compress::Zlib::memGunzip(\$minimal) ;
    ok defined $ungzip ;
    ok $buffer eq $ungzip ;

    $minimal = substr($keep, 0, -8) ;
    $ungzip = Compress::Zlib::memGunzip(\$minimal) ;
    ok defined $ungzip ;
    ok $buffer eq $ungzip ;

    $minimal = substr($keep, 0, -9) ;
    $ungzip = Compress::Zlib::memGunzip(\$minimal) ;
    ok ! defined $ungzip ;

 
    1 while unlink $name ;

    # check corrupt header -- too short
    $dest = "x" ;
    my $result = Compress::Zlib::memGunzip($dest) ;
    ok !defined $result ;

    # check corrupt header -- full of junk
    $dest = "x" x 200 ;
    $result = Compress::Zlib::memGunzip($dest) ;
    ok !defined $result ;

    # corrupt header - 1st byte wrong
    my $bad = $keep ;
    substr($bad, 0, 1, "\x[FF]") ;
    $ungzip = Compress::Zlib::memGunzip(\$bad) ;
    ok ! defined $ungzip ;

    # corrupt header - 2st byte wrong
    $bad = $keep ;
    substr($bad, 1, 1, "\x[FF]") ;
    $ungzip = Compress::Zlib::memGunzip(\$bad) ;
    ok ! defined $ungzip ;

    # corrupt header - method not deflated
    $bad = $keep ;
    substr($bad, 2, 1, "\x[FF]") ;
    $ungzip = Compress::Zlib::memGunzip(\$bad) ;
    ok ! defined $ungzip ;

    # corrupt header - reserverd bits used
    $bad = $keep ;
    substr($bad, 3, 1, "\x[FF]") ;
    $ungzip = Compress::Zlib::memGunzip(\$bad) ;
    ok ! defined $ungzip ;

    # corrupt trailer - length wrong
    $bad = $keep ;
    substr($bad, -8, 4, "\x[FF]" x 4) ;
    $ungzip = Compress::Zlib::memGunzip(\$bad) ;
    ok ! defined $ungzip ;

    # corrupt trailer - CRC wrong
    $bad = $keep ;
    substr($bad, -4, 4, "\x[FF]" x 4) ;
    $ungzip = Compress::Zlib::memGunzip(\$bad) ;
    ok ! defined $ungzip ;
}

{
    title "Check all bytes can be handled";

    my $lex = LexFile->new( my $name) ;
    my $data = join '', map { chr } 0x00 .. 0xFF;
    $data .= "\r\nabd\r\n";

    my $fil;
    ok $fil = gzopen($name, "wb") ;
    is $fil->gzwrite($data), length $data ;
    ok ! $fil->gzclose();

    my $input;
    ok $fil = gzopen($name, "rb") ;
    is $fil->gzread($input), length $data ;
    ok ! $fil->gzclose();
    ok $input eq $data;

    title "Check all bytes can be handled - transparent mode";
    writeFile($name, $data);
    ok $fil = gzopen($name, "rb") ;
    is $fil->gzread($input), length $data ;
    ok ! $fil->gzclose();
    ok $input eq $data;

}

title 'memGunzip with a gzopen created file';
{
    my $name = "test.gz" ;
    my $buffer = <<EOM;
some sample 
text

EOM

    ok $fil = gzopen($name, "wb") ;

    ok $fil->gzwrite($buffer) == length $buffer ;

    ok ! $fil->gzclose ;

    my $compr = readFile($name);
    ok length $compr ;
    my $unc = Compress::Zlib::memGunzip($compr) ;
    ok defined $unc ;
    ok $buffer eq $unc ;
    1 while unlink $name ;
}

{
    title 'CRC32' ;

    # CRC32 of this data should have the high bit set
    # value in ascii is ZgRNtjgSUW
    my $data = "\x5a\x67\x52\x4e\x74\x6a\x67\x53\x55\x57"; 
    my $expected_crc = 0xCF707A2B ; # 3480255019 

    my $crc = crc32($data) ;
    is $crc, $expected_crc;
}

{
    title 'Adler32' ;

    # adler of this data should have the high bit set
    # value in ascii is lpscOVsAJiUfNComkOfWYBcPhHZ[bT
    my $data = "\x6c\x70\x73\x63\x4f\x56\x73\x41\x4a\x69\x55\x66" .
               "\x4e\x43\x6f\x6d\x6b\x4f\x66\x57\x59\x42\x63\x50" .
               "\x68\x48\x5a\x5b\x62\x54";
    my $expected_crc = 0xAAD60AC7 ; # 2866154183 
    my $crc = adler32($data) ;
    is $crc, $expected_crc;
}

{
    # memGunzip - input > 4K

    my $contents = '' ;
    foreach (1 .. 20000)
      { $contents .= chr int rand 256 }

    ok my $compressed = Compress::Zlib::memGzip(\$contents) ;

    ok length $compressed +> 4096 ;
    ok my $out = Compress::Zlib::memGunzip(\$compressed) ;
     
    ok $contents eq $out ;
    is length $out, length $contents ;

    
}


{
    # memGunzip Header Corruption Tests

    my $string = <<EOM;
some text
EOM

    my $good ;
    ok my $x = IO::Compress::Gzip->new( \$good, Append => 1, -HeaderCRC => 1) ;
    ok $x->write($string) ;
    ok  $x->close ;

    {
        title "Header Corruption - Fingerprint wrong 1st byte" ;
        my $buffer = $good ;
        substr($buffer, 0, 1, 'x') ;

        ok ! Compress::Zlib::memGunzip(\$buffer) ;
    }

    {
        title "Header Corruption - Fingerprint wrong 2nd byte" ;
        my $buffer = $good ;
        substr($buffer, 1, 1, "\x[FF]") ;

        ok ! Compress::Zlib::memGunzip(\$buffer) ;
    }

    {
        title "Header Corruption - CM not 8";
        my $buffer = $good ;
        substr($buffer, 2, 1, 'x') ;

        ok ! Compress::Zlib::memGunzip(\$buffer) ;
    }

    {
        title "Header Corruption - Use of Reserved Flags";
        my $buffer = $good ;
        substr($buffer, 3, 1, "\x[ff]");

        ok ! Compress::Zlib::memGunzip(\$buffer) ;
    }

}

for my $index ( GZIP_MIN_HEADER_SIZE + 1 ..  GZIP_MIN_HEADER_SIZE + GZIP_FEXTRA_HEADER_SIZE + 1)
{
    title "Header Corruption - Truncated in Extra";
    my $string = <<EOM;
some text
EOM

    my $truncated ;
    ok  my $x = IO::Compress::Gzip->new( \$truncated, Append => 1, -HeaderCRC => 1, Strict => 0,
				-ExtraField => "hello" x 10)  ;
    ok  $x->write($string) ;
    ok  $x->close ;

    substr($truncated, $index, undef, '') ;

    ok ! Compress::Zlib::memGunzip(\$truncated) ;


}

my $Name = "fred" ;
for my $index ( GZIP_MIN_HEADER_SIZE ..  GZIP_MIN_HEADER_SIZE + length($Name) -1)
{
    title "Header Corruption - Truncated in Name";
    my $string = <<EOM;
some text
EOM

    my $truncated ;
    ok  my $x = IO::Compress::Gzip->new( \$truncated, Append => 1, -Name => $Name);
    ok  $x->write($string) ;
    ok  $x->close ;

    substr($truncated, $index, undef, '') ;

    ok ! Compress::Zlib::memGunzip(\$truncated) ;
}

my $Comment = "comment" ;
for my $index ( GZIP_MIN_HEADER_SIZE ..  GZIP_MIN_HEADER_SIZE + length($Comment) -1)
{
    title "Header Corruption - Truncated in Comment";
    my $string = <<EOM;
some text
EOM

    my $truncated ;
    ok  my $x = IO::Compress::Gzip->new( \$truncated, -Comment => $Comment);
    ok  $x->write($string) ;
    ok  $x->close ;

    substr($truncated, $index, undef, '') ;
    ok ! Compress::Zlib::memGunzip(\$truncated) ;
}

for my $index ( GZIP_MIN_HEADER_SIZE ..  GZIP_MIN_HEADER_SIZE + GZIP_FHCRC_SIZE -1)
{
    title "Header Corruption - Truncated in CRC";
    my $string = <<EOM;
some text
EOM

    my $truncated ;
    ok  my $x = IO::Compress::Gzip->new( \$truncated, -HeaderCRC => 1);
    ok  $x->write($string) ;
    ok  $x->close ;

    substr($truncated, $index, undef, '') ;

    ok ! Compress::Zlib::memGunzip(\$truncated) ;
}

{
    title "memGunzip can cope with a gzip header with all possible fields";
    my $string = <<EOM;
some text
EOM

    my $buffer ;
    ok  my $x = IO::Compress::Gzip->new( \$buffer, 
                             -Append     => 1,
                             -Strict     => 0,
                             -HeaderCRC  => 1,
                             -Name       => "Fred",
                             -ExtraField => "Extra",
                             -Comment    => 'Comment');
    ok  $x->write($string) ;
    ok  $x->close ;

    ok defined $buffer ;

    ok my $got = Compress::Zlib::memGunzip($buffer) 
        or diag "gzerrno is $gzerrno" ;
    is $got, $string ;
}


{
    # Trailer Corruption tests

    my $string = <<EOM;
some text
EOM

    my $good ;
    ok  my $x = IO::Compress::Gzip->new( \$good, Append => 1) ;
    ok  $x->write($string) ;
    ok  $x->close ;

    foreach my $trim (-8 .. -1)
    {
        my $got = $trim + 8 ;
        title "Trailer Corruption - Trailer truncated to $got bytes" ;
        my $buffer = $good ;

        substr($buffer, $trim, undef, '');

        ok my $u = Compress::Zlib::memGunzip(\$buffer) ;
        ok $u eq $string;

    }

    {
        title "Trailer Corruption - Length Wrong, CRC Correct" ;
        my $buffer = $good ;
        substr($buffer, -4, 4, pack('V', 1234));

        ok ! Compress::Zlib::memGunzip(\$buffer) ;
    }

    {
        title "Trailer Corruption - Length Wrong, CRC Wrong" ;
        my $buffer = $good ;
        substr($buffer, -4, 4, pack('V', 1234));
        substr($buffer, -8, 4, pack('V', 1234));

        ok ! Compress::Zlib::memGunzip(\$buffer) ;

    }
}


sub slurp
{
    my $name = shift ;

    my $input;
    my $fil = gzopen($name, "rb") ;
    ok $fil , "opened $name";
    cmp_ok $fil->gzread($input, 50000), "+>", 0, "read more than zero bytes";
    ok ! $fil->gzclose(), "closed ok";

    return $input;
}

sub trickle
{
    my $name = shift ;

    my $got;
    my $input;
    $fil = gzopen($name, "rb") ;
    ok $fil, "opened ok";
    while ($fil->gzread($input, 50000) +> 0)
    {
        $got .= $input;
        $input = '';
    }
    ok ! $fil->gzclose(), "closed ok";

    return $got;

    return $input;
}

{

    title "Append & MultiStream Tests";
    # rt.24041

    my $lex = LexFile->new( my $name) ;
    my $data1 = "the is the first";
    my $data2 = "and this is the second";
    my $trailing = "some trailing data";

    my $fil;

    title "One file";
    $fil = gzopen($name, "wb") ;
    ok $fil, "opened first file"; 
    is $fil->gzwrite($data1), length $data1, "write data1" ;
    ok ! $fil->gzclose(), "Closed";

    is slurp($name), $data1, "got expected data from slurp";
    is trickle($name), $data1, "got expected data from trickle";

    title "Two files";
    $fil = gzopen($name, "ab") ;
    ok $fil, "opened second file"; 
    is $fil->gzwrite($data2), length $data2, "write data2" ;
    ok ! $fil->gzclose(), "Closed";

    is slurp($name), $data1 . $data2, "got expected data from slurp";
    is trickle($name), $data1 . $data2, "got expected data from trickle";

    title "Trailing Data";
    open F, ">>", "$name";
    print F $trailing;
    close F;

    is slurp($name), $data1 . $data2 . $trailing, "got expected data from slurp" ;
    is trickle($name), $data1 . $data2 . $trailing, "got expected data from trickle" ;
}

{
    title "gzclose & gzflush return codes";
    # rt.29215

    my $lex = LexFile->new( my $name );
    my $data1 = "the is some text";
    my $status;

    $fil = gzopen($name, "wb") ;
    ok $fil, "opened first file"; 
    is $fil->gzwrite($data1), length $data1, "write data1" ;
    $status = $fil->gzflush(0xfff);
    ok   $status, "flush not ok" ;
    is $status, Z_STREAM_ERROR;
    ok ! $fil->gzflush(), "flush ok" ;
    ok ! $fil->gzclose(), "Closed";
}
