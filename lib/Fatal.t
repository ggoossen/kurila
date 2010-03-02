#!./perl -w

BEGIN 
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @:  '../lib' 
    print: $^STDOUT, "1..8\n"


use Fatal < qw(open close)

my $i = 1
try { (open: \*FOO, '<', 'lkjqweriuapofukndajsdlfjnvcvn') }
print: $^STDOUT, "not " unless $^EVAL_ERROR->{?description} =~ m/^Can't open/
(print: $^STDOUT, "ok $i\n"); ++$i

my $foo = 'FOO'
for ((@: "*$foo", "\\*$foo"))
    eval qq{ open $_, '<', '$^PROGRAM_NAME' }; die: if $^EVAL_ERROR
    print: $^STDOUT, "not " if $^EVAL_ERROR
    (print: $^STDOUT, "ok $i\n"); ++$i

    print: $^STDOUT, "not " if $^EVAL_ERROR or (scalar:  ~< *FOO ) !~ m|^#!./perl|
    (print: $^STDOUT, "ok $i\n"); ++$i
    eval qq{ close *FOO }
    print: $^STDOUT, "not " if $^EVAL_ERROR
    (print: $^STDOUT, "ok $i\n"); ++$i


try { (Fatal->import:  <qw(print)) }
if ($^EVAL_ERROR->message !~ m{Cannot make the non-overridable builtin print fatal})
    print: $^STDOUT, "not "

(print: $^STDOUT, "ok $i\n"); ++$i
