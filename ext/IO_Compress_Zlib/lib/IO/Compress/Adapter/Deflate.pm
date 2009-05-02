package IO::Compress::Adapter::Deflate ;

use warnings;
use bytes;

use IO::Compress::Base::Common  v2.006 < qw(:Status);

use Compress::Raw::Zlib  v2.006 < qw(Z_OK Z_FINISH MAX_WBITS) ;
our ($VERSION);

$VERSION = '2.006';

sub mkCompObject(@< @_)
{
    my $crc32    = shift @_ ;
    my $adler32  = shift @_ ;
    my $level    = shift @_ ;
    my $strategy = shift @_ ;

    my @($def, $status) =  Compress::Raw::Zlib::Deflate->new(
        AppendOutput   => 1,
        CRC32          => $crc32,
        ADLER32        => $adler32,
        Level          => $level,
        Strategy       => $strategy,
        WindowBits     => - MAX_WBITS);

    return  @(undef, "Cannot create Deflate object: $status", $status) 
        if $status != Z_OK;    

    return @(bless \%('Def'        => $def,
                 'Error'      => '',
             ) );
}

sub compr($self, $inbuffer, $outbuffer)
{
    my $def   = $self->{?Def};

    my $status = $def->deflate($inbuffer, $outbuffer) ;
    $self->{+ErrorNo} = $status;

    if ($status != Z_OK)
    {
        $self->{+Error} = "Deflate Error: $status"; 
        return STATUS_ERROR;
    }

    return STATUS_OK;    
}

sub flush(@< @_)
{
    my $self = shift @_ ;

    my $def   = $self->{?Def};

    my $opt = @_[1] || Z_FINISH;
    my $status = $def->flush(@_[0], $opt);
    $self->{+ErrorNo} = $status;

    if ($status != Z_OK)
    {
        $self->{+Error} = "Deflate Error: $status"; 
        return STATUS_ERROR;
    }

    return STATUS_OK;    

}

sub close(@< @_)
{
    my $self = shift @_ ;

    my $def   = $self->{?Def};

    $def->flush(@_[0], Z_FINISH)
        if defined $def ;
}

sub reset($self)
{

    my $def   = $self->{?Def};

    my $status = $def->deflateReset() ;
    $self->{+ErrorNo} = $status;
    if ($status != Z_OK)
    {
        $self->{+Error} = "Deflate Error: $status"; 
        return STATUS_ERROR;
    }

    return STATUS_OK;    
}

#sub total_out
#{
#    my $self = shift ;
#    $self->{Def}->total_out();
#}
#
#sub total_in
#{
#    my $self = shift ;
#    $self->{Def}->total_in();
#}

sub compressedBytes($self)
{

    $self->{Def}->compressedBytes();
}

sub uncompressedBytes($self)
{
    $self->{Def}->uncompressedBytes();
}




sub crc32($self)
{
    $self->{Def}->crc32();
}

sub adler32($self)
{
    $self->{Def}->adler32();
}


1;

__END__

