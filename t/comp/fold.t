#!./perl

use TestInit

BEGIN 
    require './test.pl'

use warnings

plan: 13

# Historically constant folding was performed by evaluating the ops, and if
# they threw an exception compilation failed. This was seen as buggy, because
# even illegal constants in unreachable code would cause failure. So now
# illegal expressions are reported at runtime, if the expression is reached,
# making constant folding consistent with many other languages, and purely an
# optimisation rather than a behaviour change.


my $a
$a = eval '$b = 0/0 if 0; 3'
is: $a, 3
is: $^EVAL_ERROR, ""

my $b = 0
$a = eval 'if ($b) {return sqrt -3} 3'
is: $a, 3
is: $^EVAL_ERROR, ""

$a = eval q{
        $b = eval q{if ($b) {return log 0} 4};
        is ($b, 4);
        is ($^EVAL_ERROR, "");
        5;
}
is: $a, 5
is: $^EVAL_ERROR, ""

# warn and die hooks should be disabled during constant folding

do
    my $c = 0
    local $^WARN_HOOK = sub (@< @_) { $c++   }
    eval q{
        local $^DIE_HOOK = sub { $c+= 2 };
        is($c, 0, "premature warn/die: $c");
        my $x = "a"+5;
        is($c, 1, "missing warn hook");
        is($x, 5, "a+5");
        $c = 0;
        $x = 1/0;
    }
    like: $^EVAL_ERROR->{?description}, qr/division/, "eval caught division"
    is: $c, 2, "missing die hook"

