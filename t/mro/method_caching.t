#!./perl


use warnings
no warnings 'redefine' # we do a lot of this
no warnings 'prototype' # we do a lot of this

require './test.pl'

do
    package MCTest::Base
    sub foo { return @_[1]+1 };

    package MCTest::Derived
    our @ISA = qw/MCTest::Base/;

    package Foo; our @FOO = @:  qw// 


# These are various ways of re-defining MCTest::Base::foo and checking whether the method is cached when it shouldn't be
my @testsubs = @: 
    sub (@< @_) { (is: ('MCTest::Derived'->foo: 0), 1); }
    sub (@< @_) { eval 'sub MCTest::Base::foo { return @_[1]+2 }'; (is: ('MCTest::Derived'->foo: 0), 2); }
    sub (@< @_) { eval 'sub MCTest::Base::foo(_, $x) { return $x+3 }'; (is: ('MCTest::Derived'->foo: 0), 3); }
    sub (@< @_) { eval 'sub MCTest::Base::foo(_, $x) { 4 }'; (is: ('MCTest::Derived'->foo: 0), 4); }
    sub (@< @_) { *MCTest::Base::foo = sub (@< @_) { @_[1]+5 }; (is: ('MCTest::Derived'->foo: 0), 5); }
    sub (@< @_) { (is: ('MCTest::Derived'->foo: 0), 5); }
    sub (@< @_) { *ASDF::asdf = sub (@< @_) { @_[1]+9 }; *MCTest::Base::foo = \&ASDF::asdf; (is: ('MCTest::Derived'->foo: 0), 9); }
    sub (@< @_) { undef *MCTest::Base::foo; try { ('MCTest::Derived'->foo: 0) }; (like: $^EVAL_ERROR->{?description}, qr/locate object method/); }
    sub (@< @_) { eval 'sub MCTest::Base::foo($);'; *MCTest::Base::foo = \&ASDF::asdf; (is: ('MCTest::Derived'->foo: 0), 9); }
    sub (@< @_) { *XYZ = sub (@< @_) { @_[1]+10 }; %MCTest::Base::{+foo} = \&XYZ; (is: ('MCTest::Derived'->foo: 0), 10); }
    sub (@< @_) { %MCTest::Base::{+foo} = sub (@< @_) { @_[1]+11 }; (is: ('MCTest::Derived'->foo: 0), 11); }

    sub (@< @_) { undef *MCTest::Base::foo; try { ('MCTest::Derived'->foo: 0) }; (like: $^EVAL_ERROR->{?description}, qr/locate object method/); }
    sub (@< @_) { eval 'package MCTest::Base; sub foo { @_[1]+12 }'; (is: ('MCTest::Derived'->foo: 0), 12); }
    sub (@< @_) { eval 'package ZZZ; sub foo { @_[1]+13 }'; *MCTest::Base::foo = \&ZZZ::foo; (is: ('MCTest::Derived'->foo: 0), 13); }
    sub (@< @_) { %MCTest::Base::{+foo} = sub (@< @_) { @_[1]+14 }; (is: ('MCTest::Derived'->foo: 0), 14); }
    # 5.8.8 fails this one
    sub (@< @_) { undef *MCTest::Base::; try { ('MCTest::Derived'->foo: 0) }; (like: $^EVAL_ERROR->{?description}, qr/locate object method/); }
    sub (@< @_) { eval 'package MCTest::Base; sub foo { @_[1]+15 }'; (is: ('MCTest::Derived'->foo: 0), 15); }
    sub (@< @_) { undef %MCTest::Base::; try { ('MCTest::Derived'->foo: 0) }; (like: $^EVAL_ERROR->{?description}, qr/locate object method/); }
    sub (@< @_) { eval 'package MCTest::Base; sub foo { @_[1]+16 }'; (is: ('MCTest::Derived'->foo: 0), 16); }
    sub (@< @_) { %MCTest::Base:: = $%; try { ('MCTest::Derived'->foo: 0) }; (like: $^EVAL_ERROR->{?description}, qr/locate object method/); }
    sub (@< @_) { eval 'package MCTest::Base; sub foo { @_[1]+17 }'; (is: ('MCTest::Derived'->foo: 0), 17); }
    # 5.8.8 fails this one too
    sub (@< @_) { eval 'package MCTest::Base; sub foo { @_[1]+18 }'; (is: ('MCTest::Derived'->foo: 0), 18); }
    

plan: tests => (scalar: nelems @testsubs)

for (@testsubs)
    ($_->& <: )
