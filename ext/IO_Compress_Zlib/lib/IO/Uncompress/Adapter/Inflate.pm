package IO::Uncompress::Adapter::Inflate;

use warnings;
use bytes;

use IO::Compress::Base::Common  v2.006 < qw(:Status);
use Compress::Raw::Zlib  v2.006 < qw(Z_OK Z_DATA_ERROR Z_STREAM_END Z_FINISH MAX_WBITS);

our ($VERSION);
$VERSION = '2.006';



sub mkUncompObject(@< @_)
{
    my $crc32   = shift @_ || 1;
    my $adler32 = shift @_ || 1;
    my $scan    = shift @_ || 0;

    my $inflate ;
    my $status ;

    if ($scan)
    {
        @($inflate, $status) =  Compress::Raw::Zlib::InflateScan->new(
            CRC32        => $crc32,
            ADLER32      => $adler32,
            WindowBits   => - MAX_WBITS) ;
    }
    else
    {
        @($inflate, $status) =  Compress::Raw::Zlib::Inflate->new(
            AppendOutput => 1,
            CRC32        => $crc32,
            ADLER32      => $adler32,
            WindowBits   => - MAX_WBITS) ;
    }

    return  @(undef, "Could not create Inflation object: $status", $status) 
        if $status != Z_OK ;

    return @( bless \%('Inf'        => $inflate,
                  'CompSize'   => 0,
                      'UnCompSize' => 0,
                      'Error'      => '',
              ) );     

}

sub uncompr(@< @_)
{
    my $self = shift @_ ;
    my $from = shift @_ ;
    my $to   = shift @_ ;
    my $eof  = shift @_ ;

    my $inf   = $self->{?Inf};

    my $status = $inf->inflate($from, $to, $eof);
    $self->{+ErrorNo} = $status;

    if ($status != Z_STREAM_END && $eof)
    {
        $self->{+Error} = "unexpected end of file";
        return STATUS_ERROR;
    }

    if ($status != Z_OK && $status != Z_STREAM_END )
    {
        $self->{+Error} = "Inflation Error: $status";
        return STATUS_ERROR;
    }


    return STATUS_OK        if $status == Z_OK ;
    return STATUS_ENDSTREAM if $status == Z_STREAM_END ;
    return STATUS_ERROR ;
}

sub reset($self)
{
    $self->{Inf}->inflateReset();

    return STATUS_OK ;
}

#sub count
#{
#    my $self = shift ;
#    $self->{Inf}->inflateCount();
#}

sub crc32($self)
{
    $self->{Inf}->crc32();
}

sub compressedBytes($self)
{
    $self->{Inf}->compressedBytes();
}

sub uncompressedBytes($self)
{
    $self->{Inf}->uncompressedBytes();
}

sub adler32($self)
{
    $self->{Inf}->adler32();
}

sub sync(@< @_)
{
    my $self = shift @_ ;
    ( $self->{?Inf}->inflateSync(< @_) == Z_OK) 
        ?? STATUS_OK 
        !! STATUS_ERROR ;
}


sub getLastBlockOffset($self)
{
    $self->{Inf}->getLastBlockOffset();
}

sub getEndOffset($self)
{
    $self->{Inf}->getEndOffset();
}

sub resetLastBlockByte(@< @_)
{
    my $self = shift @_ ;
    $self->{?Inf}->resetLastBlockByte(< @_);
}

sub createDeflateStream(@< @_)
{
    my $self = shift @_ ;
    my $deflate = $self->{?Inf}->createDeflateStream(< @_);
    return bless \%('Def'        => $deflate,
            'CompSize'   => 0,
                'UnCompSize' => 0,
                'Error'      => '',
        ), 'IO::Compress::Adapter::Deflate';
}

1;


__END__

