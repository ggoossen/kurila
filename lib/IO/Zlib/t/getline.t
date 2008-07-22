BEGIN {
    if( %ENV{PERL_CORE} ) {
	@INC = @( '../lib' );
	chdir 't';
    }
}

use IO::Zlib;
use Test::More;

my $name="test.gz";

plan tests => 22;

my @text = @(<<EOM, <<EOM, <<EOM, <<EOM) ;
this is line 1
EOM
the second line
EOM
the line after the previous line
EOM
the final line
EOM

my $text = join("", < @text) ;

ok(my $file = IO::Zlib->new($name, "wb"));
ok($file->print($text));
ok($file->close());

ok($file = IO::Zlib->new($name, "rb"));
ok(!$file->eof());
ok($file->getline() eq @text[0]);
ok($file->getline() eq @text[1]);
ok($file->getline() eq @text[2]);
ok($file->getline() eq @text[3]);
ok(!defined($file->getline()));
ok($file->eof());
ok($file->close());

ok($file = IO::Zlib->new($name, "rb"));
ok(!$file->eof());
ok(my @lines = @( < $file->getlines() ));
ok((nelems @lines) == nelems @text);
ok(@lines[0] eq @text[0]);
ok(@lines[1] eq @text[1]);
ok(@lines[2] eq @text[2]);
ok(@lines[3] eq @text[3]);
ok($file->eof());
ok($file->close());

unlink($name);
