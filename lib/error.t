#!./perl

BEGIN { require './test.pl'; }

plan( tests => 141 );


my $err = error->new("my message");
ok $err, "error object created";
is $err->{message}, "my message";

sub new_error { return error->new("my message"); }
sub new_error2 { return new_error(); }
$err = new_error2();
is( (scalar @{$err->{stack}}), 2);
is((join '**', @{$err->{stack}[0]}), "main**sv/error.t**13**main::new_error**");
is((join '**', @{$err->{stack}[1]}), "main**sv/error.t**14**main::new_error2**");
# warn join '**', @{$err->{stack}};
