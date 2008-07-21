BEGIN {
    if( %ENV{PERL_CORE} ) {
	@INC = @( '../lib' );
	chdir 't';
    }
}

use IO::Zlib;

use bytes;

sub ok
{
    my ($no, $ok) = < @_ ;

    #++ $total ;
    #++ $totalBad unless $ok ;

    print "ok $no\n" if $ok ;
    print "not ok $no\n" unless $ok ;
}

my $name="test.gz";

print "1..7\n";

my $contents = "";

foreach (1 .. 5000)
{
     $contents .= chr(int(rand(255)));
}

ok(1, my $file = IO::Zlib->new($name, "wb"));
ok(2, $file->print($contents));
ok(3, $file->close());

ok(4, $file = IO::Zlib->new($name, "rb"));
ok(5, $file->read(my $uncomp, 8192) == length($contents));
ok(6, $file->close());

unlink($name);

ok(7, $contents eq $uncomp);
