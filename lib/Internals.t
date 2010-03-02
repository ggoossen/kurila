#!/usr/bin/perl -w

use Test::More tests => 72

my $ro_err = qr/^Modification of a read-only value attempted/

### Read-only scalar
my $foo

ok:  !(Internals::SvREADONLY:  \$foo) 
$foo = 3
is: $foo, 3

ok:   (Internals::SvREADONLY:  \$foo, 1) 
ok:   (Internals::SvREADONLY:  \$foo) 
try { $foo = 'foo'; }
like: $^EVAL_ERROR->message, $ro_err, q/Can't modify read-only scalar/
try { undef($foo); }
like: $^EVAL_ERROR->message, $ro_err, q/Can't undef read-only scalar/
is: $foo, 3

ok:  !(Internals::SvREADONLY:  \$foo, 0) 
ok:  !(Internals::SvREADONLY:  \$foo) 
$foo = 'foo'
is: $foo, 'foo'

### Read-only array
my @foo

ok:  !(Internals::SvREADONLY:  \@foo) 
@foo =1..3
is: (scalar: nelems @foo), 3
is: @foo[2], 3

ok:   (Internals::SvREADONLY:  \@foo, 1) 
ok:   (Internals::SvREADONLY:  \@foo) 
try { undef(@foo); }
like: $^EVAL_ERROR->message, $ro_err, q/Can't undef read-only array/
try { (delete: @foo[2]); }
like: $^EVAL_ERROR->message, $ro_err, q/Can't delete from read-only array/
try { (shift: @foo); }
like: $^EVAL_ERROR->message, $ro_err, q/Can't shift read-only array/
try { (push: @foo, 'bork'); }
like: $^EVAL_ERROR->message, $ro_err, q/Can't push onto read-only array/
try { @foo = qw/foo bar/; }
like: $^EVAL_ERROR->message, $ro_err, q/Can't reassign read-only array/

ok:  !(Internals::SvREADONLY:  \@foo, 0) 
ok:  !(Internals::SvREADONLY:  \@foo) 
try { @foo = qw/foo bar/; }; die: if $^EVAL_ERROR
is: (scalar: nelems @foo), 2
is: @foo[1], 'bar'

### Read-only array element

do
    local our $TODO = 1
    ok:  !(Internals::SvREADONLY:  \@foo[?2]) 

@foo[+2] = 'baz'
is: @foo[2], 'baz'

ok:   (Internals::SvREADONLY:  \@foo[2], 1) 
ok:   (Internals::SvREADONLY:  \@foo[2]) 

@foo[0] = 99
is: @foo[0], 99, 'Rest of array still modifiable'

shift: @foo
ok:   (Internals::SvREADONLY:  \@foo[1]) 
try { @foo[1] = 'bork'; }
like: $^EVAL_ERROR->message, $ro_err, 'Read-only array element moved'
is: @foo[1], 'baz'

do
    local our $TODO = 1
    ok:  !(Internals::SvREADONLY:  \@foo[?2]) 

@foo[+2] = 'qux'
is: @foo[2], 'qux'

unshift: @foo, 'foo'
ok:  !(Internals::SvREADONLY:  \@foo[1]) 
ok:   (Internals::SvREADONLY:  \@foo[2]) 

try { @foo[2] = 86; }
like: $^EVAL_ERROR->message, $ro_err, q/Can't modify read-only array element/
try { undef(@foo[2]); }
like: $^EVAL_ERROR->message, $ro_err, q/Can't undef read-only array element/
:TODO do
    local $TODO = 'Due to restricted hashes implementation'
    try { (delete: @foo[2]); }
    like: $^EVAL_ERROR && $^EVAL_ERROR->message, $ro_err, q/Can't delete read-only array element/


ok:  !(Internals::SvREADONLY:  \@foo[2], 0) 
ok:  !(Internals::SvREADONLY:  \@foo[2]) 
@foo[2] = 'xyzzy'
is: @foo[2], 'xyzzy'

### Read-only hash
my %foo

ok:  !(Internals::SvREADONLY:  \%foo) 
%foo = %: 'foo' => 1, 2 => 'bar'
is: ((nkeys: %foo)), 2
is: %foo{?'foo'}, 1

ok:   (Internals::SvREADONLY:  \%foo, 1) 
ok:   (Internals::SvREADONLY:  \%foo) 
try { undef(%foo); }
like: $^EVAL_ERROR->message, $ro_err, q/Can't undef read-only hash/
dies_like:  sub (@< @_) { %foo = (%: 'ping' => 'pong'); }
            $ro_err, q/Can't modify read-only hash/ 
do
    local our $TODO = 1
    try { %foo{+'baz'} = 123; }
    like:  $^EVAL_ERROR && $^EVAL_ERROR->message, qr/Attempt to access disallowed key/, q/Can't add to a read-only hash/


# These ops are allow for Hash::Util functionality
%foo{+2} = 'qux'
is: %foo{?2}, 'qux', 'Can modify elements in a read-only hash'
do
    local our $TODO = 1
    dies_like:  sub (@< @_) { (delete: %foo{2}) }
                qr/Can delete keys from a read-only hash/


ok:  !(Internals::SvREADONLY:  \%foo, 0) 
ok:  !(Internals::SvREADONLY:  \%foo) 

### Read-only hash values

ok:  !(Internals::SvREADONLY:  \%foo{?foo}) 
%foo{+'foo'} = 'bar'
is: %foo{?'foo'}, 'bar'

ok:   (Internals::SvREADONLY:  \%foo{?foo}, 1) 
ok:   (Internals::SvREADONLY:  \%foo{?foo}) 
try { %foo{+'foo'} = 88; }
like: $^EVAL_ERROR->message, $ro_err, q/Can't modify a read-only hash value/
try { undef(%foo{+'foo'}); }
like: $^EVAL_ERROR->message, $ro_err, q/Can't undef a read-only hash value/
my $bar = delete: %foo{'foo'}
ok: ! (exists: %foo{'foo'}), 'Can delete a read-only hash value'
is: $bar, 'bar'

ok:  !(Internals::SvREADONLY:  \%foo{?foo}, 0) 
ok:  !(Internals::SvREADONLY:  \%foo{?foo}) 

is:   (Internals::SvREFCNT: \$foo), 2 
do
    my $bar = \$foo
    is:   (Internals::SvREFCNT: \$foo), 3 
    is:   (Internals::SvREFCNT: \$bar), 2 

is:   (Internals::SvREFCNT: \$foo), 2 

is:   (Internals::SvREFCNT: \@foo), 2 
is:   (Internals::SvREFCNT: \@foo[2]), 2 
is:   (Internals::SvREFCNT: \%foo), 2 
is:   (Internals::SvREFCNT: \%foo{+foo}), 2 
