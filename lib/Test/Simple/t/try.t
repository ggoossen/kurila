#!perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    



use Test::More 'no_plan'

require Test::Builder
my $tb = Test::Builder->new: 

# These should not change;
local $^EVAL_ERROR = 42
local $^OS_ERROR = 23

is: ($tb->_try: sub (@< @_) { 2 }), 2
is: ($tb->_try: sub (@< @_) { return '' }), ''

is: ($tb->_try: sub (@< @_) { (die: ); }), undef

is_deeply: \(@: ($tb->_try: sub (@< @_) { (die: "Foo\n") }))
           \@: undef

is: $^EVAL_ERROR, 42
cmp_ok: $^OS_ERROR, '==', 23
