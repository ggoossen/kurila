#!./perl -w


BEGIN 
    if ( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


package Term::ReadLine::Mock
our @ISA = @:  'Term::ReadLine::Stub' 
sub ReadLine {'Term::ReadLine::Mock'};
sub readline { "a line" }
sub new      { (bless: \$%) }

package main

use Test::More tests => 14

BEGIN 
    (env::var: 'PERL_RL' ) = 'Mock' # test against our instrumented class

use Term::ReadLine

my $t = Term::ReadLine->new:  'test term::readline'

ok: $t, "made something"

isa_ok: $t,          'Term::ReadLine::Mock'

for my $method (qw( ReadLine readline addhistory IN OUT MinLine
                    findConsole Attribs Features new ) )
    can_ok: $t, $method


is: $t->ReadLine,    'Term::ReadLine::Mock', "\$object->ReadLine"
is: $t->readline,    'a line',               "\$object->readline"

