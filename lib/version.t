#! /usr/local/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use Test::More < qw(no_plan)
use POSIX

diag: "Tests with base class" unless env::var: 'PERL_CORE'

BEGIN 
    use_ok: "version", v0.50 # If we made it this far, we are ok.


our $Verbose

BaseTests: "version"

diag: "Tests with empty derived class" unless env::var: 'PERL_CORE'

BEGIN
    package version::Empty
    use base 'version'
    our $VERSION = 0.01
    no warnings 'redefine'
    *main::qv = sub ($v) { return (bless: (version::qv: $v), __PACKAGE__); }

package version::Bad
use base 'version'
sub new($self,$n) {  (bless: \$n, $self) }

package main
my $testobj = version::Empty->new: 1.002_003
isa_ok:  $testobj, "version::Empty" 
ok:  $testobj->numify == 1.002003, "Numified correctly" 
ok:  $testobj->stringify eq "1.002003", "Stringified correctly" 
ok:  $testobj->normal eq "v1.2.3", "Normalified correctly" 

my $verobj = version->new: "1.2.4"
is:  ($verobj->vcmp: $testobj), 1, "Comparison vs parent class" 
BaseTests: "version::Empty"

diag: "tests with bad subclass" unless env::var: 'PERL_CORE'
$testobj = version::Bad->new: 1.002_003
isa_ok:  $testobj, "version::Bad" 
try { my $string = $testobj->numify }
like: $^EVAL_ERROR->{?description}, qr/Invalid version object/
      "Bad subclass numify"
try { my $string = $testobj->normal }
like: $^EVAL_ERROR->{?description}, qr/Invalid version object/
      "Bad subclass normal"
try { my $string = $testobj->stringify }
like: $^EVAL_ERROR->{?description}, qr/Invalid version object/
      "Bad subclass stringify"
try { my $test = ($testobj->vcmp: 1.0) }
like: $^EVAL_ERROR->{?description}, qr/Invalid version object/
      "Bad subclass vcmp"

# dummy up a redundant call to satify David Wheeler
local $^WARN_HOOK = sub (@< @_) { (die: @_[0]) }
eval 'use version;'
unlike: $^EVAL_ERROR, qr/^Subroutine main::qv redefined/
        "Only export qv once per package (to prevent redefined warnings)."

sub BaseTests

    my (@: $CLASS, ?$no_qv) =  @_

    # Insert your test code below, the Test module is use()ed here so read
    # its man page ( perldoc Test ) for help writing this test script.

    # Test bare number processing
    diag: "tests with bare numbers" if $Verbose
    my $version = $CLASS->new: 5.005_03
    is:  $version->stringify , "5.00503" , '5.005_03 eq 5.00503' 
    $version = $CLASS->new: 1.23
    is:  $version->stringify , "1.23" , '1.23 eq "1.23"' 

    # Test quoted number processing
    diag: "tests with quoted numbers" if $Verbose
    $version = $CLASS->new: "5.005_03"
    is:  $version->stringify , "5.005_03" , '"5.005_03" eq "5.005_03"' 
    $version = $CLASS->new: "v1.23"
    is:  $version->stringify , "v1.23" , '"v1.23" eq "v1.23"' 

    # Test stringify operator
    diag: "tests with stringify" if $Verbose
    $version = $CLASS->new: "5.005"
    is:  $version->stringify , "5.005" , '5.005 eq "5.005"' 
    $version = $CLASS->new: "5.006.001"
    is:  $version->stringify , "5.006.001" , '5.006.001 eq v5.6.1' 
    $version = $CLASS->new: "1.2.3_4"
    is:  $version->stringify , "1.2.3_4" , 'alpha version 1.2.3_4 eq v1.2.3_4' 

    # test illegal formats
    diag: "test illegal formats" if $Verbose
    try {my $version = ($CLASS->new: "1.2_3_4")}
    like: $^EVAL_ERROR->{?description}, qr/multiple underscores/
          "Invalid version format (multiple underscores)"

    try {my $version = ($CLASS->new: "1.2_3.4")}
    like: $^EVAL_ERROR->{?description}, qr/underscores before decimal/
          "Invalid version format (underscores before decimal)"

    try {my $version = ($CLASS->new: "1_2")}
    like: $^EVAL_ERROR->{?description}, qr/alpha without decimal/
          "Invalid version format (alpha without decimal)"

    # for this first test, just upgrade the warn() to die()
    try {
        local $^WARN_HOOK = sub (@< @_) { (die: @_[0]->{?description}) };
        $version = ($CLASS->new: "1.2b3");
    }
    my $warnregex = "Version string '.+' contains invalid data; ".
        "ignoring: '.+'"

    like: $^EVAL_ERROR->{?description}, qr/$warnregex/
          "Version string contains invalid data; ignoring"

    # from here on out capture the warning and test independently
    do
        my $warning
        local $^WARN_HOOK = sub (@< @_) { $warning = @_[0]->{?description} }
        $version = $CLASS->new: "99 and 44/100 pure"

        like: $warning, qr/$warnregex/
              "Version string contains invalid data; ignoring"
        is: $version->stringify, "99", '$version eq "99"'
        ok: $version->numify == 99.0, '$version->numify == 99.0'
        ok: $version->normal eq "v99.0.0", '$version->normal eq v99.0.0'

        $version = $CLASS->new: "something"
        like: $warning, qr/$warnregex/
              "Version string contains invalid data; ignoring"
        ok: defined $version, 'defined $version'

        # reset the test object to something reasonable
        $version = $CLASS->new: "1.2.3"

        # Test boolean operator
        ok: $version, 'boolean'

        # Test class membership
        isa_ok:  $version, $CLASS 

        # Test comparison operators with self
        diag: "tests with self" if $Verbose
        is:  ($version->vcmp: $version), 0, '$version <=> $version == 0' 

        # Test Numeric Comparison operators
        # test first with non-object
        $version = $CLASS->new: "5.006.001"
        my $new_version = "5.8.0"
        diag: "numeric tests with non-objects" if $Verbose
        is:  ($version->vcmp: $new_version), -1, '$version < $new_version' 

        # now test with existing object
        $new_version = $CLASS->new: $new_version
        diag: "numeric tests with objects" if $Verbose
        is:  ($version->vcmp: $new_version), -1, '$version < $new_version' 

        # now test with actual numbers
        diag: "numeric tests with numbers" if $Verbose
        ok:  $version->numify == 5.006001, '$version->numify() == 5.006001' 
        ok:  $version->numify +<= 5.006001, '$version->numify() <= 5.006001' 
        ok:  $version->numify +< 5.008, '$version->numify() < 5.008' 
        #ok ( $version->numify() > v5.005_02, '$version->numify() > 5.005_02' );

        # test with long decimals
        diag: "Tests with extended decimal versions" if $Verbose
        $version = $CLASS->new: 1.002003
        is:  ($version->vcmp: "1.2.3"), 0, '$version == "1.2.3"'
        ok:  $version->numify == 1.002003, '$version->numify == 1.002003'
        $version = $CLASS->new: "2002.09.30.1"
        is:  ($version->vcmp: "2002.9.30.1"), 0,'$version == 2002.9.30.1'
        ok:  $version->numify == 2002.009030001
             '$version->numify == 2002.009030001'

        # now test with alpha version form with string
        $version = $CLASS->new: "1.2.3"
        $new_version = "1.2.3_4"
        diag: "numeric tests with alpha-style non-objects" if $Verbose
        is:  ($version->vcmp: $new_version), -1, '$version < $new_version' 

        $version = $CLASS->new: "1.2.4"
        diag: "numeric tests with alpha-style non-objects"
            if $Verbose
        is:  ($version->vcmp: $new_version), 1, '$version > $new_version' 

        # now test with alpha version form with object
        $version = $CLASS->new: "1.2.3"
        $new_version = $CLASS->new: "1.2.3_4"
        diag: "tests with alpha-style objects" if $Verbose
        is:  ($version->vcmp: $new_version), -1, '$version < $new_version' 
        ok:  !$version->is_alpha, '!$version->is_alpha'
        ok:  $new_version->is_alpha, '$new_version->is_alpha'

        $version = $CLASS->new: "1.2.4"
        diag: "tests with alpha-style objects" if $Verbose
        is:  ($version->vcmp: $new_version), 1, '$version > $new_version' 

        $version = $CLASS->new: "1.2.3.4"
        $new_version = $CLASS->new: "1.2.3_4"
        diag: "tests with alpha-style objects with same subversion"
            if $Verbose
        is:  ($version->vcmp: $new_version), 1, '$version > $new_version' 
        is:  ($new_version->vcmp: $version), -1, '$new_version < $version' 

        diag: "test implicit [in]equality" if $Verbose
        $version = $CLASS->new: "v1.2.3"
        $new_version = $CLASS->new: "1.2.3.0"
        is:  ($version->vcmp: $new_version), 0, '$version == $new_version' 
        $new_version = $CLASS->new: "1.2.3_0"
        is:  ($version->vcmp: $new_version), 0, '$version == $new_version' 
        $new_version = $CLASS->new: "1.2.3.1"
        is:  ($version->vcmp: $new_version), -1, '$version < $new_version' 
        $new_version = $CLASS->new: "1.2.3_1"
        is:  ($version->vcmp: $new_version), -1, '$version < $new_version' 
        $new_version = $CLASS->new: "1.1.999"
        is:  ($version->vcmp: $new_version), 1, '$version > $new_version' 

        # that which is not expressly permitted is forbidden
        diag: "forbidden operations" if $Verbose
        ok:  !try { ++$version }, "noop ++" 
        ok:  !try { --$version }, "noop --" 
        ok:  !try { $version/1 }, "noop /" 
        ok:  !try { $version*3 }, "noop *" 
        ok:  !try { (abs: $version) }, "noop abs" 

        :SKIP do
            skip: "version require'd instead of use'd, cannot test qv", 3
                if defined $no_qv
            # test the qv() sub
            diag: "testing qv" if $Verbose
            $version = qv: "1.2"
            is:  $version->stringify, "v1.2", 'qv("1.2") == "1.2.0"' 
            $version = qv: 1.2
            is:  $version->stringify, "v1.2", 'qv(1.2) == "1.2.0"' 
            isa_ok:  (qv: '5.008'), $CLASS 

        # test creation from existing version object
        diag: "create new from existing version" if $Verbose
        ok: try {$new_version = ($CLASS->new: $version)}
            "new from existing object"
        is: ($new_version->vcmp: $version), 0, "class->new(\$version) identical"
        $new_version = $version->new
        isa_ok:  $new_version, $CLASS 
        is: $new_version->stringify, "0", "version->new() doesn't clone"
        $new_version = $version->new: "1.2.3"
        is: $new_version->stringify, "1.2.3" , '$version->new("1.2.3") works too'

        # test the CVS revision mode
        diag: "testing CVS Revision" if $Verbose
        $version = $CLASS->new:  < qw$Revision: 1.2$
        is:  ($version->vcmp: "1.2.0"), 0, 'qw$Revision: 1.2$ == 1.2.0' 
        $version = $CLASS->new:  < qw$Revision: 1.2.3.4$
        is:  ($version->vcmp: "1.2.3.4"), 0, 'qw$Revision: 1.2.3.4$ == 1.2.3.4' 

        # test the CPAN style reduced significant digit form
        diag: "testing CPAN-style versions" if $Verbose
        $version = $CLASS->new: "1.23_01"
        is:  $version->stringify , "1.23_01", "CPAN-style alpha version" 
        is:  ($version->vcmp: 1.23), 1, "1.23_01 > 1.23"
        is:  ($version->vcmp: 1.24), -1, "1.23_01 < 1.24"

        # test reformed UNIVERSAL::VERSION
        diag: "Replacement UNIVERSAL::VERSION tests" if $Verbose

        my $error_regex = 'does not define \$...::VERSION'


        do
            open: my $f, ">", "aaa.pm" or die: "Cannot open aaa.pm: $^OS_ERROR\n"
            print: $f, "package aaa;\n\$aaa::VERSION=0.58;\n1;\n"
            close $f

            $version = "v0.580"
            eval "use lib '.'; use aaa $version"
            unlike: $^EVAL_ERROR, qr/aaa version $version/
                    'Replacement eval works with exact version'

            # test as class method
            $new_version = "aaa"->VERSION
            is: $new_version, '0.58', "Called as class method"

            eval "print: \$^STDOUT, Completely::Unknown::Module->VERSION"
            unlike: $^EVAL_ERROR, qr/$error_regex/
                    "Don't freak if the module doesn't even exist"

            # this should fail even with old UNIVERSAL::VERSION
            $version = "v0.590"
            eval "use lib '.'; use aaa $version"
            like: $^EVAL_ERROR->{?description}, qr/aaa version $version/
                  'Replacement eval works with incremented version'

            $version =~ s/0+$// #convert to string and remove trailing 0's
            chop: $version	# shorten by 1 digit, should still succeed
            eval "use lib '.'; use aaa $version"
            unlike: $^EVAL_ERROR, qr/aaa version $version/
                    'Replacement eval works with single digit'

            unlink: 'aaa.pm'
        

        do # dummy up some variously broken modules for testing
            open: my $f, ">", "xxx.pm" or die: "Cannot open xxx.pm: $^OS_ERROR\n"
            print: $f, "1;\n"
            close $f

            eval "use lib '.'; use xxx v3;"
            like: $^EVAL_ERROR->{?description}, qr/xxx defines neither package nor VERSION/
                  'Replacement handles modules without package or VERSION'
            eval "use lib '.'; use xxx; \$version = xxx->VERSION"
            unlike: $^EVAL_ERROR, qr/$error_regex/
                    'Replacement handles modules without package or VERSION'
            ok: !(defined: $version), "Called as class method"
            unlink: 'xxx.pm'
        

        do # dummy up some variously broken modules for testing
            open: my $f, ">", "yyy.pm" or die: "Cannot open yyy.pm: $^OS_ERROR\n"
            print: $f, "package yyy;\n#look ma no VERSION\n1;\n"
            close $f
            eval "use lib '.'; use yyy v3;"
            like: $^EVAL_ERROR->{?description}, qr/$error_regex/
                  'Replacement handles modules without VERSION'
            eval "use lib '.'; use yyy; print: \$^STDOUT, yyy->VERSION"
            unlike: $^EVAL_ERROR, qr/$error_regex/
                    'Replacement handles modules without VERSION'
            unlink: 'yyy.pm'
        

        do # dummy up some variously broken modules for testing
            open: my $f, ">", "zzz.pm" or die: "Cannot open zzz.pm: $^OS_ERROR\n"
            print: $f, "package zzz;\nour \@VERSION = ();\n1;\n"
            close $f
            eval "use lib '.'; use zzz v3;"
            like: $^EVAL_ERROR->{?description}, qr/$error_regex/
                  'Replacement handles modules without VERSION'
            eval "use lib '.'; use zzz; print: \$^STDOUT, zzz->VERSION"
            unlike: $^EVAL_ERROR, qr/$error_regex/
                    'Replacement handles modules without VERSION'
            unlink: 'zzz.pm'
        

        :SKIP 	do
            diag: "Tests with v-strings" if $Verbose
            $version = $CLASS->new: v1.2.3
            is: $version->stringify, "v1.2.3", '"$version" == 1.2.3'
            $version = $CLASS->new: v1.0.0
            $new_version = $CLASS->new: 1
            is: ($version->vcmp: $new_version), 0, '$version == $new_version'
            skip: "version require'd instead of use'd, cannot test qv", 1
                if defined $no_qv
            $version = qv: "v1.2.3"
            ok: $version->stringify == "v1.2.3", 'v-string initialized qv()'
        

        diag: "Tests with real-world (malformed) data" if $Verbose

        # trailing zero testing (reported by Andreas Koenig).
        $version = $CLASS->new: "1"
        ok: $version->numify eq "1.000", "trailing zeros preserved"
        $version = $CLASS->new: "1.0"
        ok: $version->numify eq "1.000", "trailing zeros preserved"
        $version = $CLASS->new: "1.0.0"
        ok: $version->numify eq "1.000000", "trailing zeros preserved"
        $version = $CLASS->new: "1.0.0.0"
        ok: $version->numify eq "1.000000000", "trailing zeros preserved"

        # leading zero testing (reported by Andreas Koenig).
        $version = $CLASS->new: ".7"
        ok: $version->numify eq "0.700", "leading zero inferred"

        # leading space testing (reported by Andreas Koenig).
        $version = $CLASS->new: " 1.7"
        ok: $version->numify eq "1.700", "leading space ignored"

        # RT 19517 - deal with undef and 'undef' initialization
        ok: $version->stringify ne 'undef', "Undef version comparison #1"
        ok: $version->stringify ne undef, "Undef version comparison #2"
        $version = $CLASS->new: 'undef'
        unlike: $warning, qr/^Version string 'undef' contains invalid data/
                "Version string 'undef'"

        $version = $CLASS->new: undef
        like: $warning, qr/^Use of uninitialized value/
              "Version string 'undef'"
        is: ($version->vcmp: 'undef'), 0, "Undef version comparison #3"
        is: ($version->vcmp: undef), 0,  "Undef version comparison #4"
        eval "\$version = \$CLASS->new:" # no parameter at all
        unlike: $^EVAL_ERROR, qr/^Bizarre copy of CODE/, "No initializer at all"
        is: ($version->vcmp: 'undef'), 0, "Undef version comparison #5"
        is: ($version->vcmp: undef), 0,  "Undef version comparison #6"

        $version = $CLASS->new: 0.000001
        unlike: $warning, qr/^Version string '1e-06' contains invalid data/
                "Very small version objects"
    

    :SKIP do
        # dummy up a legal module for testing RT#19017
        open: my $f, ">", "www.pm" or die: "Cannot open www.pm: $^OS_ERROR\n"
        print: $f ,<<"EOF"
package www;
use version; our \$VERSION = qv('0.0.4');
1;
EOF
        close $f

        eval "use lib '.'; use www v0.000008;"
        like: $^EVAL_ERROR->{?description}, qr/^www version v0.8.0 required/
              "Make sure very small versions don't freak"
        eval "use lib '.'; use www v1;"
        like: $^EVAL_ERROR->{?description}, qr/^www version v1.0.0 required/
              "Comparing vs. version with no decimal"
        eval "use lib '.'; use www v1.;"
        like: $^EVAL_ERROR->{?description}, qr/^www version v1.0.0 required/
              "Comparing vs. version with decimal only"

        eval "use lib '.'; use www v0.0.8;"
        my $regex = "^www version v0.0.8 required"
        like: $^EVAL_ERROR->{?description}, qr/$regex/, "Make sure very small versions don't freak"

        $regex =~ s/8/4/ # set for second test
        eval "use lib '.'; use www v0.0.4;"
        unlike: $^EVAL_ERROR, qr/$regex/, 'Succeed - required == VERSION'
        cmp_ok:  "www"->VERSION, 'eq', '0.0.4', 'No undef warnings' 

        unlink: 'www.pm'
    

    open: my $f, ">", "vvv.pm" or die: "Cannot open vvv.pm: $^OS_ERROR\n"
    print: $f ,<<"EOF"
package vvv;
use base q(version);
1;
EOF
    close $f
    # need to eliminate any other qv()'s
    undef *main::qv
    ok: !(exists: (Symbol::fetch_glob: "main\::qv")->&), "make sure we cleared qv() properly"
    eval "use lib '.'; use vvv;"
    die: if $^EVAL_ERROR
    ok: (exists: (Symbol::fetch_glob: "main\::qv")->&), "make sure we exported qv() properly"
    isa_ok:  eval'qv(1.2)', "vvv"
    unlink: 'vvv.pm'

    :SKIP do
        open: my $f, ">", "uuu.pm" or die: "Cannot open uuu.pm: $^OS_ERROR\n"
        print: $f ,<<"EOF"
package uuu;
our \$VERSION = 1.0;
1;
EOF
        close $f
        eval "use lib '.'; use uuu v1.001;"
        like: $^EVAL_ERROR->{?description}, qr/^uuu version v1.1.0 required/
              "User typed numeric so we error with numeric"
        eval "use lib '.'; use uuu v1.1.0;"
        like: $^EVAL_ERROR->{?description}, qr/^uuu version v1.1.0 required/
              "User typed extended so we error with extended"
        unlink: 'uuu.pm'
    

    :SKIP do
        # test locale handling
        my $warning
        local $^WARN_HOOK = sub (@< @_) { $warning = @_[0] }
        my $ver = 1.23  # has to be floating point number
        my $loc
        while ( ~< $^DATA)
            chomp
            $loc = POSIX::setlocale: (POSIX::LC_ALL:  < @_ ), $_
            last if (POSIX::localeconv: )->{?decimal_point} eq ','
        
        skip: 'Cannot test locale handling without a comma locale', 3
            unless ( $loc and ($ver eq '1,23') )

        diag: "Testing locale handling with $loc" if $Verbose

        my $v = $CLASS->new: $ver
        unlike: $warning,qr/Version string '1,23' contains invalid data/
                "Process locale-dependent floating point"
        is: $v->stringify, "1.23", "Locale doesn't apply to version objects"
    

    eval 'my $v = $CLASS->new("1._1");'
    unlike: $^EVAL_ERROR->{?description}, qr/^Invalid version format \(alpha with zero width\)/
            "Invalid version format 1._1"

    do
        my $warning
        local $^WARN_HOOK = sub (@< @_) { $warning = @_[0] }
        try { my $v = ($CLASS->new: ^~^0); }
        unlike: $^EVAL_ERROR, qr/Integer overflow in version/, "Too large version"
        like: $warning->{?description}, qr/Integer overflow in version/, "Too large version"

    do
        # http://rt.perl.org/rt3/Ticket/Display.html?id=56606
        my $badv = bless: (\%: version => \@: 1,2,3 ), "version"
        is: $badv->stringify, '1.002003', "Deal with badly serialized versions from YAML"
        my $badv2 = bless: (\%: qv => 1, version => \@: 1,2,3 ), "version"
        is: $badv2->stringify, 'v1.2.3', "Deal with badly serialized versions from YAML "

1

__DATA__
af_ZA
af_ZA.utf8
an_ES
an_ES.utf8
az_AZ.utf8
be_BY
be_BY.utf8
bg_BG
bg_BG.utf8
br_FR
br_FR@euro
br_FR.utf8
bs_BA
bs_BA.utf8
ca_ES
ca_ES@euro
ca_ES.utf8
cs_CZ
cs_CZ.utf8
da_DK
da_DK.utf8
de_AT
de_AT@euro
de_AT.utf8
de_BE
de_BE@euro
de_BE.utf8
de_DE
de_DE@euro
de_DE.utf8
de_LU
de_LU@euro
de_LU.utf8
el_GR
el_GR.utf8
en_DK
en_DK.utf8
es_AR
es_AR.utf8
es_BO
es_BO.utf8
es_CL
es_CL.utf8
es_CO
es_CO.utf8
es_EC
es_EC.utf8
es_ES
es_ES@euro
es_ES.utf8
es_PY
es_PY.utf8
es_UY
es_UY.utf8
es_VE
es_VE.utf8
et_EE
et_EE.iso885915
et_EE.utf8
eu_ES
eu_ES@euro
eu_ES.utf8
fi_FI
fi_FI@euro
fi_FI.utf8
fo_FO
fo_FO.utf8
fr_BE
fr_BE@euro
fr_BE.utf8
fr_CA
fr_CA.utf8
fr_CH
fr_CH.utf8
fr_FR
fr_FR@euro
fr_FR.utf8
fr_LU
fr_LU@euro
fr_LU.utf8
gl_ES
gl_ES@euro
gl_ES.utf8
hr_HR
hr_HR.utf8
hu_HU
hu_HU.utf8
id_ID
id_ID.utf8
is_IS
is_IS.utf8
it_CH
it_CH.utf8
it_IT
it_IT@euro
it_IT.utf8
ka_GE
ka_GE.utf8
kk_KZ
kk_KZ.utf8
kl_GL
kl_GL.utf8
lt_LT
lt_LT.utf8
lv_LV
lv_LV.utf8
mk_MK
mk_MK.utf8
mn_MN
mn_MN.utf8
nb_NO
nb_NO.utf8
nl_BE
nl_BE@euro
nl_BE.utf8
nl_NL
nl_NL@euro
nl_NL.utf8
nn_NO
nn_NO.utf8
no_NO
no_NO.utf8
oc_FR
oc_FR.utf8
pl_PL
pl_PL.utf8
pt_BR
pt_BR.utf8
pt_PT
pt_PT@euro
pt_PT.utf8
ro_RO
ro_RO.utf8
ru_RU
ru_RU.koi8r
ru_RU.utf8
ru_UA
ru_UA.utf8
se_NO
se_NO.utf8
sh_YU
sh_YU.utf8
sk_SK
sk_SK.utf8
sl_SI
sl_SI.utf8
sq_AL
sq_AL.utf8
sr_CS
sr_CS.utf8
sv_FI
sv_FI@euro
sv_FI.utf8
sv_SE
sv_SE.iso885915
sv_SE.utf8
tg_TJ
tg_TJ.utf8
tr_TR
tr_TR.utf8
tt_RU.utf8
uk_UA
uk_UA.utf8
vi_VN
vi_VN.tcvn
wa_BE
wa_BE@euro
wa_BE.utf8

