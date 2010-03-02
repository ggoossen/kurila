#!./perl

use Test::More tests => 22

# open::import expects 'open' as its first argument, but it clashes with open()
sub import
    open::import:  'open', < @_ 


# can't use require_ok() here, with a name like 'open'
ok:  require 'open.pm', 'requiring open' 

# this should fail
try { (import: ) }
like:  $^EVAL_ERROR->{?description}, qr/needs explicit list of PerlIO layers/
       'import should fail without args' 

# prevent it from loading I18N::Langinfo, so we can test encoding failures
my $warn
local $^WARN_HOOK = sub (@< @_)
    $warn .= shift->{?description}


# and it shouldn't be able to find this layer
$warn = ''
eval q{ no warnings 'layer'; use open IN => ':macguffin' ; }
is:  $warn, ''
     'should not warn about unknown layer with bad layer provided' 

$warn = ''
eval q{ use warnings 'layer'; use open IN => ':macguffin' ; }
like:  $warn, qr/Unknown PerlIO layer/
       'should warn about unknown layer with bad layer provided' 

# open :locale logic changed since open 1.04, new logic
# difficult to test portably.

# see if it sets the magic variables appropriately
import:  'IN', ':crlf' 
is:  $^HINTS{?'open_IN'}, 'crlf', 'should have set crlf layer' 

# it should reset them appropriately, too
import:  'IN', ':raw' 
is:  $^HINTS{?'open_IN'}, 'raw', 'should have reset to raw layer' 

# it dies if you don't set IN, OUT, or IO
try { (import:  'sideways', ':raw' ) }
like:  $^EVAL_ERROR->{?description}, qr/Unknown PerlIO layer class/, 'should croak with unknown class' 

# but it handles them all so well together
import:  'IO', ':raw :crlf' 
is:  $^OPEN, ":raw :crlf\0:raw :crlf"
     'should set multi types, multi layer' 
is:  $^HINTS{?'open_IO'}, 'crlf', 'should record last layer set in %^H' 

:SKIP do
    skip: "no perlio, no :utf8", 12 unless ((PerlIO::Layer->find:  'perlio'))

    eval <<'EOE'
    use open ':utf8';
    use utf8;
    open(my $o, ">", "utf8");
    print $o, chr(0x100);
    close $o;
    open(my $i, "<", "utf8");
    is(ord(~<$i), 0x100, ":utf8 single wide character round-trip");
    close $i;
EOE
    die: if $^EVAL_ERROR

    open: my $f, ">", "a"
    my @a = map: { (chr: 1 << ($_ << 2)) }, 0..5 # 0x1, 0x10, .., 0x100000
    unshift: @a, chr: 0 # ... and a null byte in front just for fun
    print: $f, <@a
    close $f

    sub systell
        use Fcntl 'SEEK_CUR'
        sysseek: @_[0], 0, SEEK_CUR
    

    require bytes # not use

    my $ok
    my $c

    open: $f, "<:utf8", "a"
    $ok = $a = 0
    for (@a)
        unless (
              ($c = (sysread: $f, $b, 1)) == 1  &&
            (length: $b)               == 1  &&
            (ord: $b)                  == (ord: $_) &&
            (systell: $f)               == ($a += (bytes::length: $b))
            )
            print: $^STDOUT, '# ord($_)           == ', (ord: $_), "\n"
            print: $^STDOUT, '# ord($b)           == ', (ord: $b), "\n"
            print: $^STDOUT, '# length($b)        == ', (length: $b), "\n"
            print: $^STDOUT, '# bytes::length($b) == ', (bytes::length: $b), "\n"
            print: $^STDOUT, '# systell($f)        == ', (systell: $f), "\n"
            print: $^STDOUT, '# $a                == ', $a, "\n"
            print: $^STDOUT, '# $c                == ', $c, "\n"
            last
        
        $ok++
    
    close $f
    ok: $ok == (nelems @a)
        "on :utf8 streams sysread() should work on characters, not bytes"

    sub diagnostics
        print: $^STDOUT, '# ord($_)           == ', (ord: $_), "\n"
        print: $^STDOUT, '# bytes::length($_) == ', (bytes::length: $_), "\n"
        print: $^STDOUT, '# systell(G)        == ', (systell: 'G'), "\n"
        print: $^STDOUT, '# $a                == ', $a, "\n"
        print: $^STDOUT, '# $c                == ', $c, "\n"
    


    my $g
    my %actions = %:
        syswrite => sub (@< @_) { (syswrite: $g, shift); }
        'syswrite len' => sub (@< @_) { (syswrite: $g, shift, 1); }
        'syswrite len pad' => sub (@< @_)
            my $temp = (shift: ) . "\243"
            syswrite: $g, $temp, 1

        'syswrite off' => sub (@< @_)
            my $temp = "\351" . shift: 
            syswrite: $g, $temp, 1, 1

        'syswrite off pad' => sub (@< @_)
            my $temp = "\351" . (shift: ) . "\243"
            syswrite: $g, $temp, 1, 1
        

    foreach my $key ((sort: keys %actions))
        # syswrite() on should work on characters, not bytes
        open: $g, ">:utf8", "b"

        print: $^STDOUT, "# $key\n"
        $ok = $a = 0
        for (@a)
            unless (
                  ($c =( %actions{?$key}->& <: $_)) == 1 &&
                (systell: $g)                == ($a += (bytes::length: $_))
                )
                (diagnostics: )
                last
            
            $ok++
        
        close $g
        ok: $ok == (nelems @a)
            "on :utf8 streams syswrite() should work on characters, not bytes"

        open: $g, "<:utf8", "b"
        $ok = $a = 0
        for (@a)
            unless (
                  ($c = (sysread: $g, $b, 1)) == 1 &&
                (length: $b)               == 1 &&
                (ord: $b)                  == (ord: $_) &&
                (systell: $g)               == ($a += (bytes::length: $_))
                )
                print: $^STDOUT, '# ord($_)           == ', (ord: $_), "\n"
                print: $^STDOUT, '# ord($b)           == ', (ord: $b), "\n"
                print: $^STDOUT, '# length($b)        == ', (length: $b), "\n"
                print: $^STDOUT, '# bytes::length($b) == ', (bytes::length: $b), "\n"
                print: $^STDOUT, '# systell($g)        == ', (systell: $g), "\n"
                print: $^STDOUT, '# $a                == ', $a, "\n"
                print: $^STDOUT, '# $c                == ', $c, "\n"
                last
            
            $ok++
        
        close $g
        ok: $ok == (nelems @a)
            "checking syswrite() output on :utf8 streams by reading it back in"
    


:SKIP do
    skip: "no perlio", 1 unless ((PerlIO::Layer->find:  'perlio'))
    use open IN => ':non-existent';
    try {
        require Symbol; # Anything that exists but we havn't loaded
    }
    like: $^EVAL_ERROR->{?description}, qr/Can't locate Symbol|Recursive call/i
          "test for an endless loop in PerlIO_find_layer"


END 
    1 while unlink: "utf8"
    1 while unlink: "a"
    1 while unlink: "b"


# the test cases beyond __DATA__ need to be executed separately

__DATA__
$ENV{LC_ALL} = 'nonexistent.euc';
try { open::_get_locale_encoding() };
like( $@, qr/too ambiguous/, 'should die with ambiguous locale encoding' );
%%%
# the special :locale layer
$ENV{LC_ALL} = $ENV{LANG} = 'ru_RU.KOI8-R';
# the :locale will probe the locale environment variables like LANG
use open OUT => ':locale';
open(O, ">", "koi8");
print O chr(0x430); # Unicode CYRILLIC SMALL LETTER A = KOI8-R 0xc1
close O;
open(I, "<", "koi8");
printf "%#x\n", ord(~<*I), "\n"; # this should print 0xc1
close I;
%%%
