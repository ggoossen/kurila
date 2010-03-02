#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib/'
    else
        unshift: $^INCLUDE_PATH, 't/lib/'
    

chdir 't'

my $Is_VMS = $^OS_NAME eq 'VMS'

use File::Spec

use Test::More tests => 4

my @cd_args = @: "some/dir", "command1", "command2"

do
    package Test::MM_Win32
    use ExtUtils::MM_Win32
    our @ISA = qw(ExtUtils::MM_Win32)

    my $mm = bless: \$%, 'Test::MM_Win32'

    do
        local *make = sub (@< @_) { "nmake" }

        my @dirs = (@: File::Spec->updir) x 2 
        my $expected_updir = File::Spec->catdir: < @dirs

        main::is:  ($mm->cd: < @cd_args)
                   qq{cd some/dir
	command1
	command2
	cd $expected_updir}
    

    do
        local *make = sub (@< @_) { "dmake" }

        main::is:  ($mm->cd: < @cd_args)
                   q{cd some/dir && command1
	cd some/dir && command2}
    


do
    is: (ExtUtils::MM_Unix->cd: < @cd_args)
        q{cd some/dir && command1
	cd some/dir && command2}


:SKIP do
    skip: "VMS' cd requires vmspath which is only on VMS", 1 unless $Is_VMS

    use ExtUtils::MM_VMS;
    is: (ExtUtils::MM_VMS->cd: < @cd_args)
        q{startdir = F$Environment("Default")
	Set Default [.some.dir]
	command1
	command2
	Set Default 'startdir'}

