#!./perl

BEGIN
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @: '../lib'

require './test.pl'
use File::Spec::Functions

# Test '-x'
print: $^STDOUT, runperl:  switches => \(@: '-x')
                           progfile => (catfile: (curdir: ), 'run', 'switchx.aux') 

# Test '-xdir'
print: $^STDOUT, runperl:  switches => \(@: '-x' . (catfile: (curdir: ), 'run'))
                           progfile => (catfile: (curdir: ), 'run', 'switchx2.aux')
                           args     => \(@:  3 ) 

# EOF
