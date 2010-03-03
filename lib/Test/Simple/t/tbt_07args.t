#!/usr/bin/perl -w

use Test::More tests => 18
use Symbol
use Test::Builder
use Test::Builder::Tester


# argh! now we need to test the thing we're testing.  Basically we need
# to pretty much reimplement the whole code again.  This is very
# annoying but can't be avoided.  And onwards with the cut and paste

# My brain is melting.  My brain is melting.  ETOOMANYLAYERSOFTESTING

my $out = Test::Builder::Tester::Tie->new: "STDOUT"
my $err = Test::Builder::Tester::Tie->new: "STDERR"

# ooooh, use the test suite
my $t = Test::Builder->new: 

# remember the testing outputs
my $original_output_handle
my $original_failure_handle
my $original_todo_handle
my $testing_num
my $original_harness_env

sub start_testing
    # remember what the handles were set to
    $original_output_handle  = $t->output
    $original_failure_handle = $t->failure_output
    $original_todo_handle    = $t->todo_output
    $original_harness_env    = env::var: 'HARNESS_ACTIVE'

    # switch out to our own handles
    $t->output: $out->handle
    $t->failure_output: $err->handle
    $t->todo_output: $err->handle

    (env::var: 'HARNESS_ACTIVE' ) = 0

    # clear the expected list
    $out->reset
    $err->reset

    # remeber that we're testing
    $testing_num = $t->current_test: 
    ($t->current_test: ) = 0


# each test test is actually two tests.  This is bad and wrong
# but makes blood come out of my ears if I don't at least simplify
# it a little this way

sub my_test_test
    my $text = shift
    local $^WARNING = 0

    # reset the outputs
    $t->output: $original_output_handle
    $t->failure_output: $original_failure_handle
    $t->todo_output: $original_todo_handle
    (env::var: 'HARNESS_ACTIVE' ) = $original_harness_env

    # reset the number of tests
    ($t->current_test: ) = $testing_num

    # check we got the same values
    my $got
    my $wanted

    # stdout
    $t->ok:  $out->check, "STDOUT $text"

    # stderr
    $t->ok:  $err->check, "STDERR $text"


####################################################################
# Meta meta tests
####################################################################

# this is a quick test to check the hack that I've just implemented
# actually does a cut down version of Test::Builder::Tester

(start_testing: )
$out->expect: "ok 1 - foo"
pass: "foo"
my_test_test: "basic meta meta test"

(start_testing: )
$out->expect: "not ok 1 - foo"
$err->expect: "#     Failed test ($^PROGRAM_NAME at line ".(line_num: 1).")"
fail: "foo"
my_test_test: "basic meta meta test 2"

(start_testing: )
$out->expect: "ok 1 - bar"
test_out: "ok 1 - foo"
pass: "foo"
test_test: "bar"
my_test_test: "meta meta test with tbt"

(start_testing: )
$out->expect: "ok 1 - bar"
test_out: "not ok 1 - foo"
test_err: "#     Failed test ($^PROGRAM_NAME at line ".(line_num: 1).")"
fail: "foo"
test_test: "bar"
my_test_test: "meta meta test with tbt2 "

####################################################################
# Actual meta tests
####################################################################

# set up the outer wrapper again
(start_testing: )
$out->expect: "ok 1 - bar"

# set up what the inner wrapper expects
test_out: "ok 1 - foo"

# the actual test function that we are testing
ok: "1","foo"

# test the name
test_test: name => "bar"

# check that passed
my_test_test: "meta test name"

####################################################################

# set up the outer wrapper again
(start_testing: )
$out->expect: "ok 1 - bar"

# set up what the inner wrapper expects
test_out: "ok 1 - foo"

# the actual test function that we are testing
ok: "1","foo"

# test the name
test_test: title => "bar"

# check that passed
my_test_test: "meta test title"

####################################################################

# set up the outer wrapper again
(start_testing: )
$out->expect: "ok 1 - bar"

# set up what the inner wrapper expects
test_out: "ok 1 - foo"

# the actual test function that we are testing
ok: "1","foo"

# test the name
test_test: label => "bar"

# check that passed
my_test_test: "meta test title"

####################################################################

# set up the outer wrapper again
(start_testing: )
$out->expect: "ok 1 - bar"

# set up what the inner wrapper expects
test_out: "not ok 1 - foo this is wrong"
test_fail: 3

# the actual test function that we are testing
ok: "0","foo"

# test that we got what we expect, ignoring our is wrong
test_test: skip_out => 1, name => "bar"

# check that that passed
my_test_test: "meta test skip_out"

####################################################################

# set up the outer wrapper again
(start_testing: )
$out->expect: "ok 1 - bar"

# set up what the inner wrapper expects
test_out: "not ok 1 - foo"
test_err: "this is wrong"

# the actual test function that we are testing
ok: "0","foo"

# test that we got what we expect, ignoring err is wrong
test_test: skip_err => 1, name => "bar"

# diagnostics failing out
# check that that passed
my_test_test: "meta test skip_err"

####################################################################
