#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    unless (find PerlIO::Layer 'perlio') {
	print "1..0 # Skip: not perlio\n";
	exit 0;
    }
}

no utf8; # needed for use utf8 not griping about the raw octets

BEGIN { require "./test.pl"; }

plan(tests => 46);

$| = 1;

use bytes;
use utf8;

open(F,"+>:utf8",'a');
print F chr(0x100)."\xc2\xa3";
cmp_ok( tell(F), '==', 4, tell(F) );
print F "\n";
cmp_ok( tell(F), '>=', 5, tell(F) );
seek(F,0,0);
is( getc(F), chr(0x100) );
is( getc(F), "\xc2\xa3" );
is( getc(F), "\n" );
seek(F,0,0);
binmode(F,":bytes");
my $chr = bytes::chr(0xc4);
is( getc(F), $chr );
$chr = bytes::chr(0x80);
is( getc(F), $chr );
$chr = bytes::chr(0xc2);
is( getc(F), $chr );
$chr = bytes::chr(0xa3);
is( getc(F), $chr );
is( getc(F), "\n" );
seek(F,0,0);
binmode(F,":utf8");
is( scalar(<F>), "\x{100}\xc2\xa3\n" );
seek(F,0,0);
$buf = chr(0x200);
$count = read(F,$buf,2,1);
cmp_ok( $count, '==', 2 );
is( $buf, "\x{200}\x{100}\xc2\xa3" );
close(F);

{
    $a = chr(300); # This *is* UTF-encoded
    $b = chr(130); # This also.

    open F, ">:utf8", 'a' or die $!;
    print F $a,"\n";
    close F;

    open F, "<:utf8", 'a' or die $!;
    $x = <F>;
    chomp($x);
    is( $x, chr(300) );

    open F, "a" or die $!; # Not UTF
    binmode(F, ":bytes");
    $x = <F>;
    chomp($x);
    $chr = bytes::chr(196).bytes::chr(172);
    is( $x, $chr );
    close F;

    open F, ">:utf8", 'a' or die $!;
    binmode(F);  # we write a "\n" and then tell() - avoid CRLF issues.
    binmode(F,":utf8"); # turn UTF-8-ness back on
    print F $a;
    my $y;
    { my $x = tell(F);
      { use bytes; $y = length($a);}
      cmp_ok( $x, '==', $y );
  }

    print F $b,"\n";

    {
	my $x = tell(F);
        $y += 3;
	cmp_ok( $x, '==', $y );
    }

    close F;

    open F, "a" or die $!; # Not UTF
    binmode(F, ":bytes");
    $x = <F>;
    chomp($x);
    $chr = chr(300).chr(130);
    is( $x, $chr, sprintf('(%vd)', $x) );

    open F, "<:utf8", "a" or die $!;
    $x = <F>;
    chomp($x);
    close F;
    is( $x, chr(300).chr(130), sprintf('(%vd)', $x) );

    open F, ">", "a" or die $!;
    binmode(F, ":bytes:");

    # Now let's make it suffer.
    my $w;
    {
	use warnings 'utf8';
	local $SIG{__WARN__} = sub { $w = $_[0] };
	print F $a;
        ok( (!$@));
	ok( ! $w, , "No 'Wide character in print' warning" );
    }
}

# Hm. Time to get more evil.
open F, ">:utf8", "a" or die $!;
print F $a;
binmode(F, ":bytes");
print F chr(130)."\n";
close F;

open F, "<", "a" or die $!;
binmode(F, ":bytes");
$x = <F>; chomp $x;
$chr = chr(130);
is( $x, $a . $chr );

# Right.
open F, ">:utf8", "a" or die $!;
print F $a;
close F;
open F, ">>", "a" or die $!;
binmode(F, ":bytes");
print F bytes::chr(130)."\n";
close F;

open F, "<", "a" or die $!;
binmode(F, ":bytes");
$x = <F>; chomp $x;
SKIP: {
    skip("Defaulting to UTF-8 output means that we can't generate a mangled file")
	if $UTF8_OUTPUT;
    is( $x, $a . bytes::chr(130) );
}

# Now we have a deformed file.

SKIP: {
	my @warnings;
	open F, "<:utf8", "a" or die $!;
	$x = <F>; chomp $x;
	local $SIG{__WARN__} = sub { push @warnings, $_[0]; };
	eval { sprintf "%vd\n", $x };
	is (scalar @warnings, 1);
	like ($warnings[0], qr/Malformed UTF-8 character \(unexpected continuation byte 0x82, with no preceding start byte/);
}

close F;
unlink('a');

open F, ">:utf8", "a";
@a = map { chr(1 << ($_ << 2)) } 0..5; # 0x1, 0x10, .., 0x100000
unshift @a, chr(0); # ... and a null byte in front just for fun
print F @a;
close F;

my $c;

# read() should work on characters, not bytes
open F, "<:utf8", "a";
$a = 0;
my $failed;
for (@a) {
    unless (($c = read(F, $b, 1) == 1)  &&
            length($b)           == 1  &&
            ord($b)              == ord($_) &&
            tell(F)              == ($a += bytes::length($b))) {
        print '# ord($_)           == ', ord($_), "\n";
        print '# ord($b)           == ', ord($b), "\n";
        print '# length($b)        == ', length($b), "\n";
        print '# bytes::length($b) == ', bytes::length($b), "\n";
        print '# tell(F)           == ', tell(F), "\n";
        print '# $a                == ', $a, "\n";
        print '# $c                == ', $c, "\n";
	$failed++;
        last;
    }
}
close F;
is($failed, undef);

{
    my @a = ( [ 0x007F, "bytes" ],
	      [ 0x0080, "bytes" ],
	      [ 0x0080, "utf8"  ],
	      [ 0x0100, "utf8"  ] );
    my $t = 34;
    for my $u (@a) {
	for my $v (@a) {
	    # print "# @$u - @$v\n";
	    open F, ">a";
	    binmode(F, ":" . $u->[1]);
	    print F chr($u->[0]);
	    close F;

	    open F, "<a";
	    binmode(F, ":" . $u->[1]);

	    my $s = chr($v->[0]);
	    utf8::upgrade($s) if $v->[1] eq "utf8";

	    $s .= <F>;
	    is( $s, chr($v->[0]) . chr($u->[0]), 'rcatline utf8' );
	    close F;
	    $t++;
	}
    }
    # last test here 49
}

{
    # [perl #23428] Somethings rotten in unicode semantics
    open F, ">a";
    binmode F, ":utf8";
    syswrite(F, $a = chr(0x100));
    close F;
    is( ord($a), 0x100, '23428 syswrite should not downgrade scalar' );
    like( $a, qr/^\w+/, '23428 syswrite should not downgrade scalar' );
}

# sysread() and syswrite() tested in lib/open.t since Fcntl is used

{
    # <FH> on a :utf8 stream should complain immediately with -w
    # if it finds bad UTF-8 (:encoding(utf8) works this way)
    use warnings 'utf8';
    undef $@;
    local $SIG{__WARN__} = sub { $@ = shift };
    open F, ">a";
    binmode F;
    my ($chrE4, $chrF6) = ("\xE4", "\xF6");
    print F "foo", $chrE4, "\n";
    print F "foo", $chrF6, "\n";
    close F;
    open F, "<:utf8", "a";
    undef $@;
    my $line = <F>;
    my ($chrE4, $chrF6) = ("E4", "F6");
    like( $@, qr/utf8 "\\x$chrE4" does not map to Unicode .+ <F> line 1/,
	  "<:utf8 readline must warn about bad utf8");
    undef $@;
    $line .= <F>;
    like( $@, qr/utf8 "\\x$chrF6" does not map to Unicode .+ <F> line 2/,
	  "<:utf8 rcatline must warn about bad utf8");
    close F;
}

END {
    1 while unlink "a";
    1 while unlink "b";
}
