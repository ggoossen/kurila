#!./perl -w

BEGIN
    require './test.pl'

use Config
plan: tests => 1

:SKIP do
    skip: "setpgrp() is not available", 2 unless config_value: 'd_setpgrp'
    dies_like:  { package A;sub foo { (die: "got here") }; package main; (A->foo: (setpgrp: ))}
                qr/got here/, "setpgrp() should extend the stack before modifying it"
