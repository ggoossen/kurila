BEGIN {
    if (%ENV{?PERL_CORE}) {
	push @INC, "lib/compress";
    }
}

use lib < qw(t t/compress);

use IO::Uncompress::Gunzip v2.006 ;

use warnings;
use bytes;

use Test::More ;
use CompTestUtils;
use IO::File ;

BEGIN {
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if try { require Test::NoWarnings ;  Test::NoWarnings->import(); 1 };

    plan tests => 179 + $extra ;

}

use Compress::Zlib;
use IO::Compress::Gzip::Constants;

my $hello = <<EOM ;
hello world
this is a test
EOM

my $len   = length $hello ;

# Check zlib_version and ZLIB_VERSION are the same.
is Compress::Zlib::zlib_version, ZLIB_VERSION,
    "ZLIB_VERSION matches Compress::Zlib::zlib_version" ;
 
# gzip tests
#===========

my $name = "test.gz" ;
my ($x, $uncomp) ;

ok my $fil = gzopen($name, "wb") ;

is $gzerrno, 0, 'gzerrno is 0';
is $fil->gzerror(), 0, "gzerror() returned 0";

is $fil->gztell(), 0, "gztell returned 0";
is $gzerrno, 0, 'gzerrno is 0';

is $fil->gzwrite($hello), $len ;
is $gzerrno, 0, 'gzerrno is 0';

is $fil->gztell(), $len, "gztell returned $len";
is $gzerrno, 0, 'gzerrno is 0';

ok ! $fil->gzclose ;

ok $fil = gzopen($name, "rb") ;

is $gzerrno, 0, 'gzerrno is 0';
is $fil->gztell(), 0;

is $fil->gzread($uncomp), $len; 

is $fil->gztell(), $len;

ok ! $fil->gzclose ;


1 while unlink $name ;

ok $hello eq $uncomp ;

# check that a number can be gzipped
my $number = 7603 ;
my $num_len = 4 ;

ok $fil = gzopen($name, "wb") ;

is $gzerrno, 0;

is $fil->gzwrite($number), $num_len, "gzwrite returned $num_len" ;
is $gzerrno, 0, 'gzerrno is 0';
ok ! $fil->gzflush(Z_FINISH) ;

is $gzerrno, 0, 'gzerrno is 0';

ok ! $fil->gzclose ;

cmp_ok $gzerrno, '==', 0;

ok $fil = gzopen($name, "rb") ;

ok (($x = $fil->gzread($uncomp)) == $num_len) ;

ok $fil->gzerror() == 0 || $fil->gzerror() == Z_STREAM_END;
ok $gzerrno == 0 || $gzerrno == Z_STREAM_END;

ok ! $fil->gzclose ;

ok $gzerrno == 0
    or print "# gzerrno is $gzerrno\n" ;

1 while unlink $name ;

ok $number == $uncomp ;
ok $number eq $uncomp ;


# now a bigger gzip test

my $text = 'text' ;
my $file = "$text.gz" ;

ok my $f = gzopen($file, "wb") ;

# generate a long random string
my $contents = '' ;
foreach (1 .. 5000)
  { $contents .= chr int rand 256 }

$len = length $contents ;

ok $f->gzwrite($contents) == $len ;

ok ! $f->gzclose ;

ok $f = gzopen($file, "rb") ;
 
my $uncompressed ;
is $f->gzread($uncompressed, $len), $len ;

ok $contents eq $uncompressed 

    or print "# Length orig $len" . 
             ", Length uncompressed " . length($uncompressed) . "\n" ;

ok ! $f->gzclose ;

1 while unlink($file) ;

# gzip - readline tests
# ======================

# first create a small gzipped text file
$name = "test.gz" ;
my @text = @(<<EOM, <<EOM, <<EOM, <<EOM) ;
this is line 1
EOM
the second line
EOM
the line after the previous line
EOM
the final line
EOM

$text = join("", @text) ;

ok $fil = gzopen($name, "wb") ;
ok $fil->gzwrite($text) == length $text ;
ok ! $fil->gzclose ;

# now try to read it back in
ok $fil = gzopen($name, "rb") ;
my $line = '';
for my $i (0 .. nelems(@text) -2)
{
    ok $fil->gzreadline($line) +> 0;
    is $line, @text[$i] ;
}

# now read the last line
ok $fil->gzreadline($line) +> 0;
is $line, @text[-1] ;

# read past the eof
is $fil->gzreadline($line), 0;

ok ! $fil->gzclose ;
1 while unlink($name) ;

# a text file with a very long line (bigger than the internal buffer)
my $line1 = ("abcdefghijklmnopq" x 2000) . "\n" ;
my $line2 = "second line\n" ;
$text = $line1 . $line2 ;
ok $fil = gzopen($name, "wb") ;
ok $fil->gzwrite($text) == length $text ;
ok ! $fil->gzclose ;

# now try to read it back in
ok $fil = gzopen($name, "rb") ;
my $i = 0 ;
my @got = @();
while ($fil->gzreadline($line) +> 0) {
    @got[+$i] = $line ;
    ++ $i ;
}
is $i, 2 ;
is @got[0], $line1 ;
is @got[1], $line2 ;

ok ! $fil->gzclose ;

1 while unlink $name ;

# a text file which is not termined by an EOL

$line1 = "hello hello, I'm back again\n" ;
$line2 = "there is no end in sight" ;

$text = $line1 . $line2 ;
ok $fil = gzopen($name, "wb") ;
ok $fil->gzwrite($text) == length $text ;
ok ! $fil->gzclose ;

# now try to read it back in
ok $fil = gzopen($name, "rb") ;
@got = @() ; $i = 0 ;
while ($fil->gzreadline($line) +> 0) {
    @got[+$i] = $line ;    
    ++ $i ;
}
is $i, 2 ;
is @got[0], $line1 ;
is @got[1], $line2 ;

ok ! $fil->gzclose ;

1 while unlink $name ;

do {

    title 'mix gzread and gzreadline';
    
    # case 1: read a line, then a block. The block is
    #         smaller than the internal block used by
    #	  gzreadline
    my $lex = LexFile->new( my $name) ;
    $line1 = "hello hello, I'm back again\n" ;
    $line2 = "abc" x 200 ; 
    my $line3 = "def" x 200 ;
    
    $text = $line1 . $line2 . $line3 ;
    my $fil;
    ok $fil = gzopen($name, "wb"), ' gzopen for write ok' ;
    is $fil->gzwrite($text), length $text, '    gzwrite ok' ;
    is $fil->gztell(), length $text, '    gztell ok' ;
    ok ! $fil->gzclose, '  gzclose ok' ;
    
    # now try to read it back in
    ok $fil = gzopen($name, "rb"), '  gzopen for read ok' ;
    cmp_ok $fil->gzreadline($line), '+>', 0, '    gzreadline' ;
    is $fil->gztell(), length $line1, '    gztell ok' ;
    is $line, $line1, '    got expected line' ;
    cmp_ok $fil->gzread($line, length $line2), '+>', 0, '    gzread ok' ;
    is $fil->gztell(), length($line1)+length($line2), '    gztell ok' ;
    is $line, $line2, '    read expected block' ;
    cmp_ok $fil->gzread($line, length $line3), '+>', 0, '    gzread ok' ;
    is $fil->gztell(), length($text), '    gztell ok' ;
    is $line, $line3, '    read expected block' ;
};

do {
    title "Pass gzopen a filehandle - use IO::File" ;

    my $lex = LexFile->new( my $name) ;

    my $hello = "hello" ;
    my $len = length $hello ;

    my $f = IO::File->new( "$name", ">") ;
    ok $f;

    my $fil;
    ok $fil = gzopen($f, "wb") ;

    ok $fil->gzwrite($hello) == $len ;

    ok ! $fil->gzclose ;

    $f = IO::File->new( "$name", "<") ;
    ok $fil = gzopen($name, "rb") ;

    my $uncmomp;
    ok (($x = $fil->gzread($uncomp)) == $len) 
        or print "# length $x, expected $len\n" ;

    ok ! $fil->gzclose ;

    is $uncomp, $hello, "got expected output" ;
};


do {
    title 'test parameters for gzopen';
    my $lex = LexFile->new( my $name) ;

    my $fil;

    # missing parameters
    eval ' $fil = gzopen()  ' ;
    like $@->{?description}, mkEvalErr('Not enough arguments for Compress::Zlib::gzopen'),
        '  gzopen with missing mode fails' ;

    # unknown parameters
    $fil = try { gzopen($name, "xy") };
    ok ! defined $fil, '  gzopen with unknown mode fails' ;

    $fil = gzopen($name, "ab") ;
    ok $fil, '  gzopen with mode "ab" is ok' ;

    $fil = gzopen($name, "wb6") ;
    ok $fil, '  gzopen with mode "wb6" is ok' ;

    $fil = gzopen($name, "wbf") ;
    ok $fil, '  gzopen with mode "wbf" is ok' ;

    $fil = gzopen($name, "wbh") ;
    ok $fil, '  gzopen with mode "wbh" is ok' ;
};

do {
    title 'Read operations when opened for writing';

    my $lex = LexFile->new( my $name) ;
    my $fil;
    ok $fil = gzopen($name, "wb"), '  gzopen for writing' ;
    is $fil->gzread(), Z_STREAM_ERROR, "    gzread returns Z_STREAM_ERROR" ;
    ok ! $fil->gzclose, "  gzclose ok" ;
};

do {
    title 'write operations when opened for reading';

    my $lex = LexFile->new( my $name) ;
    my $test = "hello" ;
    my $fil;
    ok $fil = gzopen($name, "wb"), "  gzopen for writing" ;
    is $fil->gzwrite($text), length $text, "    gzwrite ok" ;
    ok ! $fil->gzclose, "  gzclose ok" ;

    ok $fil = gzopen($name, "rb"), "  gzopen for reading" ;
    is $fil->gzwrite(), Z_STREAM_ERROR, "  gzwrite returns Z_STREAM_ERROR" ;
};

do {
    title 'read/write a non-readable/writable file';

    SKIP:
    do {
        my $lex = LexFile->new( my $name) ;
        writeFile($name, "abc");
        chmod 0444, $name ;

        skip "Cannot create non-writable file", 3 
            if -w $name ;

        ok ! -w $name, "  input file not writable";

        my $fil = try { gzopen($name, "wb") };
        ok !$fil, "  gzopen returns undef" ;
        ok $gzerrno, "  gzerrno ok" or 
            diag " gzerrno $gzerrno\n";

        chmod 0777, $name ;
    };

    SKIP:
    do {
        my $lex = LexFile->new( my $name) ;
        skip "Cannot create non-readable file", 3 
            if $^O eq 'cygwin';

        writeFile($name, "abc");
        chmod 0222, $name ;

        skip "Cannot create non-readable file", 3 
            if -r $name ;

        ok ! -r $name, "  input file not readable";
        $gzerrno = 0;
        $fil = try { gzopen($name, "rb") };
        ok !$fil, "  gzopen returns undef" ;
        ok $gzerrno, "  gzerrno ok";
        chmod 0777, $name ;
    };

};

do {
    title "gzseek" ;

    my $buff ;
    my $lex = LexFile->new( my $name) ;

    my $first = "beginning" ;
    my $last  = "the end" ;
    my $iow = gzopen($name, "w");
    $iow->gzwrite($first) ;
    ok $iow->gzseek(5, SEEK_CUR) ;
    is $iow->gztell(), length($first)+5;
    ok $iow->gzseek(0, SEEK_CUR) ;
    is $iow->gztell(), length($first)+5;
    ok $iow->gzseek(length($first)+10, SEEK_SET) ;
    is $iow->gztell(), length($first)+10;

    $iow->gzwrite($last) ;
    $iow->gzclose ;

    ok GZreadFile($name) eq $first . "\x00" x 10 . $last ;

    my $io = gzopen($name, "r");
    ok $io->gzseek(length($first), SEEK_CUR) ;
    is $io->gztell(), length($first);

    ok $io->gzread($buff, 5) ;
    is $buff, "\x00" x 5 ;
    is $io->gztell(), length($first) + 5;

    is $io->gzread($buff, 0), 0 ;
    #is $buff, "\x00" x 5 ;
    is $io->gztell(), length($first) + 5;

    ok $io->gzseek(0, SEEK_CUR) ;
    my $here = $io->gztell() ;
    is $here, length($first)+5;

    ok $io->gzseek($here+5, SEEK_SET) ;
    is $io->gztell(), $here+5 ;
    ok $io->gzread($buff, 100) ;
    ok $buff eq $last ;
};

do {
    # seek error cases
    my $lex = LexFile->new( my $name) ;

    my $a = gzopen($name, "w");

    ok ! $a->gzerror() 
        or print "# gzerrno is $Compress::Zlib::gzerrno \n" ;
    try { $a->gzseek(-1, 10) ; };
    like $@->{?description}, mkErr("seek: unknown value, 10, for whence parameter");

    try { $a->gzseek(-1, SEEK_END) ; };
    like $@->{?description}, mkErr("seek: cannot seek backwards");

    $a->gzwrite("fred");
    $a->gzclose ;


    my $u = gzopen($name, "r");

    try { $u->gzseek(-1, 10) ; };
    like $@->{?description}, mkErr("seek: unknown value, 10, for whence parameter");

    try { $u->gzseek(-1, SEEK_END) ; };
    like $@->{?description}, mkErr("seek: SEEK_END not allowed");

    try { $u->gzseek(-1, SEEK_CUR) ; };
    like $@->{?description}, mkErr("seek: cannot seek backwards");
};

do {
    title 'gzreadline does not support $/';

    my $lex = LexFile->new( my $name );

    my $a = gzopen($name, "w");
    my $text = "fred\n";
    my $len = length $text;
    $a->gzwrite($text);
    $a->gzwrite("\n\n");
    $a->gzclose ;

    for my $delim ( @( undef, "", 0, 1, "abc", $text, "\n\n", "\n" ) )
    {
        local $/ = $delim;
        my $u = gzopen($name, "r");
        my $line;
        is $u->gzreadline($line), length $text, "  read $len bytes";
        is $line, $text, "  got expected line";
        ok ! $u->gzclose, "  closed" ;
        is $/, $delim, '  $/ unchanged by gzreadline';
    }
};
