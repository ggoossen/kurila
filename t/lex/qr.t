#!./perl

print: $^STDOUT, "1..7\n"

# This is() function is written to avoid ""
my $test = 1
sub is($left, $right, ?$msg)

    if ($left eq $right)
        printf: $^STDOUT, 'ok %d
', $test++
        return 1
    
    printf: $^STDOUT, q(not ok %d - got %s expected %s
), $test++, $left, $right

    printf: $^STDOUT, q(# Failed test at line %d
), (caller)[[2]]

    return 0


is:  qr/foo/, '(?-uxism:foo)', 'basic regexp' 
is:  qr*foo*, '(?-uxism:foo)', 'basic regexp with * delimeter' 
is:  qr'foo', '(?-uxism:foo)', 'basic regexp with single quote delimeter' 

# backslashes:
is:  qr/\/foo/, '(?-uxism:\/foo)', 'slash' 
is:  qr'\/foo', '(?-uxism:\/foo)', 'slash with single quote' 

my $x = "bla"
is:  qr/$x/, '(?-uxism:bla)', 'with variable interpolation' 
is:  qr'$x', '(?-uxism:bla)', 'vairable interpolation with single quotes' 
