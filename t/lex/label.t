#!./perl

require "test.pl"

plan: 1

fresh_perl_is: <<'EOC', "continued", \$%, "label after constsub correctly parsed"
sub constsub()
    5

constsub

:MYLABEL do
    do
        last MYLABEL
    die: "not reached\n"

print: $^STDOUT, "continued"
EOC
