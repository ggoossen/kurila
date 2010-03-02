#!/usr/bin/perl -w

use Test::More tests => 1

use base

do
    package Test::SIGDIE

    local $^DIE_HOOK = sub (@< @_)
        main::fail: 'sigdie not caught, this test should not run'
    
    try {
        ('base'->import:  <qw(Huh::Boo));
    }

    main::like: $^EVAL_ERROR->{?description}, qr/^Base class package "Huh::Boo" is empty/
                'Base class empty error message'

