#!./perl

print "1..8\n";

{
  our $blurfl = 123;
  our $foo = 3;
}

package xyz;

sub new {bless \@();}

our $bar = 4;

{
    package ABC;
    our $blurfl = 5;
    $main::a = $::b;
}

$ABC::dyick = 6;

our $xyz = 2;

our $main = join(':', sort(keys %main::));
our $xyz = join(':', sort(keys %xyz::));
our $ABC = join(':', sort(keys %ABC::));

print $xyz eq 'ABC:bar:main:new:xyz' ? "ok 1\n" : "not ok 1 '$xyz'\n";
print $ABC eq 'blurfl:dyick' ? "ok 2\n" : "not ok 2 '$ABC'\n";
print $main::blurfl == 123 ? "ok 3\n" : "not ok 3\n";

{
  package ABC;
  
  our $blurfl;
  print $blurfl == 5 ? "ok 4\n" : "not ok 4\n";
  eval 'print $blurfl == 5 ? "ok 5\n" : "not ok 5\n";';
  eval 'package main; our $blurfl; print $blurfl == 123 ? "ok 6\n" : "not ok 6\n";';
  print $blurfl == 5 ? "ok 7\n" : "not ok 7\n";
}

package main;

sub c { @(caller(0)) }

sub foo {
   my $s = shift;
   if ($s) {
	package PQR;
	main::c();
   }
}

print(foo(1)[0] eq 'PQR' ? "ok 8\n" : "not ok 8\n");
