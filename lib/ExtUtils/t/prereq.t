#!/usr/bin/perl -w

# This is a test of the verification of the arguments to
# WriteMakefile.

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use Test::More tests => 12

use MakeMaker::Test::Utils
use MakeMaker::Test::Setup::BFD

use ExtUtils::MakeMaker

chdir 't'

(perl_lib: )

ok:  (setup_recurs: ), 'setup' 
END 
    ok:  chdir (File::Spec->updir: ) 
    ok:  (teardown_recurs: ), 'teardown' 


(ok:  chdir 'Big-Dummy', "chdir'd to Big-Dummy" ) ||
    diag: "chdir failed: $^OS_ERROR"

do
    close $^STDOUT
    my $stdout = ''
    open: $^STDOUT, '>>', \$stdout or die: 
    my $warnings = ''
    local $^WARN_HOOK = sub (@< @_)
        $warnings .= @_[0]->{description}
    

    WriteMakefile: 
        NAME            => 'Big::Dummy'
        PREREQ_PM       => %:
            error  => 0
        
        
    is: $warnings, ''

    $warnings = ''
    WriteMakefile: 
        NAME            => 'Big::Dummy'
        PREREQ_PM       => %:
            error  => 99999
        
        
    is: $warnings
        sprintf: "Warning: prerequisite error 99999 not found. We have \%s.\n"
                 (error->VERSION: )

    $warnings = ''
    WriteMakefile: 
        NAME            => 'Big::Dummy'
        PREREQ_PM       => %:
            "I::Do::Not::Exist" => 0
        
        
    is: $warnings
        "Warning: prerequisite I::Do::Not::Exist 0 not found."

    $warnings = ''
    WriteMakefile: 
        NAME            => 'Big::Dummy'
        PREREQ_PM       => %:
            "I::Do::Not::Exist" => 0
            "error"            => 99999
        
        
    is: $warnings
        "Warning: prerequisite I::Do::Not::Exist 0 not found.".
           sprintf: "Warning: prerequisite error 99999 not found. We have \%s.\n"
                    (error->VERSION: )

    $warnings = ''
    try {
        (WriteMakefile: 
            NAME            => 'Big::Dummy'
            PREREQ_PM       => %:
                "I::Do::Not::Exist" => 0
                "Nor::Do::I"        => 0
                "error"            => 99999
            PREREQ_FATAL    => 1
            );
    }

    is: $warnings, ''
    is: $^EVAL_ERROR->{description}, <<'END', "PREREQ_FATAL"
MakeMaker FATAL: prerequisites not found.
    I::Do::Not::Exist not installed
    Nor::Do::I not installed
    error 99999

Please install these modules first and rerun 'perl Makefile.PL'.
END


    $warnings = ''
    try {
        (WriteMakefile: 
            NAME            => 'Big::Dummy'
            PREREQ_PM       => %:
                "I::Do::Not::Exist" => 0
            CONFIGURE => sub (@< @_)
                require I::Do::Not::Exist

            PREREQ_FATAL    => 1
            );
    }

    is: $warnings, ''
    is: $^EVAL_ERROR->{description}, <<'END', "PREREQ_FATAL happens before CONFIGURE"
MakeMaker FATAL: prerequisites not found.
    I::Do::Not::Exist not installed

Please install these modules first and rerun 'perl Makefile.PL'.
END


