#!perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    



require Test::Simple::Catch
use env
my(@: $out, $err) =  (Test::Simple::Catch::caught: )
local (env::var: 'HARNESS_ACTIVE' ) = 0


# Can't use Test.pm, that's a 5.005 thing.
package My::Test

# This has to be a require or else the END block below runs before
# Test::Builder's own and the ending diagnostics don't come out right.
require Test::Builder
my $TB = Test::Builder->create: 
($TB->plan: tests => 16);

sub like
    $TB->like: < @_


sub is
    $TB->is_eq: < @_


sub main::err_ok($expect)
    my $got = $err->$
    $err->$ = ""

    return $TB->is_eq:  $got, $expect 



package main;

require Test::More;
my $Total = 27;
(Test::More->import: tests => $Total);

my $tb = (Test::More->builder: );
($tb->use_numbers: 0);

my $Filename = quotemeta $^PROGRAM_NAME;

# Preserve the line numbers.
#line 38
ok:  0, 'failing' 
(err_ok:  <<ERR )
#   Failed test 'failing'
#   at $^PROGRAM_NAME line 38.
ERR

#line 40
(is:  "foo", "bar", 'foo is bar?')
is:  undef, '',    'undef is empty string?'
is:  undef, 0,     'undef is 0?'
is:  '',    0,     'empty string is 0?' 
(err_ok:  <<ERR )
#   Failed test 'foo is bar?'
#   at $^PROGRAM_NAME line 40.
#          got: 'foo'
#     expected: 'bar'
#   Failed test 'undef is empty string?'
#   at $^PROGRAM_NAME line 41.
#          got: undef
#     expected: ''
#   Failed test 'undef is 0?'
#   at $^PROGRAM_NAME line 42.
#          got: undef
#     expected: 0
#   Failed test 'empty string is 0?'
#   at $^PROGRAM_NAME line 43.
#          got: ''
#     expected: '0'
ERR

#line 45
isnt: "foo", "foo", 'foo isnt foo?' 
isnt: undef, undef, 'undef isnt undef?'
(err_ok:  <<ERR )
#   Failed test 'foo isnt foo?'
#   at $^PROGRAM_NAME line 45.
#     'foo'
#         ne
#     'foo'
#   Failed test 'undef isnt undef?'
#   at $^PROGRAM_NAME line 46.
#     undef
#         ne
#     undef
ERR

#line 48
like:  "foo", '/that/',  'is foo like that' 
unlike:  "foo", '/foo/', 'is foo unlike foo' 
(err_ok:  <<ERR )
#   Failed test 'is foo like that'
#   at $^PROGRAM_NAME line 48.
#                   'foo'
#     doesn't match '/that/'
#   Failed test 'is foo unlike foo'
#   at $^PROGRAM_NAME line 49.
#                   'foo'
#           matches '/foo/'
ERR

# Nick Clark found this was a bug.  Fixed in 0.40.
# line 60
(like:  "bug", '/(%)/',   'regex with % in it' );
(err_ok:  <<ERR );
#   Failed test 'regex with \% in it'
#   at $^PROGRAM_NAME line 60.
#                   'bug'
#     doesn't match '/(\%)/'
ERR

#line 67
(fail: 'fail()');
(err_ok:  <<ERR );
#   Failed test 'fail()'
#   at $^PROGRAM_NAME line 67.
ERR

#line 52
can_ok: 'Mooble::Hooble::Yooble', < qw(this that)
(can_ok: 'Mooble::Hooble::Yooble', ())
can_ok: undef, undef
(can_ok: \$@, "foo");
(err_ok:  <<ERR );
#   Failed test 'Mooble::Hooble::Yooble->can(...)'
#   at $^PROGRAM_NAME line 52.
#     Mooble::Hooble::Yooble->can('this') failed
#     Mooble::Hooble::Yooble->can('that') failed
#   Failed test 'Mooble::Hooble::Yooble->can(...)'
#   at $^PROGRAM_NAME line 53.
#     can_ok() called with no methods
#   Failed test '->can(...)'
#   at $^PROGRAM_NAME line 54.
#     can_ok() called with empty class or reference
#   Failed test 'ARRAY->can('foo')'
#   at $^PROGRAM_NAME line 55.
#     ARRAY->can('foo') failed
ERR

#line 55
isa_ok: (bless: \$@, "Foo"), "Wibble"
isa_ok: 42,    "Wibble", "My Wibble"
isa_ok: undef, "Wibble", "Another Wibble"
isa_ok: \$@,    "HASH"
(err_ok:  <<ERR )
#   Failed test 'The object isa Wibble'
#   at $^PROGRAM_NAME line 55.
#     The object isn't a 'Wibble' it's a 'Foo'
#   Failed test 'My Wibble isa Wibble'
#   at $^PROGRAM_NAME line 56.
#     My Wibble isn't a reference
#   Failed test 'Another Wibble isa Wibble'
#   at $^PROGRAM_NAME line 57.
#     Another Wibble isn't defined
#   Failed test 'The object isa HASH'
#   at $^PROGRAM_NAME line 58.
#     The object isn't a 'HASH' it's a 'ARRAY'
ERR

#line 68
cmp_ok:  'foo', 'eq', 'bar', 'cmp_ok eq' 
cmp_ok:  42.1,  '==', 23,  , '       ==' 
cmp_ok:  42,    '!=', 42   , '       !=' 
cmp_ok:  1,     '&&', 0    , '       &&' 
err_ok:  <<ERR 
#   Failed test 'cmp_ok eq'
#   at $^PROGRAM_NAME line 68.
#          got: 'foo'
#     expected: 'bar'
#   Failed test '       =='
#   at $^PROGRAM_NAME line 69.
#          got: 42.1
#     expected: 23
#   Failed test '       !='
#   at $^PROGRAM_NAME line 70.
#     42
#         !=
#     42
#   Failed test '       &&'
#   at $^PROGRAM_NAME line 71.
#     1
#         &&
#     0
ERR


# line 196
(cmp_ok:  42,    'eq', "foo", '       eq with numbers' );
(err_ok:  <<ERR );
#   Failed test '       eq with numbers'
#   at $^PROGRAM_NAME line 196.
#          got: '42'
#     expected: 'foo'
ERR


do
    my $warnings
    local $^WARN_HOOK = sub (@< @_) { $warnings .= @_[0]->message: }

    local our $TODO = "Fix line numbers"

    # line 211
    cmp_ok:  42,    '==', "foo", '       == with strings' 
    err_ok:  <<ERR 
#   Failed test '       == with strings'
#   at $^PROGRAM_NAME line 211.
#          got: 42
#     expected: 'foo'
ERR
    My::Test::like:  $warnings
                     qq[/^Argument "foo" isn't numeric in .*/]

;


#line 84
use_ok: 'Hooble::mooble::yooble'

my $more_err_re = <<ERR;
#   Failed test 'use Hooble::mooble::yooble;'
#   at $Filename line 84\\.
#     Tried to use 'Hooble::mooble::yooble'.
#     Error:  Can't locate Hooble.* in \\\$\\\^INCLUDE_PATH .*
ERR

(My::Test::like: $err->$, "/^$more_err_re/");
$err->$ = "";


#line 85
require_ok: 'ALL::YOUR::BASE::ARE::BELONG::TO::US::wibble'
$more_err_re = <<ERR
#   Failed test 'require ALL::YOUR::BASE::ARE::BELONG::TO::US::wibble;'
#   at $Filename line 85\\.
#     Tried to require 'ALL::YOUR::BASE::ARE::BELONG::TO::US::wibble'.
#     Error:  Can't locate ALL.* in \\\$\\\^INCLUDE_PATH .*
ERR

(My::Test::like: $err->$, "/^$more_err_re/");
$err->$ = ""


#line 88
END 
    $TB->is_eq: $out->$, <<OUT, 'failing output'
1..$Total
not ok - failing
not ok - foo is bar?
not ok - undef is empty string?
not ok - undef is 0?
not ok - empty string is 0?
not ok - foo isnt foo?
not ok - undef isnt undef?
not ok - is foo like that
not ok - is foo unlike foo
not ok - regex with \% in it
not ok - fail()
not ok - Mooble::Hooble::Yooble->can(...)
not ok - Mooble::Hooble::Yooble->can(...)
not ok - ->can(...)
not ok - ARRAY->can('foo')
not ok - The object isa Wibble
not ok - My Wibble isa Wibble
not ok - Another Wibble isa Wibble
not ok - The object isa HASH
not ok - cmp_ok eq
not ok -        ==
not ok -        !=
not ok -        &&
not ok -        eq with numbers
not ok -        == with strings # TODO Fix line numbers
not ok - use Hooble::mooble::yooble;
not ok - require ALL::YOUR::BASE::ARE::BELONG::TO::US::wibble;
OUT

    err_ok:  <<ERR 
# Looks like you failed $($Total-1) tests of $Total.
ERR

    exit: 0

