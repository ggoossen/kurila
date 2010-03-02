#!./perl -w

use Config

require "./test.pl"

my $file = "crlf$^PID.dat"
END 
    1 while unlink: $file


if (('PerlIO::Layer'->find:  'perlio'))
    plan: tests => 16
    ok: (open: my $foo,">:crlf",$file)
    ok: (print: $foo, 'a'.((('a' x 14).qq{\n}) x 2000) || (close: $foo))
    ok: (open: $foo,"<:crlf",$file)

    my $text
    do { local $^INPUT_RECORD_SEPARATOR = undef; $text = ~< $foo->* }
    is: (count_chars: $text, "\015\012"), 0
    is: (count_chars: $text, "\n"), 2000

    binmode: $foo
    seek: $foo,0,0
    do { local $^INPUT_RECORD_SEPARATOR = undef; $text = ~< $foo->* }
    is: (count_chars: $text, "\015\012"), 2000

    :SKIP
        do
        skip: "miniperl can't rely on loading PerlIO::scalar"
            if env::var: 'PERL_CORE_MINITEST'
        skip: "no PerlIO::scalar" unless (config_value: "extensions") =~ m!\bPerlIO/scalar\b!
        require PerlIO::scalar
        my $fcontents = join: "", map: {"$_\015\012"}, 10..100000
        open: my $fh, "<:crlf", \$fcontents
        local $^INPUT_RECORD_SEPARATOR = "12345"
        local $_ = ~< $fh
        my $pos = tell $fh # pos must be behind "12345", before "\n12346\n"
        seek: $fh, $pos, 0 or die: "Failed seek"
        $^INPUT_RECORD_SEPARATOR = "\n"
        my $s = ( ~< $fh ) . ~< $fh
        is: $s, "\n12346\n"
    

    ok: (close: $foo)

    # binmode :crlf should not cumulate.
    # Try it first once and then twice so that even UNIXy boxes
    # get to exercise this, for DOSish boxes even once is enough.
    # Try also pushing :utf8 first so that there are other layers
    # in between (this should not matter: CRLF layers still should
    # not accumulate).
    for my $utf8 ((@: '', ':utf8'))
        for my $binmode (1..2)
            open: my $foo_fh, ">", "$file"
            # require PerlIO; print PerlIO::get_layers($foo), "\n";
            for (1..$binmode)
                binmode: $foo_fh, "$utf8:crlf"
            # require PerlIO; print PerlIO::get_layers($foo), "\n";
            print: $foo_fh, "Hello\n"
            close $foo_fh
            open: $foo_fh, "<", "$file"
            binmode: $foo_fh
            my $foo = scalar ~< $foo_fh->*
            close $foo_fh
            print: $^STDOUT, (join: " ", (@:  "#", < (map: { (sprintf: '%02x', $_) }, (@:  (unpack: "C*", $foo)))))
                   "\n"
            ok: $foo =~ m/\x0d\x0a$/
            ok: $foo !~ m/\x0d\x0d/
        
    
else
    skip_all: "No perlio, so no :crlf"


sub count_chars($text, $chars)
    my $seen = 0
    $seen++ while $text =~ m/$chars/g
    return $seen

