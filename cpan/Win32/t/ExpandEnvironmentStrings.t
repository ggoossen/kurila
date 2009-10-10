use Test::More;
use Win32;

plan tests => 1;

is(Win32::ExpandEnvironmentStrings("%WINDIR%"), $ENV{WINDIR});
