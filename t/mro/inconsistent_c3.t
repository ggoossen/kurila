#!./perl


use warnings

require q(./test.pl); plan: tests => 1

=pod

This example is take from: http://www.python.org/2.3/mro.html

"Serious order disagreement" # From Guido
class O: pass
class X(O): pass
class Y(O): pass
class A(X,Y): pass
class B(Y,X): pass
try:
    class Z(A,B): pass #creates Z(A,B) in Python 2.2
except TypeError:
    pass # Z(A,B) cannot be created in Python 2.3

=cut

do
    package X

    package Y

    package XY
    our @ISA = @: 'X', 'Y'

    package YX;
    our @ISA = @: 'Y', 'X'


try { @Z::ISA = (@: 'XY', 'YX') }
like: $^EVAL_ERROR->{?description}, qr/^Inconsistent /, '... got the right error with an inconsistent hierarchy'
