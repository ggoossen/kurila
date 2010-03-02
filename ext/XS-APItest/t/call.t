#!perl -w

# test the various call-into-perl-from-C functions
# DAPM Aug 2004

use TestInit
use Config

use warnings

use Test::More

use XS::APItest

plan: skip_all => "Figure out what this should do"

#########################

sub f
    shift
    unshift: @_, 'b'
    pop @_
    'x'


sub d
    no warnings 'misc' # keep G_KEEPERR from emitting this as a warning
    die: "its_dead_jim\n"


my $obj = bless: \$@, 'Foo'

sub Foo::meth
    return 'bad_self' unless (nelems @_) && ref @_[0] && (ref: @_[0]) eq 'Foo'
    shift
    shift
    unshift: @_, 'b'
    pop @_
    'x'


sub Foo::d
    no warnings 'misc' # keep G_KEEPERR from emitting this as a warning
    die: "its_dead_jim\n"


do 
    local our $TODO = 1
    is: (eval_sv: 'q{x}', G_SCALAR), q{x}, "eval_sv G_SCALAR"


for my $test ( @:
    # flags      args           expected         description
    \(@:  G_SCALAR,  \$@,           'x',     '0 args, G_SCALAR' )
    \(@:  G_SCALAR,  \qw(a p q), 'x',     '3 args, G_SCALAR' )
    \(@:  G_DISCARD, \$@,           undef,       '0 args, G_DISCARD' )
    \(@:  G_DISCARD, \qw(a p q), undef,       '3 args, G_DISCARD' )
    )
    my (@: $flags, $args, $expected, $description) = $test->@

    (is: (call_sv: \&f, $flags, < $args->@), $expected
         "$description call_sv(\\&f)")

    (is: (call_sv: *f,  $flags, < $args->@), $expected
         "$description call_sv(*f)")

    (is: (call_pv: 'f', $flags, < $args->@), $expected
         "$description call_pv('f')")

    (is: (call_method: 'meth', $flags, $obj, < $args->@), $expected
         "$description call_method('meth')")

    my $returnval = ((($flags ^&^ G_WANT) == G_ARRAY) || ($flags ^&^ G_DISCARD))
       ?? \(@: 0) !! \(@:  undef, 1 )
    for my $keep (@: 0, G_KEEPERR)
        local our $TODO = $keep
        my $desc = $description . ($keep ?? ' G_KEEPERR' !! '')
        my $exp_err = $keep ?? "before\n\t(in cleanup) its_dead_jim\n"
            !! "its_dead_jim\n"

        $^EVAL_ERROR = "before\n"
        (is: (call_pv: 'd', $flags^|^G_EVAL^|^$keep, < $args->@)
             undef
             "$desc G_EVAL call_pv('d')")
        (is: $^EVAL_ERROR->{description}, $exp_err
             "$desc G_EVAL call_pv('d') - \$@")

        # 	$^EVAL_ERROR = "before\n";
        # 	is(eval_sv('d()', $flags^|^$keep),
        # 		    $returnval,
        # 		    "$desc eval_sv('d()')");
        # 	is($^EVAL_ERROR->{description}, $exp_err, "$desc eval_sv('d()') - \$@");

        $^EVAL_ERROR = "before\n"
        (is: (call_method: 'd', $flags^|^G_EVAL^|^$keep, $obj, < $args->@)
             undef
             "$desc G_EVAL call_method('d')")
        (is: $^EVAL_ERROR->{description}, $exp_err, "$desc G_EVAL call_method('d') - \$@")
    

    (ok: (eq_array:  \(@:  try { < (call_pv: 'd', $flags, < $args->@) }, $^EVAL_ERROR->{description} )
                     \(@:  "its_dead_jim\n" )), "$description eval \{ call_pv('d') \}")

    (ok: (eq_array:  \(@:  try { < (eval_sv: 'd', $flags), $^EVAL_ERROR && < ($^EVAL_ERROR->message: ) }, $^EVAL_ERROR && ($^EVAL_ERROR->message: ) )
                     \(@:  < $returnval->@
                           "its_dead_jim\n", '' ))
         "$description eval \{ eval_sv('d') \}")

    (ok: (eq_array:  \(@:  try { < (call_method: 'd', $flags, $obj, < $args->@) }, $^EVAL_ERROR->{description} )
                     \(@:  "its_dead_jim\n" )), "$description eval \{ call_method('d') \}")

;

    is: (eval_pv: 'f()', 0), 'y', "eval_pv('f()', 0)"
is: (eval_pv: 'f(qw(a b c))', 0), 'y', "eval_pv('f(qw(a b c))', 0)"
is: (eval_pv: 'd()', 0), undef, "eval_pv('d()', 0)"
is: $^EVAL_ERROR->{description}, "its_dead_jim\n", "eval_pv('d()', 0) - \$^EVAL_ERROR"
is: try { (eval_pv: 'd()', 1) } , undef, "eval \{ eval_pv('d()', 1) \}"
is: $^EVAL_ERROR->{description}, "its_dead_jim\n", "eval \{ eval_pv('d()', 1) \} - \$^EVAL_ERROR"

