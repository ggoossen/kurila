#!./perl

my $PERLIO

BEGIN 
    require './test.pl'
    unless (('PerlIO::Layer'->find: 'perlio'))
        print: $^STDOUT, "1..0 # Skip: not perlio\n"
        exit 0
    
    # Makes testing easier.
    (env::var: 'PERLIO' ) = 'stdio' if defined (env::var: 'PERLIO') && (env::var: 'PERLIO') eq ''
    if (defined (env::var: 'PERLIO') && (env::var: 'PERLIO') !~ m/^(stdio|perlio|mmap)$/)
        # We are not prepared for anything else.
        print: $^STDOUT, "1..0 # PERLIO='$((env::var: 'PERLIO'))' unknown\n"
        exit 0
    
    $PERLIO = defined (env::var: 'PERLIO') ?? (env::var: 'PERLIO') !! "(undef)"


use Config

my $DOSISH    = $^OS_NAME =~ m/^(?:MSWin32|os2|dos|NetWare)$/ ?? 1 !! 0
$DOSISH    = 1 if !$DOSISH and $^OS_NAME =~ m/^uwin/
my $NONSTDIO  = defined (env::var: 'PERLIO') && (env::var: 'PERLIO') ne 'stdio'     ?? 1 !! 0
my $FASTSTDIO = (config_value: 'd_faststdio') && (config_value: 'usefaststdio') ?? 1 !! 0
my $UTF8_STDIN
if ($^UNICODE ^&^ 1)
    if ($^UNICODE ^&^ 64)
        # Conditional on the locale
        $UTF8_STDIN = $^UTF8LOCALE
    else
        # Unconditional
        $UTF8_STDIN = 1
    
else
    $UTF8_STDIN = 0

my $NTEST = 32 - (($DOSISH || !$FASTSTDIO) ?? 7 !! 0) - ($DOSISH ?? 5 !! 0)
    + $UTF8_STDIN

sub PerlIO::F_UTF8 () { 0x00008000 } # from perliol.h

plan: tests => $NTEST

print: $^STDOUT, <<__EOH__
# PERLIO        = $PERLIO
# DOSISH        = $DOSISH
# NONSTDIO      = $NONSTDIO
# FASTSTDIO     = $FASTSTDIO
# UNICODE       = $^UNICODE
# UTF8LOCALE    = $^UTF8LOCALE
# UTF8_STDIN = $UTF8_STDIN
__EOH__

:SKIP do
    # FIXME - more of these could be tested without Encode or full perl
    skip: "miniperl does not have Encode", $NTEST if env::var: 'PERL_CORE_MINITEST'

    sub check
        my (@: $result, $expected, $id) =  @_
        # An interesting dance follows where we try to make the following
        # IO layer stack setups to compare equal:
        #
        # PERLIO     UNIX-like                   DOS-like
        #
        # unset / "" unix perlio / stdio [1]     unix crlf
        # stdio      unix perlio / stdio [1]     stdio
        # perlio     unix perlio                 unix perlio
        # mmap       unix mmap                   unix mmap
        #
        # [1] "stdio" if Configure found out how to do "fast stdio" (depends
        # on the stdio implementation) and in Perl 5.8, otherwise "unix perlio"
        #
        if ($NONSTDIO)
            # Get rid of "unix".
            shift $result if $result[0] eq "unix"
            # Change expectations.
            if ($FASTSTDIO)
                $expected[0] = env::var: 'PERLIO'
            else
                $expected[0] = (env::var: 'PERLIO') if $expected[0] eq "stdio"
            
        elsif (!$FASTSTDIO && !$DOSISH)
            splice: $result, 0, 2, "stdio"
                if (nelems: $result) +>= 2 &&
              $result[0] eq "unix" &&
              $result[1] eq "perlio"
        elsif ($DOSISH)
            splice: $result, 0, 2, "stdio"
                if (nelems: $result) +>= 2 &&
              $result[0] eq "unix" &&
              $result[1] eq "crlf"
        
        if ($DOSISH && (grep: { $_ eq 'crlf' }, $expected))
            # 5 tests potentially skipped because
            # DOSISH systems already have a CRLF layer
            # which will make new ones not stick.
            $expected = grep: { $_ ne 'crlf' }, $expected
        
        my $n = nelems $expected
        is: (nelems: $result), $n, "$id - layers == $n"
        for my $i (0 .. $n -1)
            my $j = $expected[$i]
            if (ref $j eq 'CODE')
                ok: ($j->& <: $result[$i]), "$id - $i is ok"
            else
                is: $result[$i], $j
                    (sprintf: "$id - $i is \%s"
                              defined $j ?? $j !! "undef")

    check: (PerlIO::get_layers: $^STDIN)
           $UTF8_STDIN ?? (@:  "stdio", "utf8" ) !! (@:  "stdio" )
           "STDIN"

    open: my $f, ">:crlf", "afile"

    check:  (PerlIO::get_layers: $f)
            qw(stdio crlf)
            "open :crlf"

    binmode: $f, ":pop" or die: "$^OS_ERROR"

    check: (PerlIO::get_layers: $f)
           qw(stdio)
           ":pop"

    binmode: $f, ":raw" or die: "$^OS_ERROR"

    check: (PerlIO::get_layers: $f)
           (@: "stdio")
           ":raw"

    binmode: $f, ":utf8"

    check: (PerlIO::get_layers: $f)
           qw(stdio utf8)
           ":utf8"

    binmode: $f, ":bytes"

    check: (PerlIO::get_layers: $f)
           (@:  "stdio" )
           ":bytes"

    binmode: $f, ":raw :crlf"

    check: (PerlIO::get_layers: $f)
           qw(stdio crlf)
           ":raw:crlf"

    binmode: $f, ":raw :encoding(latin1)" # "latin1" will be canonized

    # 7 tests potentially skipped.
    unless ($DOSISH || !$FASTSTDIO)
        my @results = PerlIO::get_layers: $f, details => 1

        # Get rid of the args and the flags.
        splice: @results, 1, 2 if $NONSTDIO

        check: @results
               (@: "stdio",    undef,        sub (@< @_) { @_[0] +> 0 }
                   "encoding", "iso-8859-1", sub (@< @_) { @_[0] ^&^ (PerlIO::F_UTF8: ) } )
               ":raw:encoding(latin1)"

    binmode: $f

    check: (PerlIO::get_layers: $f)
           (@: "stdio")
           "binmode"

    close $f

    do
        use open(IN => ":crlf", OUT => ":utf8")

        open: $f, "<", "afile"
        open: my $g, ">", "afile"

        check: (PerlIO::get_layers: $f, input  => 1)
               qw(stdio crlf)
               "use open IN"

        check: (PerlIO::get_layers: $g, output => 1)
               qw[stdio utf8]
               "use open OUT"

        close $f
        close $g

    1 while unlink: "afile"
