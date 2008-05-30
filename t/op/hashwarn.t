#!./perl

require './test.pl';
plan( tests => 12 );

use strict;
use warnings;

use vars qw{ @warnings };

BEGIN {
    $^WARN_HOOK = sub { push @warnings, @_[0]->message };
    $| = 1;
}

my $fail_odd      = 'Odd number of elements in hash assignment at ';
my $fail_odd_anon = 'Odd number of elements in anonymous hash at ';
my $fail_ref      = 'Reference found where even-sized list expected at ';
my $fail_not_hr   = 'Not a HASH reference at ';

{
    @warnings = ();
    my %hash = (1..3);
    cmp_ok(scalar(@warnings),'==',1,'odd count');
    cmp_ok(substr(@warnings[0],0,length($fail_odd)),'eq',$fail_odd,'odd msg');

    @warnings = ();
    %hash = 1;
    cmp_ok(scalar(@warnings),'==',1,'scalar count');
    cmp_ok(substr(@warnings[0],0,length($fail_odd)),'eq',$fail_odd,'scalar msg');

    @warnings = ();
    dies_like( sub { %hash = \%( 1..3 ); }, qr/reference as string/ );

    @warnings = ();
    dies_like( sub { %hash = \@( 1..3 ); }, qr/reference as string/ );

    @warnings = ();
    dies_like( sub { %hash = sub { print "fenice" }; }, qr/reference as string/ );

    @warnings = ();
    $_ = \%( 1..10 );
    cmp_ok(scalar(@warnings),'==',0,'hashref assign');

    # Old pseudo-hash syntax, now removed.

    @warnings = ();
    my $avhv = \@(\%(x=>1,y=>2));
    try {
        %$avhv = (x=>13,'y');
    };
    cmp_ok(scalar(@warnings),'==',0,'pseudo-hash 1 count');
    cmp_ok(substr($@->message,0,length($fail_not_hr)),'eq',$fail_not_hr,'pseudo-hash 1 msg');

    @warnings = ();
    try {
        %$avhv = 'x';
    };
    cmp_ok(scalar(@warnings),'==',0,'pseudo-hash 2 count');
    cmp_ok(substr($@->message,0,length($fail_not_hr)),'eq',$fail_not_hr,'pseudo-hash 2 msg');
}
