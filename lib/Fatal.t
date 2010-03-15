#!./perl -w

use Test::More 'no_plan'

use Fatal < qw(open close)

my $i = 1
try open: \*FOO, '<', 'lkjqweriuapofukndajsdlfjnvcvn'
like: $^EVAL_ERROR->{?description}, qr/^Can't open/

my $foo = 'FOO'
for ((@: "*$foo", "\\*$foo"))
    eval qq{ open $_, '<', '$^PROGRAM_NAME' }
    die: if $^EVAL_ERROR

    ok: (not ( $^EVAL_ERROR or (scalar:  ~< *FOO ) !~ m|^#!./perl| ))
    eval qq{ close *FOO }
    ok: ! $^EVAL_ERROR


try Fatal->import: 'print'
like: $^EVAL_ERROR->message
      qr{Cannot make the non-overridable builtin print fatal}

sub mysub($x)
    return $x

BEGIN
    Fatal->import: 'mysub'

is: (mysub: 1), 1

try mysub: 0
like: $^EVAL_ERROR->message
      qr{Can't mysub}
