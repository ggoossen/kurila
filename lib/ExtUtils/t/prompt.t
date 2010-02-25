#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use Test::More tests => 11
use ExtUtils::MakeMaker

eval q{
    prompt();
}
like:  $^EVAL_ERROR->{description}, qr/^Not enough arguments for ExtUtils::MakeMaker::prompt/
       'no args' 

try {
    (prompt: undef);
}
like:  $^EVAL_ERROR->{description}, qr/^prompt function called without an argument/
       'undef message' 

my $stdout = \$( '' )
open: my $stdout_fh, '>>', $stdout or die: 
$^STDOUT = $stdout_fh->*{IO}


(env::var: 'PERL_MM_USE_DEFAULT' ) = 1
is:  (prompt: "Foo?"), '',     'no default' 
like:  $stdout->$,  qr/^Foo\?\s*\n$/,      '  question' 
$stdout->$ = ''

is:  (prompt: "Foo?", undef), '',     'undef default' 
like:  $stdout->$,  qr/^Foo\?\s*\n$/,      '  question' 
$stdout->$ = ''

is:  (prompt: "Foo?", 'Bar!'), 'Bar!',     'default' 
like:  $stdout->$,  qr/^Foo\? \[Bar!\]\s+Bar!\n$/,      '  question' 
$stdout->$ = ''


do
    (env::var: 'PERL_MM_USE_DEFAULT' ) = 0
    close $^STDIN
    my $stdin = ''
    open: my $stdin_fh, '<', \$stdin or die: 
    $^STDIN = $stdin_fh->*{IO}
    $stdin .= "From STDIN"
    ok:  !-t $^STDIN,      'STDIN not a tty' 

    is:  (prompt: "Foo?", 'Bar!'), 'From STDIN',     'from STDIN' 
    like:  $stdout->$,  qr/^Foo\? \[Bar!\]\s*$/,      '  question' 
    $stdout->$ = ''

