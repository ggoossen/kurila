#!/usr/bin/perl -w

use Test::More tests => 15

use ExtUtils::Packlist

is:  (ref: (ExtUtils::Packlist::mkfh: )), 'GLOB', 'mkfh() should return a FH' 

# new calls tie()
my $pl = ExtUtils::Packlist->new: 
isa_ok:  $pl, 'ExtUtils::Packlist' 

:SKIP do

    # and some test data to be read
    $pl->{+data} = %:
        single => 1
        hash => \ %:
            foo => 'bar'
            baz => 'bup'
        '/./abc' => ''

    ExtUtils::Packlist::write: $pl, 'eplist'
    is:  $pl->{packfile}, 'eplist', 'write() should set packfile name' 



#'open packfile for reading


# and more read() tests
:SKIP do
    open: my $in, "<", "eplist" or die: 
    my $file = do { local $^INPUT_RECORD_SEPARATOR = undef; ~< $in }
    close $in

    like:  $file, qr/single\n/, 'key with value should be available' 
    like:  $file, qr!/\./abc\n!, 'key with no value should also be present' 
    like:  $file, qr/hash.+baz=bup/, 'key with hash value should be present' 
    like:  $file, qr/hash.+foo=bar/, 'second embedded hash value should appear'

    ExtUtils::Packlist::read: $pl, 'eplist'
    is:  $pl->{data}{?single}, undef, 'single keys should have undef value' 
    is:  (ref: $pl->{data}{?hash}), 'HASH', 'multivalue keys should become hashes'

    is:  $pl->{data}{hash}->{?foo}, 'bar', 'hash values should be set' 
    ok:  exists $pl->{data}{'/abc'}, 'read() should resolve /./ to / in keys' 

    # give validate a valid and an invalid file to find
    $pl->{+data} = %:
        eplist => 1
        fake => undef
        

    is:  (nelems: @: (ExtUtils::Packlist::validate: $pl)), 1
         'validate() should find missing files' 
    ExtUtils::Packlist::validate: $pl, 1
    ok:  !exists $pl->{data}{fake}
         'validate() should remove missing files when prompted' 

    # one more new() test, to see if it calls read() successfully
    $pl = ExtUtils::Packlist->new: 'eplist'



# packlist_file, $pl should be set from write test
is:  (ExtUtils::Packlist::packlist_file: \(%:  packfile => 'pl' ))[0], 'pl'
     'packlist_file() should fetch packlist from passed hash' 
is:  (ExtUtils::Packlist::packlist_file: $pl)[0], 'eplist'
     'packlist_file() should fetch packlist from ExtUtils::Packlist object' 

END 
    1 while unlink: < qw( eplist )

