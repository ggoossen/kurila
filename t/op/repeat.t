#!./perl

BEGIN { require './test.pl' };
plan: tests => 31

# compile time

is: '-' x 5, '-----',    'compile time x'
is: '-' x 3.1, '---',    'compile time 3.1'
is: '-' x 3.9, '---',    'compile time 3.9'
is: '-' x 1, '-',        '  x 1'
is: '-' x 0, '',         '  x 0'
is: '-' x -1, '',        '  x -1'
is: '-' x undef, '',     '  x undef'
is: '-' x "foo", '',     '  x "foo"'
is: '-' x "3rd", '---',  '  x "3rd"'

is: 'ab' x 3, 'ababab',  '  more than one char'

# run time

$a = '-'
is: $a x 5, '-----',     'run time x'
is: $a x 3.1, '---',     '  x 3.1'
is: $a x 3.9, '---',     '  x 3.9'
is: $a x 1, '-',         '  x 1'
is: $a x 0, '',          '  x 0'
is: $a x -3, '',         '  x -3'
is: $a x undef, '',      '  x undef'
is: $a x "foo", '',      '  x "foo"'
is: $a x "3rd", '---',   '  x "3rd"'

$a = 'ab'
is: $a x 3, 'ababab',    '  more than one char'
$a = 'ab'
is: $a x 0, '',          '  more than one char'
$a = 'ab'
is: $a x -12, '',        '  more than one char'

$a = 'xyz'
$a x= 2
is: $a, 'xyzxyz',        'x=2'
$a x= 1
is: $a, 'xyzxyz',        'x=1'
$a x= 0
is: $a, '',              'x=0'

my @x = @: 1,2,3

is: (join: '', (@x x 4)),      '123123123123',         '(@x) x Y'
is: (join: '', (@x x -14)),    '',                     '(@x) x -14'


eval_dies_like: q[ (1, 2) x 3 ], qr/list may not be used in scalar context/

is: "\x[dd]" x 24, "\x[dddddddddddddddddddddddddddddddddddddddddddddddd]", 'Dec C bug'

# perlbug 20011113.110 works in 5.6.1, broken in 5.7.2
do
    my $x= \@: ("foo") x 2
    is:  (join: '', $x->@), 'foofoo', 'list repeat in anon array ref broken [ID 20011113.110]' 


# [ID 20010809.028] x operator not copying elements in 'for' list?
do
    local our $TODO = "x operator not copying elements in 'for' list? [ID 20010809.028]"
    my $x = 'abcd'
    my $y = ''
    for ((@: $x =~ m/./g) x 2)
        $y .= chop
    
    is: $y, 'abcdabcd'

