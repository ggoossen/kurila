### Module::Load::Conditional test suite ###

BEGIN { use FindBin; }

use File::Spec ()
use Test::More 'no_plan'

use constant ON_VMS     => $^OS_NAME eq 'VMS'

use lib "$FindBin::Bin/../lib"
use lib "$FindBin::Bin/to_load"

use_ok:  'Module::Load::Conditional' 

### stupid stupid warnings ###
do {   $Module::Load::Conditional::VERBOSE =
        $Module::Load::Conditional::VERBOSE = 0;

    *can_load       = \&Module::Load::Conditional::can_load;
    *check_install  = \&Module::Load::Conditional::check_install;
    *requires       = \&Module::Load::Conditional::requires;
}

do
    my $rv = check_install: 
        module  => 'Module::Load::Conditional'
        version => $Module::Load::Conditional::VERSION
        

    ok:  $rv{?uptodate},    q[Verify self] 
    is:  ($rv{version}->stringify: ), $Module::Load::Conditional::VERSION
         q[  Found proper version] 

    ### break up the specification
    my @rv_path = do

        ### Use the UNIX specific method, as the VMS one currently
        ### converts the file spec back to VMS format.
        my $class = (ON_VMS: )?? 'File::Spec::Unix' !! 'File::Spec'

        my(@: $vol, $path, $file) =  $class->splitpath:  $rv{'file'} 

        my @path = @: $vol, < ($class->splitdir:  $path ), $file 

        ### First element could be blank for some system types like VMS
        shift @path if $vol eq ''

        ### and return it
        @path
    

    is:  $^INCLUDED{?'Module/Load/Conditional.pm'}
         (File::Spec::Unix->catfile: < @rv_path)
         q[  Found proper file]
        



### the version may contain an _, which means perl will warn about 'not
### numeric' -- turn off that warning here.
do {   local $^WARNING = undef;
    my $rv =( check_install: 
        module  => 'Module::Load::Conditional'
        version => $Module::Load::Conditional::VERSION + 1
        );

    ok:  !$rv{?uptodate} && $rv{?version} && $rv{?file}
         q[Verify out of date module]
        ;
}

do
    my $rv = check_install:  module  => 'Module::Load::Conditional' 

    ok:  $rv{?uptodate} && $rv{?version} && $rv{?file}
         q[Verify any module]
        


do
    my $rv = check_install:  module  => 'Module::Does::Not::Exist' 

    ok:  !$rv{?uptodate} && !$rv{?version} && !$rv{?file}
         q[Verify non-existant module]
        



### test finding a version of a module that mentions $VERSION in pod
do {   my $rv =( check_install:  module => 'InPod' );
    ok:  $rv,                        'Testing $VERSION in POD' ;
    ok:  $rv{?version},             "   Version found" ;
    is:  ($rv{version}->stringify: ), 2,          "   Version is correct" ;
}

### test beta/developer release versions
do {   my $test_ver = $Module::Load::Conditional::VERSION;

    ### strip beta tags
    $test_ver =~ s/_\d+//g;
    $test_ver .= '_99';

    my $rv =( check_install: 
        module  => 'Module::Load::Conditional'
        version => $test_ver
        );

    ok:  $rv,                "Checking beta versions" ;
    ok:  !$rv{?'uptodate'}, "   Beta version is higher" ;

}

### test $FIND_VERSION
do {   local $Module::Load::Conditional::FIND_VERSION = 0;
    local $Module::Load::Conditional::FIND_VERSION = 0;

    my $rv =( check_install:  module  => 'Module::Load::Conditional' );

    ok:  $rv,                        'Testing $FIND_VERSION' ;
    is:  $rv{?version}, undef,      "   No version info returned" ;
    ok:  $rv{?uptodate},            "   Module marked as uptodate" ;
}

### test 'can_load' ###

do
    my $use_list = \%:  'LoadIt' => 1 
    my $bool = can_load:  modules => $use_list 

    ok:  $bool, q[Load simple module] 


do
    my $use_list = \%:  'Commented' => 2 
    my $bool = can_load:  modules => $use_list 

    ok:  $bool, q[Load module with a second, commented-out $VERSION] 


do
    my $use_list = \%:  'MustBe::Loaded' => 1 
    my $bool = can_load:  modules => $use_list 

    ok:  !$bool, q[Detect out of date module] 


do
    delete $^INCLUDED{'LoadIt.pm'}
    delete $^INCLUDED{'MustBe/Loaded.pm'}

    my $use_list = \%:  'LoadIt' => 1, 'MustBe::Loaded' => 1 
    my $bool = can_load:  modules => $use_list 

    ok:  !$^INCLUDED{?'LoadIt.pm'} && !$^INCLUDED{?'MustBe/Loaded.pm'}
         q[Do not load if one prerequisite fails]
        



### test 'requires' ###
:SKIP do
    skip: "Depends on \$^X, which doesn't work well when testing the Perl core"
          1 if env::var: 'PERL_CORE'

    my %list = %:  < @+: map: { @: $_ => 1 }, requires: 'Carp' 

    my $flag
    $flag++ unless delete %list{'Exporter'}

    ok:  !$flag, q[Detecting requirements] 


### test using the %INC lookup for check_install
do {   local $Module::Load::Conditional::CHECK_INC_HASH = 1;
    local $Module::Load::Conditional::CHECK_INC_HASH = 1;

    do {   package A::B::C::D;
        $A::B::C::D::VERSION = $^PID;
        $^INCLUDED{+'A/B/C/D.pm'}   = $^PID.$^PID;

    ### XXX this is no longer needed with M::Load 0.11_01
    #$INC{'[.A.B.C]D.pm'} = $$.$$ if $^O eq 'VMS';
    };

    my $href =( check_install:  module => 'A::B::C::D', version => 0 );

    ok:  $href,                  'Found package in %INC' ;
    is:  $href{?'file'}, $^PID.$^PID, '   Found correct file' ;
    is:  $href{?'version'}, $^PID, '   Found correct version' ;
    ok:  $href{?'uptodate'},    '   Marked as uptodate' ;
    ok: ( can_load:  modules => \(%:  'A::B::C::D' => 0 ) )
        '   can_load successful' ;
}

