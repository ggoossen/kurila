#!./perl

BEGIN 
    require './test.pl'


plan: tests => 2

my @expect = qw(
b1
b2
b3
b4
b6
u5
b7
u6
u1
c3
c2
c1
i1
i2
b5
u2
u3
u4
e2
e1
		)
my $expect = ":" . join: ":", @expect

fresh_perl_is: <<'SCRIPT', $expect,\(%: switches => \(@: ''), stdin => '', stderr => 1 ),'Order of execution of special blocks'
BEGIN {print $^STDOUT, ":b1"}
END {print $^STDOUT, ":e1"}
BEGIN {print $^STDOUT, ":b2"}
do {
    BEGIN {BEGIN {print $^STDOUT, ":b3"}; print $^STDOUT, ":b4"}
};
CHECK {print $^STDOUT, ":c1"}
INIT {print $^STDOUT, ":i1"}
UNITCHECK {print $^STDOUT, ":u1"}
eval 'BEGIN {print $^STDOUT, ":b5"}';
eval 'UNITCHECK {print $^STDOUT, ":u2"}';
eval 'UNITCHECK {print $^STDOUT, ":u3"; UNITCHECK {print $^STDOUT, ":u4"}}';
"a" =~ m/(?{UNITCHECK {print $^STDOUT, ":u5"};
           CHECK {print $^STDOUT, ":c2"};
           BEGIN {print $^STDOUT, ":b6"}})/x;
try {BEGIN {print $^STDOUT, ":b7"}};
try {UNITCHECK {print $^STDOUT, ":u6"}};
try {INIT {print $^STDOUT, ":i2"}};
try {CHECK {print $^STDOUT, ":c3"}};
END {print $^STDOUT, ":e2"}
SCRIPT

@expect =@:  <
                 # BEGIN
                 qw( main bar myfoo foo ), <
                 # UNITCHECK
                 qw( foo myfoo bar main ), <
                 # CHECK
                 qw( foo myfoo bar main ), <
                 # INIT
                 qw( main bar myfoo foo ), <
                 # END
                 qw(foo myfoo bar main  )

$expect = ":" . join: ":", @expect
fresh_perl_is: <<'SCRIPT2', $expect,\(%: switches => \(@: ''), stdin => '', stderr => 1 ),'blocks interact with packages/scopes'
our $f;
BEGIN {$f = 'main'; print $^STDOUT, ":$f"}
UNITCHECK {print $^STDOUT, ":$f"}
CHECK {print $^STDOUT, ":$f"}
INIT {print $^STDOUT, ":$f"}
END {print $^STDOUT, ":$f"}
package bar;
our $f;
BEGIN {$f = 'bar';print $^STDOUT, ":$f"}
UNITCHECK {print $^STDOUT, ":$f"}
CHECK {print $^STDOUT, ":$f"}
INIT {print $^STDOUT, ":$f"}
END {print $^STDOUT, ":$f"}
package foo;
our $f;
do {
    my $f;
    BEGIN {$f = 'myfoo'; print $^STDOUT, ":$f"}
    UNITCHECK {print $^STDOUT, ":$f"}
    CHECK {print $^STDOUT, ":$f"}
    INIT {print $^STDOUT, ":$f"}
    END {print $^STDOUT, ":$f"}
};
BEGIN {$f = "foo";print $^STDOUT, ":$f"}
UNITCHECK {print $^STDOUT, ":$f"}
CHECK {print $^STDOUT, ":$f"}
INIT {print $^STDOUT, ":$f"}
END {print $^STDOUT, ":$f"}
SCRIPT2
