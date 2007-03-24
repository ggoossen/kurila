
use lib 't';
use strict;
use warnings;
use bytes;

use Test::More ;
use CompTestUtils;

BEGIN
{
    plan(skip_all => "Destroy not supported in Perl $]")
        if $] == 5.008 || ( $] >= 5.005 && $] < 5.006) ;

    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  Test::NoWarnings->import(); 1 };

    plan tests => 7 + $extra ;

    use_ok('IO::File') ;
}

sub run
{

    my $CompressClass   = identify();
    my $UncompressClass = getInverse($CompressClass);
    my $Error           = getErrorRef($CompressClass);
    my $UnError         = getErrorRef($UncompressClass);

    title "Testing $CompressClass";

    {
        # Check that the class destructor will call close

        my $lex = LexFile->new( my $name) ;

        my $hello = <<EOM ;
hello world
this is a test
EOM


        {
          ok my $x = $CompressClass-> new( $name, -AutoClose => 1)  ;

          ok $x->write($hello) ;
        }

        is anyUncompress($name), $hello ;
    }

    {
        # Tied filehandle destructor


        my $lex = LexFile->new( my $name) ;

        my $hello = <<EOM ;
hello world
this is a test
EOM

        my $fh = IO::File->new( "> $name") ;

        {
          ok my $x = $CompressClass-> new( $fh, -AutoClose => 1)  ;

          $x->write($hello) ;
        }

        ok anyUncompress($name) eq $hello ;
    }
}

1;
