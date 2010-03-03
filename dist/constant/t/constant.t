#!./perl

use warnings
our (@warnings, $fagwoosh, $putt, $kloong)
BEGIN                           # ...and save 'em for later
    $^WARN_HOOK = sub (@< @_) { (push: @warnings, @_[0]->{?description}) }

END { (print: $^STDERR, < @warnings) }

use Test::More tests => 88
my $TB = Test::More->builder: 

BEGIN { (use_ok: 'constant'); }

use constant PI         => 4 * atan2: 1, 1

ok: defined (PI: ),                          'basic scalar constant'
is: (substr: (PI: ), 0, 7), '3.14159',         '    in substr()'

sub deg2rad { (PI: )* @_[0] / 180 }

my $ninety = deg2rad: 90

cmp_ok: (abs: $ninety - 1.5707), '+<', 0.0001, '    in math expression'

use constant UNDEF1     => undef       # the right way
use constant UNDEF2     =>             # the weird way
use constant 'UNDEF3'                  # the 'short' way
use constant EMPTY      => ( )         # the right way for lists

is: (UNDEF1: ), undef,       'right way to declare an undef'
is: (UNDEF2: ), undef,       '    weird way'
is: (UNDEF3: ), undef,       '    short way'

# XXX Why is this way different than the other ones?
my @undef = @:  (UNDEF1: )
is:  (nelems: @undef), 1
is: @undef[0], undef

@undef = (UNDEF2: )
is:  (nelems @undef), 0
@undef = (UNDEF3: )
is:  (nelems @undef), 0
@undef = (EMPTY: )
is:  (nelems @undef), 0

use constant COUNTDOWN  => '54321'
use constant COUNTLIST  => < reverse: @:  1, 2, 3, 4, 5
use constant COUNTLAST  => ((COUNTLIST: ))[-1]

is: (COUNTDOWN: ), '54321'
my @cl = (COUNTLIST: )
is: (nelems: @cl), 5
is: (COUNTDOWN: ), join: '', @cl
is: (COUNTLAST: ), 1
is: ((COUNTLIST: ))[1], 4

use constant ABC        => 'ABC'
is: "abc$( (ABC: ))abc", "abcABCabc"

use constant DEF        => 'D', 'E', chr ord 'F'
is: "d e f $((join: ' ', (DEF: ))) d e f", "d e f D E F d e f"

use constant SINGLE     => "'"
use constant DOUBLE     => '"'
use constant BACK       => '\'
my $tt = (BACK: ). (SINGLE: ). (DOUBLE: )
is: $tt, q(\'")

use constant MESS       => q('"'\"'"\)
is: (MESS: ), q('"'\"'"\)
is: (length: (MESS: )), 8

use constant TRAILING   => '12 cats'
do
    local $^WARNING = 0
    cmp_ok: (TRAILING: ), '==', 12

is: (TRAILING: ), '12 cats'

use constant LEADING    => " \t1234"
cmp_ok: (LEADING: ), '==', 1234
is: (LEADING: ), " \t1234"

use constant ZERO1      => 0
use constant ZERO2      => 0.0
use constant ZERO3      => '0.0'
is: (ZERO1: ), '0'
is: (ZERO2: ), '0'
is: (ZERO3: ), '0.0'

do
    package Other
    use constant PI     => 3.141


cmp_ok: (abs: (PI: )- 3.1416), '+<', 0.0001
is: (Other::PI: ), 3.141

use constant E2BIG => ($^OS_ERROR = 7)
cmp_ok: (E2BIG: ), '==', 7
# This is something like "Arg list too long", but the actual message
# text may vary, so we can't test much better than this.
cmp_ok: (length: (E2BIG: )), '+>', 6

is: (nelems: @warnings), 0 or diag: join: "\n", @:  "unexpected warning", < @warnings

is: (nelems: @warnings), 0, "unexpected warning"

ok: 1

my $curr_test = $TB->current_test: 
use constant CSCALAR    => \"ok 37\n"
use constant CHASH      => \%:  foo => "ok 38\n" 
use constant CARRAY     => \(@:  undef, "ok 39\n" )
use constant CCODE      => sub (@< @_) { "ok @_[0]\n" }

my $output = $TB->output 
print: $output, $: (CSCALAR: )->$
print: $output, (CHASH: )->{?foo}
print: $output, (CARRAY: )->[1]
print: $output, (CCODE: )->& <: $curr_test+4

($TB->current_test: ) += 4

eval q{ CCODE->{foo} }
like: $^EVAL_ERROR->{?description}, qr/^Expected a HASH REF but got a CODE/


# Allow leading underscore
use constant _PRIVATE => 47
is: (_PRIVATE: ), 47

# Disallow doubled leading underscore
eval q{
    use constant __DISALLOWED => "Oops";
}
like: $^EVAL_ERROR->{?description}, qr/begins with '__'/

# Check on declared() and %declared. This sub should be EXACTLY the
# same as the one quoted in the docs!
sub declared($name)
    use constant v1.01              # don't omit this!
    $name =~ s/^::/main::/
    my $pkg = caller
    my $full_name = $name =~ m/::/ ?? $name !! "$($pkg)::$name"
    %constant::declared{?$full_name}


ok: declared: 'PI'
ok: %constant::declared{?'main::PI'}

ok: !declared: 'PIE'
ok: !%constant::declared{?'main::PIE'}

do
    package Other
    use constant IN_OTHER_PACK => 42
    main::ok:  main::declared:  'IN_OTHER_PACK'
    main::ok:  %constant::declared{?'Other::IN_OTHER_PACK'}
    main::ok:  main::declared:  'main::PI'
    main::ok:  %constant::declared{?'main::PI'}


ok: declared: 'Other::IN_OTHER_PACK'
ok: %constant::declared{?'Other::IN_OTHER_PACK'}

@warnings = $@
eval q{
    no warnings;
    use warnings 'constant';
    use constant 'BEGIN' => 1 ;
    use constant 'INIT' => 1 ;
    use constant 'CHECK' => 1 ;
    use constant 'UNITCHECK' => 1;
    use constant 'END' => 1 ;
    use constant 'DESTROY' => 1 ;
    use constant 'AUTOLOAD' => 1 ;
    use constant 'STDIN' => 1 ;
    use constant 'STDOUT' => 1 ;
    use constant 'STDERR' => 1 ;
    use constant 'ARGV' => 1 ;
    use constant 'ARGVOUT' => 1 ;
    use constant 'ENV' => 1 ;
    use constant 'INC' => 1 ;
    use constant 'SIG' => 1 ;
}

my @Expected_Warnings =
    @:
   qr/^Constant name 'BEGIN' is a Perl keyword/
   qr/^Constant name 'INIT' is a Perl keyword/
   qr/^Constant name 'CHECK' is a Perl keyword/
   qr/^Constant name 'UNITCHECK' is a Perl keyword/
   qr/^Constant name 'END' is a Perl keyword/
   qr/^Constant name 'DESTROY' is a Perl keyword/
   qr/^Constant name 'STDIN' is forced into package main::/
   qr/^Constant name 'STDOUT' is forced into package main::/
   qr/^Constant name 'STDERR' is forced into package main::/
   qr/^Constant name 'ARGV' is forced into package main::/
   qr/^Constant name 'ARGVOUT' is forced into package main::/
   qr/^Constant name 'ENV' is forced into package main::/
   qr/^Constant name 'INC' is forced into package main::/
   qr/^Constant name 'SIG' is forced into package main::/

# when run under "make test"
if (0+nelems @warnings == 0+nelems @Expected_Warnings)
    push: @warnings, ""
    push: @Expected_Warnings, qr/^$/
elsif ((nelems @warnings) == (nelems @Expected_Warnings) + 1)
    splice: @Expected_Warnings, 1, 0
            qr/^Prototype mismatch: sub main::BEGIN \(\) vs none/
else
    my $rule = " -" x 20
    diag: "/!\\ unexpected case: ", scalar nelems @warnings, " warnings\n$rule\n"
    diag: < map: { "  $_" }, @warnings
    diag: $rule, $^INPUT_RECORD_SEPARATOR


is: (nelems: @warnings), 0+nelems @Expected_Warnings

for my $idx (0..((nelems @warnings)-1))
    like: @warnings[$idx], @Expected_Warnings[$idx]


@warnings = $@


use constant \%:
    THREE  => 3
    FAMILY => \ qw( John Jane Sally )
    AGES   => \(%:  John => 33, Jane => 28, Sally => 3 )
    RFAM   => \(@:  \ qw( John Jane Sally ) )
    SPIT   => sub (@< @_) { shift }

is: (nelems: $:(FAMILY: )->@), (THREE: )
is: (nelems: $:(FAMILY: )->@), nelems (RFAM: )->[0]->@
is: (FAMILY: )->[2], (RFAM: )->[0]->[2]
is: (AGES: )->{?(FAMILY: )->[1]}, 28
is: (THREE: )**3, (SPIT: )->& <: (nelems $:(FAMILY: )->@)**3

# Allow name of digits/underscores only if it begins with underscore
do
    use warnings FATAL => 'constant'
    eval q{
        use constant '_1_2_3' => 'allowed';
    }
    die: if $^EVAL_ERROR
    ok:  $^EVAL_ERROR eq '' 


$fagwoosh = 'geronimo'
$putt = 'leutwein'
$kloong = 'schlozhauer'

do
    my @warnings
    local $^WARN_HOOK = sub (@< @_) { (push: @warnings, < @_) }
    eval 'use constant fagwoosh => 5; 1' or die: $^EVAL_ERROR

    is: "$((join: ' ',@warnings))", "", "No warnings if the typeglob exists already"

    my $value = eval 'fagwoosh'
    is: $^EVAL_ERROR, ''
    is: $value, 5

    my @value = @:  eval 'fagwoosh' 
    is: $^EVAL_ERROR, ''
    is_deeply: \@value, \(@: 5)

    eval 'use constant putt => 6, 7; 1' or die: $^EVAL_ERROR

    is: "$((join: ' ',@warnings))", "", "No warnings if the typeglob exists already"

    @value = eval 'putt'
    is: $^EVAL_ERROR, ''
    is_deeply: \@value, \(@: 6, 7)

    eval 'use constant "klong"; 1' or die: $^EVAL_ERROR

    is: "$((join: ' ',@warnings))", "", "No warnings if the typeglob exists already"

    $value = eval 'klong'
    is: $^EVAL_ERROR, ''
    is: $value, undef

    @value = eval 'klong'
    is: $^EVAL_ERROR, ''
    is_deeply: \@value, \undef

