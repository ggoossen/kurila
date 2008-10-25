#!perl -w
package version;


use vars < qw(@ISA $VERSION $CLASS *qv);

$VERSION = 0.73;

$CLASS = 'version';

# Preloaded methods go here.
sub import {
    my ($class) = < @_;
    my $callpkg = caller();
    
    *{Symbol::fetch_glob($callpkg."::qv")} = 
	    sub {return bless version::qv(shift), $class }
	unless defined (&{Symbol::fetch_glob("$callpkg\::qv")});

}

1;
