#!./perl

my $file

BEGIN 
    $file = $^PROGRAM_NAME
    chdir 't' if -d 't'

END 
    # let VMS whack all versions
    1 while unlink: 'tcout'

use Test::More

# these names are hardcoded in Term::Cap
my $files = join: '', grep: { -f $_ },
                                @:  $((env::var: 'HOME')) . '/.termcap' # we assume pretty UNIXy system anyway
                                    '/etc/termcap'
                                    '/usr/share/misc/termcap'
unless( $files || $^OS_NAME eq 'VMS' )
    plan: skip_all => 'no termcap available to test'
else
    plan: tests => 45


use_ok:  'Term::Cap' 

open: my $out_fh, ">>", \(my $out)
my $writable = 1

if ((open: my $tcout, ">", "tcout"))
    print: $tcout, ~< $^DATA
    close $tcout
else
    $writable = 0


# termcap_path -- the names are hardcoded in Term::Cap
(env::var: 'TERMCAP' ) = ''
my $path = join: '', (Term::Cap::termcap_path: )
is:  $path, $files, 'termcap_path() should find default files' 

:SKIP do
    # this is ugly, but -f $0 really *ought* to work
    skip: "-f $file fails, some tests difficult now", 2 unless -f $file

    (env::var: 'TERMCAP' ) = $file
    (env::var: 'TERMPATH' ) = $file
    ok:  (grep: $file, (Term::Cap::termcap_path: ))
         'termcap_path() should find file from $ENV{TERMCAP}' 

    (env::var: 'TERMCAP' ) = '/'
    ok:  (grep: $file, (Term::Cap::termcap_path: ))
         'termcap_path() should find file from $ENV{TERMPATH}' 


# make a Term::Cap "object"
my $t = \%:
    PADDING => 1
    _pc => 'pc'
    
bless: $t, 'Term::Cap' 

# see if Tpad() works
is:  ($t->Tpad: ), undef, 'Tpad() should return undef with no arguments' 
is:  ($t->Tpad: 'x'), 'x', 'Tpad() should return strings verbatim with no match' 
is:  ($t->Tpad:  '1*a', 2 ), 'apcpc', 'Tpad() should pad paddable strings' 

$t->{+PADDING} = 2
is:  ($t->Tpad:  '1*a', 3, $out_fh ), 'apcpc', 'Tpad() should perform pad math' 
is:  ($out->read: ), 'apcpc', 'Tpad() should write to filehandle when passed' 

is:  ($t->Tputs: 'PADDING'), 2, 'Tputs() should return existing value' 
is:  ($t->Tputs: 'pc', 2), 'pc', 'Tputs() should delegate to Tpad()' 
$t->Tputs: 'pc', 1, $out_fh
is:  $t->{?pc}, 'pc', 'Tputs() should cache pc value when asked' 
is:  ($out->read: ), 'pc', 'Tputs() should write to filehandle when passed' 

try { ($t->Trequire:  'pc' ) }
is:  $^EVAL_ERROR, '', 'Trequire() should finds existing cap' 
try { ($t->Trequire:  'nonsense' ) }
like:  $^EVAL_ERROR->{?description}, qr/support: \(nonsense\)/
       'Trequire() should croak with unsupported cap' 

my $warn
local $^WARN_HOOK = sub (@< @_)
    $warn = @_[0]


# test the first few features by forcing Tgetent() to croak (line 156)
(env::var: 'TERM') = undef
my $vals = \$%
try { local $^WARNING = 1; $t = (Term::Cap->Tgetent: $vals) }
like:  $^EVAL_ERROR->{?description}, qr/TERM not set/, 'Tgetent() should croaks without TERM' 
like:  $warn, qr/OSPEED was not set/, 'Tgetent() should set default OSPEED' 

is:  $vals->{?PADDING}, 10000/9600, 'Default OSPEED implies default PADDING' 

$warn = 'xxxx'
try { local $^WARNING = 0; $t = (Term::Cap->Tgetent: $vals) }
is: $warn,'xxxx',"Tgetent() doesn't carp() without warnings on"

# check values for very slow speeds
$vals->{+OSPEED} = 1
$warn = ''
try { $t = (Term::Cap->Tgetent: $vals) }
is:  $warn, '', 'Tgetent() should not work if OSPEED is provided' 
is:  $vals->{?PADDING}, 200, 'Tgetent() should set slow PADDING when needed' 


:SKIP do
    skip: 'Tgetent() bad termcap test, since using a fixed termcap',1
        if $^OS_NAME eq 'VMS'
    # now see if lines 177 or 180 will fail
    (env::var: 'TERM' ) = 'foo'
    (env::var: 'TERMPATH' ) = '!'
    (env::var: 'TERMCAP' ) = ''
    try { $t = (Term::Cap->Tgetent: $vals) }
    isnt:  $^EVAL_ERROR, '', 'Tgetent() should catch bad termcap file' 


:SKIP do
    skip:  "Can't write 'tcout' file for tests", 9  unless $writable

    # it won't find the termtype in this fake file, so it should croak
    $vals->{+TERM} = 'quux'
    (env::var: 'TERMPATH' ) = 'tcout'
    try { $t = (Term::Cap->Tgetent: $vals) }
    like:  $^EVAL_ERROR->{?description}, qr/failed termcap/, 'Tgetent() should die with bad termcap' 

    # it shouldn't try to read one file more than 32(!) times
    # see __END__ for a really awful termcap example
    (env::var: 'TERMPATH' ) = join: ' ', (@:  ('tcout') x 33)
    $vals->{+TERM} = 'bar'
    try { $t = (Term::Cap->Tgetent: $vals) }
    like:  $^EVAL_ERROR->{?description}, qr/failed termcap loop/, 'Tgetent() should catch deep recursion'

    # now let it read a fake termcap file, and see if it sets properties
    (env::var: 'TERMPATH' ) = 'tcout'
    $vals->{+TERM} = 'baz'
    $t = Term::Cap->Tgetent: $vals
    is:  $t->{?_f1}, 1, 'Tgetent() should set a single field correctly' 
    is:  $t->{?_f2}, 1, 'Tgetent() should set another field on the same line' 
    is:  $t->{?_no}, '', 'Tgetent() should set a blank field correctly' 
    is:  $t->{?_k1}, 'v1', 'Tgetent() should set a key value pair correctly' 
    like:  $t->{?_k2}, qr/v2\\\n2/, 'Tgetent() should set and translate pairs' 

    # and it should have set these two fields
    is:  $t->{?_pc}, "\0", 'should set _pc field correctly' 
    is:  $t->{?_bc}, "\b", 'should set _bc field correctly' 


# Windows hack
:SKIP
    do
    skip: "QNX's termcap database does not contain an entry for dumb terminals"
          1 if $^OS_NAME eq 'nto'

    local $^OS_NAME = undef
    push: dynascope->{onleave}, (env::make_restore: )
    (env::var: 'TERM') = undef
    $^OS_NAME = 'Win32'

    my $foo = Term::Cap->Tgetent: 
    is: $foo->{?TERM} ,'dumb','Windows gets "dumb" by default'


# Tgoto has comments on the expected formats
$t->{+_test} = "a\%d"
is:  ($t->Tgoto: 'test', '', 1, $out_fh), 'a1', 'Tgoto() should handle %d code' 
is:  ($out->read: ), 'a1', 'Tgoto() should print to filehandle if passed' 

$t->{+_test} = "a\%."
like:  ($t->Tgoto: 'test', '', 1), qr/^a\x01/, 'Tgoto() should handle %.' 
if ((ord: 'A') == 193)  # EBCDIC platform
    like:  ($t->Tgoto: 'test', '', 0), qr/\x81\x01\x16/
           'Tgoto() should handle %. and magic' 
else # ASCII platform
    like:  ($t->Tgoto: 'test', '', 0), qr/\x61\x01\x08/
           'Tgoto() should handle %. and magic' 


$t->{+_test} = 'a%+'
like:  ($t->Tgoto: 'test', '', 1), qr/a\x01/, 'Tgoto() should handle %+' 
$t->{+_test} = 'a%+a'
is:  ($t->Tgoto: 'test', '', 1), 'ab', 'Tgoto() should handle %+char' 
$t->{+_test} .= 'a' x 99
like:  ($t->Tgoto: 'test', '', 1), qr/ba{98}/
       'Tgoto() should substr()s %+ if needed' 

$t->{+_test} = '%ra%d'
is:  ($t->Tgoto: 'test', 1, ''), 'a1', 'Tgoto() should swaps params with %r' 

$t->{+_test} = 'a%>11bc'
is:  ($t->Tgoto: 'test', '', 1), 'abc', 'Tgoto() should unpack args with %>' 

$t->{+_test} = 'a%21'
is:  ($t->Tgoto: 'test'), 'a001', 'Tgoto() should format with %2' 

$t->{+_test} = 'a%31'
is:  ($t->Tgoto: 'test'), 'a0001', 'Tgoto() should also formats with %3' 

$t->{+_test} = '%ia%21'
is:  ($t->Tgoto: 'test', '', 1), 'a021', 'Tgoto() should increment args with %i' 

$t->{+_test} = '%z'
is:  ($t->Tgoto: 'test'), 'OOPS', 'Tgoto() should catch invalid args' 

# and this is pretty standard
package TieOut

sub TIEHANDLE
    bless:  \(my $self), @_[0] 


sub PRINT
    my $self = shift
    $self->$ .= join: '', @_


sub read
    my $self = shift
    substr:  $self->$, 0, (length: $self->$), '' 


__END__
bar: :tc=bar: \
baz: \
:f1: :f2: \
:no@ \
:k1#v1\
:k2=v2\\n2
