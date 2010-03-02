
use Test::More tests => 3

eval 'use kurila'
ok: ! $^EVAL_ERROR, "'use kurila' without version"

eval "use kurila v1.4"
ok: ! $^EVAL_ERROR, "'use kurila 1.4'"

eval "use kurila v1.99"
like: $^EVAL_ERROR->{?description}, qr/only version/
