#!/usr/bin/perl -w

use File::Path
use File::Spec
require "test.pl"
(plan: tests => 17)

do 
    require XSLoader

    my @load
    local $^WARNING = 0
    local *XSLoader::load = sub (@< @args)
        push: @load, \@args

        # use_ok() calls import, which we do not want to do
    (require_ok:  'IO' )
    (ok:  < @load, 'IO should call XSLoader::load()' )
    (is:  @load[0]->[0], 'IO', '... loading the IO library' )
    (is:  @load[0]->[1], $IO::VERSION, '... with the current .pm version' )


my @default = map: { "IO/$_.pm" }, qw( Handle Seekable File Socket Dir )
delete $^INCLUDED{[@default ]}

my $warn = '' 
local $^WARN_HOOK = sub { $warn = @_[0]->{?description} } 

do 
    no warnings 
    (IO->import: )
    (is:  $warn, '', "... import default, should not warn")
    $warn = '' 


do 
    local $^WARNING = 0
    (IO->import: )
    (is:  $warn, '', "... import default, should not warn")
    $warn = '' 


do 
    local $^WARNING = 1
    (IO->import: )
    (like:  $warn, qr/^Parameterless "use IO" deprecated/
            "... import default, should warn")
    $warn = '' 


do 
    use warnings 'deprecated' 
    (IO->import: )
    (like:  $warn, qr/^Parameterless "use IO" deprecated/
            "... import default, should warn")
    $warn = '' 


do 
    use warnings 
    (IO->import: )
    (like:  $warn, qr/^Parameterless "use IO" deprecated/
            "... import default, should warn")
    $warn = '' 


foreach my $default ( @default)
    ok:  exists $^INCLUDED{ $default }, "... import should default load $default" 

try { (IO->import:  'nothere' ) }
(like:  $^EVAL_ERROR->{?description}, qr/Can.t locate IO.nothere\.pm/, '... croaking on any error' )

my $fakedir = (File::Spec->catdir:  'lib', 'IO' )
my $fakemod = (File::Spec->catfile:  $fakedir, 'fakemod.pm' )

my $flag
if ( -d $fakedir or mkpath:  $fakedir )
    my $outfh;
    if ((open:  $outfh, ">", "$fakemod"))
        (my $package = <<'                END_HERE') =~ s/\t//g;
                package IO::fakemod;

                sub import { die: "Do not import!\n" }

                sub exists { 1 }

                1;
                END_HERE

        (print: $outfh, $package);

    if (close $outfh)
        $flag = 1;
        push: $^INCLUDE_PATH, 'lib';

:SKIP do 
    skip: "Could not write to disk", 2  unless $flag
    try { (IO->import:  'fakemod' ) }
    (ok:  (IO::fakemod::exists: ), 'import() should import IO:: modules by name' )
    (is:  $^EVAL_ERROR, '', '... and should not call import() on imported modules' )


END
    1 while unlink: $fakemod
    rmdir $fakedir
