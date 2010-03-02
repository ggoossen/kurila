BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


use Test::Builder

# STDOUT must be unbuffered else our prints might come out after
# Test::More's.
$^OUTPUT_AUTOFLUSH = 1

BEGIN 
    (Test::Builder->new: )->no_header: 1


use Test::More tests => 1

print: $^STDOUT, "1..1\n"
(pass: )
