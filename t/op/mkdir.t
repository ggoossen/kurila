#!./perl -w

BEGIN 
    require './test.pl'


plan: tests => 22

use File::Path
rmtree: 'blurfl'

# tests 3 and 7 rather naughtily expect English error messages
(env::var: 'LC_ALL' ) = 'C'
(env::var: 'LANGUAGE' ) = 'C' # GNU locale extension

ok: (mkdir: 'blurfl',0777)
ok: !(mkdir: 'blurfl',0777)
like: $^OS_ERROR, qr/cannot move|exist|denied|unknown/i
ok: -d 'blurfl'
ok: (rmdir: 'blurfl')
ok: !(rmdir: 'blurfl')
like: $^OS_ERROR, qr/cannot find|such|exist|not found|not a directory|unknown/i
ok: (mkdir: 'blurfl')
ok: (rmdir: 'blurfl')

:SKIP do
    # trailing slashes will be removed before the system call to mkdir
    # but we don't care for MacOS ...
    skip: "MacOS", 4 if $^OS_NAME eq 'MacOS'
    ok: (mkdir: 'blurfl///')
    ok: -d 'blurfl'
    ok: (rmdir: 'blurfl///')
    ok: !-d 'blurfl'


# test default argument

$_ = 'blurfl'
ok: (mkdir: )
ok: -d
ok: rmdir
ok: !-d
$_ = 'lfrulb'

do
    my $_ = 'blurfl'
    ok: (mkdir: )
    ok: -d
    ok: -d 'blurfl'
    ok: !-d 'lfrulb'
    ok: rmdir

