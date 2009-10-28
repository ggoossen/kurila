#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


my $Exit_Code
BEGIN 
    *CORE::GLOBAL::exit = sub (@< @_) { $Exit_Code = shift; }



use Test::Builder
use Test::More

my $output = ""
open: my $fakeout, '>>', \$output or die: 
my $TB = Test::More->builder: 
$TB->output: $fakeout

my $Test = Test::Builder->create: 
$Test->level: 0

$Test->plan: tests => 3


plan: tests => 4

BAIL_OUT: "ROCKS FALL! EVERYONE DIES!"


$Test->is_eq:  $output, <<'OUT' 
1..4
Bail out!  ROCKS FALL! EVERYONE DIES!
OUT

$output = ""
$Test->is_eq:  $Exit_Code, 255 

$Test->ok:  ($Test->can: "BAILOUT"), "Backwards compat" 
