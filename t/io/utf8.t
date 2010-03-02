#!./perl

BEGIN 
    unless (('PerlIO::Layer'->find: 'perlio'))
        print: $^STDOUT, "1..0 # Skip: not perlio\n"
        exit 0
    


no utf8 # needed for use utf8 not griping about the raw octets

BEGIN { require "./test.pl"; }

plan: tests => 46

$^OUTPUT_AUTOFLUSH = 1

use bytes
use utf8

open: my $f,"+>:utf8",'a'
print: $f, (chr: 0x100)."\x[c2]\x[a3]"
cmp_ok:  (tell: $f), '==', 4, (tell: $f) 
print: $f, "\n"
cmp_ok:  (tell: $f), '+>=', 5, (tell: $f) 
seek: $f,0,0
is:  (getc: $f), (chr: 0x100) 
is:  (getc: $f), "\x[c2]\x[a3]" 
is:  (getc: $f), "\n" 
seek: $f,0,0
binmode: $f,":bytes"
my $chr = bytes::chr: 0xc4
is:  (getc: $f), $chr 
$chr = bytes::chr: 0x80
is:  (getc: $f), $chr 
$chr = bytes::chr: 0xc2
is:  (getc: $f), $chr 
$chr = bytes::chr: 0xa3
is:  (getc: $f), $chr 
is:  (getc: $f), "\n" 
seek: $f,0,0
binmode: $f,":utf8"
is:  (scalar:  ~< $f), "\x{100}\x[c2]\x[a3]\n" 
seek: $f,0,0
my $buf = chr: 0x200
my $count = read: $f,$buf,2,1
cmp_ok:  $count, '==', 2 
is:  $buf, "\x{200}\x{100}\x[c2]\x[a3]" 
close: $f

do
    $a = chr: 300 # This *is* UTF-encoded
    $b = chr: 130 # This also.

    open: $f, ">:utf8", 'a' or die: $^OS_ERROR
    print: $f, $a,"\n"
    close $f

    open: $f, "<:utf8", 'a' or die: $^OS_ERROR
    my $x = ~< $f
    chomp: $x
    is:  $x, (chr: 300) 

    open: $f, "<", "a" or die: $^OS_ERROR # Not UTF
    binmode: $f, ":bytes"
    $x = ~< $f
    chomp: $x
    $chr = (bytes::chr: 196).bytes::chr: 172
    is:  $x, $chr 
    close $f

    open: $f, ">:utf8", 'a' or die: $^OS_ERROR
    binmode: $f  # we write a "\n" and then tell() - avoid CRLF issues.
    binmode: $f,":utf8" # turn UTF-8-ness back on
    print: $f, $a
    my $y
    do { my $x = (tell: $f);
        do { use bytes; $y = (length: $a);};
        cmp_ok:  $x, '==', $y ;
    }

    print: $f, $b,"\n"

    do
        my $x = tell: $f
        $y += 3
        cmp_ok:  $x, '==', $y 
    

    close $f

    open: $f, "<", "a" or die: $^OS_ERROR # Not UT$f
    binmode: $f, ":bytes"
    $x = ~< $f
    chomp: $x
    $chr = (chr: 300).chr: 130
    is:  $x, $chr, (sprintf: '(%vd)', $x) 

    open: $f, "<:utf8", "a" or die: $^OS_ERROR
    $x = ~< $f
    chomp: $x
    close $f
    is:  $x, (chr: 300).(chr: 130), (sprintf: '(%vd)', $x) 

    open: $f, ">", "a" or die: $^OS_ERROR
    binmode: $f, ":bytes:"

    # Now let's make it suffer.
    my $w
    do
        use warnings 'utf8'
        local $^WARN_HOOK = sub (@< @_) { $w = @_[0] }
        print: $f, $a
        ok:  (!$^EVAL_ERROR)
        ok:  ! $w, , "No 'Wide character in print' warning" 


# Hm. Time to get more evil.
open: $f, ">:utf8", "a" or die: $^OS_ERROR
print: $f, $a
binmode: $f, ":bytes"
print: $f, (chr: 130)."\n"
close $f

open: $f, "<", "a" or die: $^OS_ERROR
binmode: $f, ":bytes"
my $x = ~< $f; chomp $x
$chr = chr: 130
is:  $x, $a . $chr 

# Right.
open: $f, ">:utf8", "a" or die: $^OS_ERROR
print: $f, $a
close $f
open: $f, ">>", "a" or die: $^OS_ERROR
binmode: $f, ":bytes"
print: $f, (bytes::chr: 130)."\n"
close $f

open: $f, "<", "a" or die: $^OS_ERROR
binmode: $f, ":bytes"
$x = ~< $f; chomp $x
is:  $x, $a . (bytes::chr: 130) 

# Now we have a deformed file.

:SKIP do
    my @warnings
    open: $f, "<:utf8", "a" or die: $^OS_ERROR
    $x = ~< $f; chomp $x
    local $^WARN_HOOK = sub (@< @_) { (push: @warnings, @_[0]->message); }
    try { (sprintf: "\%vd\n", $x) }
    is: nelems @warnings, 1
    like: @warnings[0], qr/Malformed UTF-8 character \(unexpected continuation byte 0x82, with no preceding start byte/


close $f
unlink: 'a'

open: $f, ">:utf8", "a"
my @a = map: { (chr: 1 << ($_ << 2)) }, 0..5 # 0x1, 0x10, .., 0x100000
unshift: @a, chr: 0 # ... and a null byte in front just for fun
print: $f, < @a
close $f

my $c

# read() should work on characters, not bytes
open: $f, "<:utf8", "a"
$a = 0
my $failed
for ( @a)
    unless (($c = (read: $f, $b, 1) == 1)  &&
        (length: $b)           == 1  &&
        (ord: $b)              == (ord: $_) &&
        (tell: $f)              == ($a += (bytes::length: $b)))
        print: $^STDOUT, '# ord($_)           == ', (ord: $_), "\n"
        print: $^STDOUT, '# ord($b)           == ', (ord: $b), "\n"
        print: $^STDOUT, '# length($b)        == ', (length: $b), "\n"
        print: $^STDOUT, '# bytes::length($b) == ', < (bytes::length: $b), "\n"
        print: $^STDOUT, '# tell($f)           == ', (tell: $f), "\n"
        print: $^STDOUT, '# $a                == ', $a, "\n"
        print: $^STDOUT, '# $c                == ', $c, "\n"
        $failed++
        last
    

close $f
is: $failed, undef

do
    my @a = @:  \(@:  0x007F, "bytes" )
                \(@:  0x0080, "bytes" )
                \(@:  0x0080, "utf8"  )
                \(@:  0x0100, "utf8"  ) 
    my $t = 34
    for my $u ( @a)
        for my $v ( @a)
            # print "# @$u - @$v\n";
            open: $f, ">", "a"
            binmode: $f, ":" . $u->[1]
            print: $f, chr: $u->[0]
            close $f

            open: $f, "<", "a"
            binmode: $f, ":" . $u->[1]

            my $s = chr: $v->[0]

            $s .= ~< $f
            is:  $s, (chr: $v->[0]) . (chr: $u->[0]), 'rcatline utf8' 
            close $f
            $t++
        
    
# last test here 49


do
    # [perl #23428] Somethings rotten in unicode semantics
    open: $f, ">", "a"
    binmode: $f, ":utf8"
    syswrite: $f, ($a = (chr: 0x100))
    close $f
    is:  (ord: $a), 0x100, '23428 syswrite should not downgrade scalar' 
    like:  $a, qr/^\p{IsWord}+/, '23428 syswrite should not downgrade scalar' 

# sysread() and syswrite() tested in lib/open.t since Fcntl is used

do
    # <FH> on a :utf8 stream should complain immediately with -w
    # if it finds bad UTF-8 (:encoding(utf8) works this way)
    use warnings 'utf8'
    undef $^EVAL_ERROR
    local $^WARN_HOOK = sub (@< @_) { $^EVAL_ERROR = shift }
    open: $f, ">", "a"
    binmode: $f
    my (@: $chrE4, $chrF6) = @: "\x[E4]", "\x[F6]"
    print: $f, "foo", $chrE4, "\n"
    print: $f, "foo", $chrF6, "\n"
    close $f
    open: $f, "<:utf8", "a"
    undef $^EVAL_ERROR
    my $line = ~< $f
    my (@: $chrE4, $chrF6) = @: "E4", "F6"
    like:  $^EVAL_ERROR->message, qr/utf8 "\\x$chrE4" does not map to Unicode/
           "<:utf8 readline must warn about bad utf8"
    undef $^EVAL_ERROR
    $line .= ~< $f
    like:  $^EVAL_ERROR->message, qr/utf8 "\\x$chrF6" does not map to Unicode/
           "<:utf8 rcatline must warn about bad utf8"
    close $f


END 
    1 while unlink: "a"
    1 while unlink: "b"
