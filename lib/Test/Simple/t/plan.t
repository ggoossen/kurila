#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


use Test::More

plan: tests => 4
try { (plan: tests => 4) }
is:  $^EVAL_ERROR->{?description}, (sprintf: "You tried to plan twice")
     'disallow double plan' 
try { (plan: 'no_plan')  }
is:  $^EVAL_ERROR->{?description}, (sprintf: "You tried to plan twice")
     'disallow changing plan' 

pass: 'Just testing plan()'
pass: 'Testing it some more'
