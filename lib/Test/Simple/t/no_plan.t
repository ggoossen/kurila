#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use Test::More tests => 6

my $tb = Test::Builder->create: 
$tb->level: 0

#line 19
ok: !try { ($tb->plan: tests => undef) }
is: $^EVAL_ERROR->{?description}, "Got an undefined number of tests"

#line 23
ok: !try { ($tb->plan: tests => 0) }
is: $^EVAL_ERROR->{?description}, "You said to run 0 tests"

#line 27
ok: !try { ($tb->ok: 1) }
is:  $^EVAL_ERROR->{?description}, "You tried to run a test without a plan"
