#!./perl

BEGIN {
    require "test.pl";
}

plan(3);

fresh_perl_is('$_ = qq{OK\n}; print;', "OK\n",
              'print without arguments outputs $_');
fresh_perl_is('$_ = qq{OK\n}; print STDOUT;', "OK\n",
              'print with only a filehandle outputs $_');

fresh_perl_is('print(qq{OK}||1)', "OK",
              'constant folded bareword is not interpreted as a filehandle');
