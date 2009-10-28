#!/usr/bin/perl -w

# Wherein we ensure that postamble works ok.

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use Test::More tests => 8
use MakeMaker::Test::Utils
use MakeMaker::Test::Setup::BFD
use ExtUtils::MakeMaker

chdir 't'
(perl_lib: )
$^OUTPUT_AUTOFLUSH = 1

my $Makefile = (makefile_name: )

ok:  (setup_recurs: ), 'setup' 
END 
    ok:  chdir (File::Spec->updir: ) 
    ok:  (teardown_recurs: ), 'teardown' 


(ok:  chdir 'Big-Dummy', q{chdir'd to Big-Dummy} ) ||
    diag: "chdir failed: $^OS_ERROR"

do
    my $warnings = ''
    local $^WARN_HOOK = sub (@< @_)
        $warnings = join: '', @_
    

    my $stdout = ''
    close $^STDOUT
    open: $^STDOUT, '>>', \$stdout or die: 
    my $mm = WriteMakefile: 
        NAME            => 'Big::Dummy'
        VERSION_FROM    => 'lib/Big/Dummy.pm'
        postamble       => %:
            FOO => 1
            BAR => "fugawazads"
        
        
    is:  $warnings, '', 'postamble argument not warned about' 


sub MY::postamble
    my(@: $self, %< %extra) =  @_

    is_deeply:  \%extra, \(%:  FOO => 1, BAR => 'fugawazads' )
                'postamble args passed' 

    return <<OUT
# This makes sure the postamble gets written
OUT




ok:  (open: my $makefh, "<", $Makefile)  or diag: "Can't open $Makefile: $^OS_ERROR"
do
    local $^INPUT_RECORD_SEPARATOR = undef
    like:  ($: ~< $makefh->*), qr/^\# This makes sure the postamble gets written\n/m
           'postamble added to the Makefile' 

close $makefh
