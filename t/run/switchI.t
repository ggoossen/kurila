#!./perl -IFoo::Bar -IBla

BEGIN 
    require './test.pl'	# for which_perl() etc


BEGIN 
    plan: 4


my $Is_MacOS = $^OS_NAME eq 'MacOS'
my $Is_VMS   = $^OS_NAME eq 'VMS'
my $lib

$lib = $Is_MacOS ?? ':Bla:' !! 'Bla'
ok: (grep: { $_ eq $lib }, $^INCLUDE_PATH)
:SKIP do
    skip: 'Double colons not allowed in dir spec', 1 if $Is_VMS
    $lib = $Is_MacOS ?? 'Foo::Bar:' !! 'Foo::Bar'
    ok: (grep: { $_ eq $lib }, $^INCLUDE_PATH)


$lib = $Is_MacOS ?? ':Bla2:' !! 'Bla2'
fresh_perl_is: "print \$^STDOUT, < grep \{ \$_ eq '$lib' \}, \$^INCLUDE_PATH", $lib
               \(%:  switches => \(@: '-IBla2') ), '-I'
:SKIP do
    skip: 'Double colons not allowed in dir spec', 1 if $Is_VMS
    $lib = $Is_MacOS ?? 'Foo::Bar2:' !! 'Foo::Bar2'
    fresh_perl_is: "print \$^STDOUT, < grep \{ \$_ eq '$lib' \}, \$^INCLUDE_PATH", $lib
                   \(%:  switches => \(@: '-IFoo::Bar2') ), '-I with colons'

