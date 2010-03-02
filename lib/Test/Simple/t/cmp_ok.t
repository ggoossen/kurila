#!/usr/bin/perl -w

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

require Test::Builder
my $TB = Test::Builder->create: 
$TB->level: 0

sub try_cmp_ok($left, $cmp, $right)

    my %expect
    %expect{+ok}    = eval "\$left $cmp \$right"
    %expect{+error} = $^EVAL_ERROR
    %expect{+error} =~ s/ at .*\n?//

    local $Test::Builder::Level = $Test::Builder::Level + 1
    my $ok = cmp_ok: $left, $cmp, $right
    $TB->is_num:  ! ! $ok, ! ! %expect{ok}

    my $diag = $err->$
    $err->$ = ""
    if( !$ok and %expect{?error} )
        $diag =~ s/^# //mg
        $TB->like:  $diag, "/\Q%expect{?error}\E/" 
    elsif( $ok )
        $TB->is_eq:  $diag, '' 
    else
        $TB->ok: 1
    



use Test::More
(Test::More->builder: )->no_ending: 1

my @Tests = @:
    \(@: 1, '==', 1)
    \(@: 1, '==', 2)
    \(@: "a", "eq", "b")
    \(@: "a", "eq", "a")
    \(@: 1, "+", 1)
    \(@: 1, "-", 1)

# These don't work yet.
if( 0 )
    #if( try { require overload } ) {
    require MyOverload

    my $cmp = Overloaded::Compare->new: "foo", 42
    my $ify = Overloaded::Ify->new: "bar", 23

    push: @Tests, (
              \(@: $cmp, '==', 42),
              \(@: $cmp, 'eq', "foo"),
              \(@: $ify, 'eq', "bar"),
              \(@: $ify, "==", 23),
              )


plan: tests => scalar nelems @Tests
$TB->plan: tests => (nelems @Tests) * 2

for my $test ( @Tests)
    try_cmp_ok: < $test->@

