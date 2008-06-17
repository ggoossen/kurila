#!./perl

use strict;
use Config;

use Test::More tests => 15;

use_ok( 'sigtrap' );

package main;
local %SIG;

# use a version of sigtrap.pm somewhat too high
try{ sigtrap->import(99999) };
like( $@->{description}, qr/version 99999 required,/, 'import excessive version number' );

# use an invalid signal name
try{ sigtrap->import('abadsignal') };
like( $@->{description}, qr/^Unrecognized argument abadsignal/, 'send bad signame to import' );

try{ sigtrap->import('handler') };
like( $@->{description}, qr/^No argument specified/, 'send handler without subref' );

sigtrap->import('AFAKE');
cmp_ok( %SIG{AFAKE}, '\==', \&sigtrap::handler_traceback, 'install normal handler' );

sigtrap->import('die', 'AFAKE', 'stack-trace', 'FAKE2');
cmp_ok( %SIG{AFAKE}, '\==', \&sigtrap::handler_die, 'install the die handler' );
cmp_ok( %SIG{FAKE2}, '\==',\&sigtrap::handler_traceback, 'install traceback handler' );

my @normal = @(qw( HUP INT PIPE TERM ));
%SIG{[<@normal]} = '' x (nelems @normal);
sigtrap->import('normal-signals');
is( nelems @(grep { ref $_ } %SIG{[<@normal]}), nelems(@normal), 'check normal-signals set' );

my @error = @(qw( ABRT BUS EMT FPE ILL QUIT SEGV SYS TRAP ));
%SIG{[<@error]} = '' x (nelems @error);
sigtrap->import('error-signals');
is( (grep { ref $_ } %SIG{[<@error]}), @error, 'check error-signals set' );

my @old = @(qw( ABRT BUS EMT FPE ILL PIPE QUIT SEGV SYS TERM TRAP ));
%SIG{[<@old]} = '' x @old;
sigtrap->import('old-interface-signals');
is( (grep { ref $_ } %SIG{[<@old]}), @old, 'check old-interface-signals set' );

my $handler = sub {};
sigtrap->import(handler => $handler, 'FAKE3');
cmp_ok( %SIG{FAKE3}, '\==', $handler, 'install custom handler' );

%SIG{FAKE} = 'IGNORE';
sigtrap->import('untrapped', 'FAKE');
is( %SIG{FAKE}, 'IGNORE', 'respect existing handler set to IGNORE' );

my $out = tie *STDOUT, 'TieOut';
%SIG{FAKE} = 'DEFAULT';
$sigtrap::Verbose = 1;
sigtrap->import('any', 'FAKE');
cmp_ok( %SIG{FAKE}, '\==', \&sigtrap::handler_traceback, 'should set default handler' );
like( $out->read, qr/^Installing handler/, 'does it talk with $Verbose set?' );

# handler_die croaks with first argument
try { sigtrap::handler_die('FAKE') };
like( $@->{description}, qr/^Caught a SIGFAKE/, 'does handler_die() croak?' );
 
package TieOut;

sub TIEHANDLE {
	bless(\(my $scalar), @_[0]);
}

sub PRINT {
	my $self = shift;
	$$self .= join '', @_;
}

sub WRITE {
	my ($self, $msg, $length) = @_;
	$$self .= $msg;
}

sub read {
	my $self = shift;
	substr($$self, 0, length($$self), '');
}
