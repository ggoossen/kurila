#!/usr/bin/perl -w


use Test::More tests => 5


BEGIN 
    use_ok:  'ExtUtils::Liblist' 


do
    my @warn
    local $^WARN_HOOK = sub (@< @_) {(push: @warn, \(@: @_[0]->{?description}))}

    my $ll = bless: \$%, 'ExtUtils::Liblist'
    my @out = $ll->ext: '-ln0tt43r3_perl'
    is:  (nelems @out), 4, 'enough output' 
    unlike:  @out[2], qr/-ln0tt43r3_perl/, 'bogus library not added' 
    ok:  (nelems @warn), 'had warning'

    (is:  (nelems: (grep:  {m/\QNote (probably harmless): No library found for \E(-l)?n0tt43r3_perl/ }, @+: (map: { $_->@ }, @warn))), 1 ) || diag: join: "\n", < @warn

