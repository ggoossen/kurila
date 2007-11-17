use IO::Zlib;

use Test::More;

$name="test.gz";

plan tests => 17;

$hello = <<EOM ;
hello world
this is a test
EOM

ok($file = IO::Zlib->new($name, "wb"));
ok($file->print($hello));
ok($file->opened());
ok($file->close());
ok(!$file->opened());

ok($file = IO::Zlib->new());
ok($file->open($name, "rb"));
ok(!$file->eof());
ok($file->read($uncomp, 1024) == length($hello));
is($uncomp, $hello);
ok($file->eof());
ok($file->opened());
ok($file->close());
ok(!$file->opened());

$file = IO::Zlib->new($name, "rb");
ok($file->read($uncomp, 1024, length($uncomp)) == length($hello));
ok($uncomp eq $hello . $hello);
$file->close();

unlink($name);

ok(!defined(IO::Zlib->new($name, "rb")));
