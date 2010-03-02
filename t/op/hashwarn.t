#!./perl

require './test.pl'
plan:  tests => 8 

use warnings

our (@warnings)

BEGIN 
    $^WARN_HOOK = sub (@< @_) { (push: @warnings, @_[0]->message) }
    $^OUTPUT_AUTOFLUSH = 1


my $fail_odd      = 'Odd number of elements in hash assignment'
my $fail_odd_anon = 'Odd number of elements in anonymous hash'
my $fail_ref      = 'Reference found where even-sized list expected'
my $fail_not_hr   = 'Not a HASH reference'

do
    @warnings = $@
    my (@: %<%hash) =  1..3
    cmp_ok: (nelems: @warnings),'==',1,'odd count'
    cmp_ok: (substr: @warnings[0],0,(length: $fail_odd)),'eq',$fail_odd,'odd msg'

    @warnings = $@
    (@: %<%hash) = @: 1
    cmp_ok: (scalar: nelems @warnings),'==',1,'scalar count'
    cmp_ok: (substr: @warnings[0],0,(length: $fail_odd)),'eq',$fail_odd,'scalar msg'

    @warnings = $@
    dies_like:  sub (@< @_) { %hash = (%:  \(%:  < 1..3 ) ); }, qr/reference as string/ 

    @warnings = $@
    dies_like:  sub (@< @_) { %hash = (%:  \( 1..3 ) ); }, qr/reference as string/ 

    @warnings = $@
    dies_like:  sub (@< @_) { %hash = (%:  sub (@< @_) { (print: $^STDOUT, "fenice") } ); }
                qr/CODE can not be used as a string/ 

    @warnings = $@
    $_ = \%:  < 1..10 
    cmp_ok: (scalar: nelems @warnings),'==',0,'hashref assign'

