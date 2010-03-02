#!./perl

use Test::More tests => 11
use env
require_ok:  're' 

# setcolor
$^INCLUDED{+'Term/Cap.pm' } = 1
local (env::var: 'PERL_RE_TC') = undef
(re::setcolor: )
is:  (env::var: 'PERL_RE_COLORS'), "md\tme\tso\tse\tus\tue"
     'setcolor() should provide default colors' 
(env::var: 'PERL_RE_TC' ) = 'su,n,ny'
(re::setcolor: )
is:  (env::var: 'PERL_RE_COLORS'), "su\tn\tny", '... or use %ENV{PERL_RE_COLORS}' 

# bits
# get on
my $warn
local $^WARN_HOOK = sub (@< @_)
    $warn = @_[0]->{?description}

#try { re::bits(1) };
#like( $warn, qr/Useless use/, 'bits() should warn with no args' );

(env::var: 'PERL_RE_COLORS') = undef
re::bits: 0, 'debug'
is:  (env::var: 'PERL_RE_COLORS'), undef
     "... should not set regex colors given 'debug'" 
re::bits: 0, 'debugcolor'
isnt:  (env::var: 'PERL_RE_COLORS'), ''
       "... should set regex colors given 'debugcolor'" 
re::bits: 0, 'nosuchsubpragma'
like:  $warn, qr/Unknown "re" subpragma/
       '... should warn about unknown subpragma' 
ok:  (re::bits: 0, 'eval')  ^&^ 0x00200000, '... should set eval bits' 

local $^HINT_BITS = undef

# import
re->import: 'eval'
ok:  $^HINT_BITS ^&^ 0x00200000, 'import should set eval bits in $^H when requested' 

re->unimport: 'taint'
ok:  !( $^HINT_BITS ^&^ 0x00100000 ), 'unimport should clear bits in $^H when requested' 
re->unimport: 'eval'
ok:  !( $^HINT_BITS ^&^ 0x00200000 ), '... and again' 
my $reg=qr/(foo|bar|baz|blah)/
close $^STDERR
eval"use re Debug=>'ALL'"
my $ok='foo'=~m/$reg/
eval"no re Debug=>'ALL'"
ok:  $ok, 'No segv!' 

package Term::Cap

sub Tgetent
    bless: \$%, @_[0]


sub Tputs
    return @_[1]

