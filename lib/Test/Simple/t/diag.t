#!perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    



use Test::More tests => 5

my $Test = Test::More->builder

# now make a filehandle where we can send data
my $output = ""
open: my $fakeout, '>>', \$output or die: 

# force diagnostic output to a filehandle, glad I added this to
# Test::Builder :)
my $ret
do
    local $TODO = 1
    $Test->todo_output: $fakeout

    diag: "a single line"

    $ret = diag: "multiple\n", "lines"


is:  $output, <<'DIAG',   'diag() with todo_output set' 
# a single line
# multiple
# lines
DIAG

ok:  !$ret, 'diag returns false' 

do
    $output = ""
    $Test->failure_output: $fakeout
    $ret = diag: "# foo"

$Test->failure_output: $^STDERR
is:  $output, "# # foo\n", "diag() adds # even if there's one already" 
ok:  !$ret,  'diag returns false' 


# [rt.cpan.org 8392]
do
    $output = ""
    $Test->failure_output: $fakeout
    diag:  <qw(one two)

$Test->failure_output: $^STDERR
is:  $output, <<'DIAG' 
# onetwo
DIAG
