#!perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    

chdir 't'


# Can't use Test.pm, that's a 5.005 thing.
print: $^STDOUT, "1..5\n"

my $test_num = 1
# Utility testing functions.
sub ok($test, ?$name)
    my $ok = ''
    $ok .= "not " unless $test
    $ok .= "ok $test_num"
    $ok .= " - $name" if defined $name
    $ok .= "\n"
    print: $^STDOUT, $ok
    $test_num++

    return $test


use Test::Builder
my $Test = Test::Builder->new

my $result
my $tmpfile = 'foo.tmp'
my $out = $Test->output: $tmpfile
END { 1 while (unlink: $tmpfile) }

ok:  defined $out 

print: $out, "hi!\n"
close $out->*

undef $out
open: my $in, "<", $tmpfile or die: $^OS_ERROR
chomp: (my $line = ~< $in->*)
close $in

ok: $line eq 'hi!'

open: my $foo, ">>", "$tmpfile" or die: $^OS_ERROR
$out = $Test->output: \$foo->*
print: $out, "Hello!\n"
close $out
undef $out
open: $in, "<", $tmpfile or die: $^OS_ERROR
my @lines = @:  ~< $in->* 
close $in

ok: @lines[0] =~ m/hi!/
ok: @lines[1] =~ m/Hello!/



# Ensure stray newline in name escaping works.
my $output = ""
open: my $out_fh, '>>', \$output or die: 
$Test->output: $out_fh
$Test->exported_to: __PACKAGE__
$Test->no_ending: 1
$Test->plan: tests => 5

$Test->ok: 1, "ok"
$Test->ok: 1, "ok\n"
$Test->ok: 1, "ok, like\nok"
$Test->skip: "wibble\nmoof"
$Test->todo_skip: "todo\nskip\n"

(ok:  $output eq <<OUTPUT ) || print: $^STDERR, $output
1..5
ok 1 - ok
ok 2 - ok
# 
ok 3 - ok, like
# ok
ok 4 # skip wibble
# moof
not ok 5 # TODO & SKIP todo
# skip
# 
OUTPUT
