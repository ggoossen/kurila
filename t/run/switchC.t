#!./perl -w

# Tests for the command-line switches

BEGIN
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @: '../lib'

BEGIN { require "./test.pl"; }

BEGIN 
    unless (('PerlIO::Layer'->find:  'perlio'))
        skip_all: "not perlio"
    


plan: tests => 6

my $r

my $tmpfile = (tempfile: )

my $b = pack: "C*", (unpack: "U0C*", (pack: "U",256))

$r = runperl:  switches => \(@:  '-CO', '-w' )
               prog     => 'use utf8; print: $^STDOUT, (chr: 256)'
               stderr   => 1 
like:  $r, qr/^$b(?:\r?\n)?$/s, '-CO: no warning on UTF-8 output' 

:SKIP do
    if (defined (env::var: 'PERL_UNICODE') &&
        ((env::var: 'PERL_UNICODE') eq "" || (env::var: 'PERL_UNICODE') =~ m/[SO]/))
        skip: qq[cannot test with PERL_UNICODE locale "" or /[SO]/], 1
    
    $r = runperl:  switches => \(@:  '-CI', '-w' )
                   prog     => 'use utf8; print: $^STDOUT, ord: ~< $^STDIN'
                   stderr   => 1
                   stdin    => $b 
    like:  $r, qr/^256(?:\r?\n)?$/s, '-CI: read in UTF-8 input' 


$r = runperl:  switches => \(@:  '-CE', '-w' )
               prog     => 'use utf8; warn: chr: 256'
               stderr   => 1 
like:  $r, qr/^$b at -e line 1 character \d+.$/s, '-CE: UTF-8 stderr' 

$r = runperl:  switches => \(@:  '-Co', '-w' )
               prog     => 'use utf8; open: my $f, q(>), q(out) or die: $^OS_ERROR; print: $f, chr: 256; close: $f', stderr   => 1 
like:  $r, qr/^$/s, '-Co: auto-UTF-8 open for output' 

$r = runperl:  switches => \(@:  '-Ci', '-w' )
               prog     => 'use utf8; open: my $f, q(<), q(out); print: $^STDOUT, ord: ~< $f; close: $f'
               stderr   => 1 
like:  $r, qr/^256(?:\r?\n)?$/s, '-Ci: auto-UTF-8 open for input' 

require utf8
$r = runperl:  switches => \(@:  '-CA', '-w' )
               prog     => 'use utf8; print: $^STDOUT, ord: shift: @ARGV'
               stderr   => 1
               args     => \(@:  (utf8::chr: 256) ) 
like:  $r, qr/^256(?:\r?\n)?$/s, '-CA: @ARGV' 

