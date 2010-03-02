#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    



use Test::More tests => 10
use Test::Builder
my $tb = Test::Builder->create
$tb->level: 0

ok: !try { ($tb->plan:  tests => 'no_plan' ); }
is: $^EVAL_ERROR->{?description}, "Number of tests must be a positive integer.  You gave it 'no_plan'"

my $foo = \$@
my @foo = @: $foo, 2, 3
ok: !try { ($tb->plan:  tests => $foo ) }
like: $^EVAL_ERROR->{?description}, qr/reference as string/

#line 25
ok: !try { ($tb->plan:  tests => -1 ) }
is: $^EVAL_ERROR->{?description}, "Number of tests must be a positive integer.  You gave it '-1'"

#line 29
ok: !try { ($tb->plan:  tests => '' ) }
is: $^EVAL_ERROR->{?description}, "You said to run 0 tests"

#line 33
ok: !try { ($tb->plan:  'wibble' ) }
is: $^EVAL_ERROR->{?description}, "plan() doesn't understand wibble"
