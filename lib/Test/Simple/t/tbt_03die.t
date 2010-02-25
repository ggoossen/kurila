#!/usr/bin/perl

use Test::Builder::Tester tests => 1
use Test::More

try {
    (test_test: "foo");
}
like: $^EVAL_ERROR->{?description}
      "/Not testing\.  You must declare output with a test function first\./"
      "dies correctly on error"

