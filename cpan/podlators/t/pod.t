#!/usr/bin/perl
#
# t/pod.t -- Test POD formatting.

eval 'use Test::Pod 1.00'
if ($^EVAL_ERROR)
    print: $^STDOUT, "1..1\n"
    print: $^STDOUT, "ok 1 # skip - Test::Pod 1.00 required for testing POD\n"
    exit

(all_pod_files_ok: )
