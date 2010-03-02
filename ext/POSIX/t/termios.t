#!perl

BEGIN 
    use Config
    use Test::More


use POSIX
BEGIN 
    plan: skip_all => "POSIX::Termios not implemented"
        if  !eval "POSIX::Termios->new;1"
      and $^EVAL_ERROR->{?description}=~m/not implemented/



my @getters = qw(getcflag getiflag getispeed getlflag getoflag getospeed)

plan: tests => 3 + 2 * (3 + (NCCS: ) + nelems @getters)

my $r

# create a new object
my $termios = try { POSIX::Termios->new }
is:  $^EVAL_ERROR, '', "calling POSIX::Termios->new" 
ok:  defined $termios, "\tchecking if the object is defined" 
isa_ok:  $termios, "POSIX::Termios", "\tchecking the type of the object" 

# testing getattr()

:SKIP do
    -t $^STDIN or skip: "STDIN not a tty", 2
    $r = try { ($termios->getattr: 0) }
    is:  $^EVAL_ERROR, '', "calling getattr(0)" 
    ok:  defined $r, "\tchecking if the returned value is defined: $r" 


:SKIP do
    -t $^STDOUT or skip: "STDOUT not a tty", 2
    $r = try { ($termios->getattr: 1) }
    is:  $^EVAL_ERROR, '', "calling getattr(1)" 
    ok:  defined $r, "\tchecking if the returned value is defined: $r" 


:SKIP do
    -t $^STDERR or skip: "STDERR not a tty", 2
    $r = try { ($termios->getattr: 2) }
    is:  $^EVAL_ERROR, '', "calling getattr(2)" 
    ok:  defined $r, "\tchecking if the returned value is defined: $r" 


# testing getcc()
for my $i (0..(NCCS: )-1)
    $r = try { ($termios->getcc: $i) }
    is:  $^EVAL_ERROR, '', "calling getcc($i)" 
    ok:  defined $r, "\tchecking if the returned value is defined: $r" 


# testing getcflag()
for my $method ( @getters)
    $r = try {( $termios->?$method: ) }
    is:  $^EVAL_ERROR, '', "calling $method()" 
    ok:  defined $r, "\tchecking if the returned value is defined: $r" 


