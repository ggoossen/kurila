
package IO::Compress::Base ;


use warnings;

use IO::Compress::Base::Common v2.006 ;

use IO::File ;
use Scalar::Util < qw(blessed readonly);

#use File::Glob;
#require Exporter ;
use Carp ;
use Symbol;
use bytes;

our (@ISA, $VERSION);
#@ISA    = qw(Exporter IO::File);

$VERSION = '2.006';

#Can't locate object method "SWASHNEW" via package "utf8" (perhaps you forgot to load "utf8"?) at .../ext/Compress-Zlib/Gzip/blib/lib/Compress/Zlib/Common.pm line 16.

sub saveStatus(@< @_)
{
    my $self   = shift @_ ;
     $self->{ErrorNo}->$ = shift( @_) + 0 ;
     $self->{Error}->$ = '' ;

    return  $self->{?ErrorNo}->$ ;
}


sub saveErrorString(@< @_)
{
    my $self   = shift @_ ;
    my $retval = shift @_ ;
     $self->{Error}->$ = shift( @_) . ($self->{?Error}->$ ?? "\nprevious: $($self->{?Error}->$)" !! "") ;
     $self->{ErrorNo}->$ = shift( @_) + 0 if (nelems @_) ;

    return $retval;
}

sub croakError(@< @_)
{
    my $self   = shift @_ ;
    $self->saveErrorString(0, @_[0]);
    croak @_[0];
}

sub closeError(@< @_)
{
    my $self = shift @_ ;
    my $retval = shift @_ ;

    my $errno = $self->{?ErrorNo};
    my $error =  $self->{?Error}->$;

    $self->close();

    $self->{+ErrorNo} = $errno ;
     $self->{Error}->$ = $error ;

    return $retval;
}



sub error($self)
{
    return  $self->{?Error}->$ ;
}

sub errorNo($self)
{
    return  $self->{?ErrorNo}->$ ;
}


sub writeAt(@< @_)
{
    my $self = shift @_ ;
    my $offset = shift @_;
    my $data = shift @_;

    if (defined $self->{?FH}) {
        my $here = tell($self->{?FH});
        return $self->saveErrorString(undef, "Cannot seek to end of output filehandle: $^OS_ERROR", $^OS_ERROR) 
            if $here +< 0 ;
        seek($self->{?FH}, $offset, SEEK_SET)
            or return $self->saveErrorString(undef, "Cannot seek to end of output filehandle: $^OS_ERROR", $^OS_ERROR) ;
        defined $self->{?FH}->write($data, length $data)
            or return $self->saveErrorString(undef, $^OS_ERROR, $^OS_ERROR) ;
        seek($self->{?FH}, $here, SEEK_SET)
            or return $self->saveErrorString(undef, "Cannot seek to end of output filehandle: $^OS_ERROR", $^OS_ERROR) ;
    }
    else {
        substr( $self->{?Buffer}->$, $offset, length($data), $data) ;
    }

    return 1;
}

sub output(@< @_)
{
    my $self = shift @_ ;
    my $data = shift @_ ;
    my $last = shift @_ ;

    return 1 
        if length $data == 0 && ! $last ;

    if ( $self->{?FilterEnvelope} ) {
        *_ = \$data;
        &{ $self->{?FilterEnvelope} }();
    }

    if ( defined $self->{?FH} ) {
        defined IO::Handle::write($self->{?FH}, $data, length $data )
            or return $self->saveErrorString(0, $^OS_ERROR, $^OS_ERROR); 
    }
    else {
         $self->{Buffer}->$ .= $data ;
    }

    return 1;
}

sub getOneShotParams(...)
{
    return  @( 'MultiStream' => \@(1, 1, Parse_boolean,   1),
        );
}

sub checkParams(@< @_)
{
    my $self = shift @_ ;
    my $class = shift @_ ;

    my $got = shift @_ || IO::Compress::Base::Parameters::new();

    $got->parse(
        \%(
            # Generic Parameters
            'AutoClose' => \@(1, 1, Parse_boolean,   0),
                #'Encode'    => [1, 1, Parse_any,       undef],
                'Strict'    => \@(0, 1, Parse_boolean,   1),
                'Append'    => \@(1, 1, Parse_boolean,   0),
                'BinModeIn' => \@(1, 1, Parse_boolean,   0),

                'FilterEnvelope' => \@(1, 1, Parse_any,   undef),

                < $self->getExtraParams(),
                $self->{?OneShot} ?? < $self->getOneShotParams() !! (),
        ), 
        < @_) or die("$(dump::view($class)): $(dump::view($got->{?Error}))")  ;

    return $got ;
}

sub _create(@< @_)
{
    my $obj = shift @_;
    my $got = shift @_;

    $obj->{+Closed} = 1 ;

    my $class = ref $obj;
    $obj->croakError("$class: Missing Output parameter")
        if ! nelems @_ && ! $got ;

    my $outValue = shift @_ ;
    my $oneShot = 1 ;

    if (! $got)
    {
        $oneShot = 0 ;
        $got = $obj->checkParams($class, undef, < @_)
            or $obj->croakError("invalid params");
    }

    my $lax = ! $got->value('Strict') ;

    my $outType = whatIsOutput($outValue);

    $obj->ckOutputParam($class, $outValue)
        or $obj->croakError("invalid output param");

    if ($outType eq 'buffer') {
        $obj->{+Buffer} = $outValue;
    }
    else {
        my $buff = "" ;
        $obj->{+Buffer} = \$buff ;
    }

    my $appendOutput = $got->value('Append');
    $obj->{+Append} = $appendOutput;
    $obj->{+FilterEnvelope} = $got->value('FilterEnvelope') ;

    # If output is a file, check that it is writable
    if ($outType eq 'filename' && -e $outValue && ! -w _)
    { return $obj->saveErrorString(undef, "Output file '$outValue' is not writable" ) }



    if ($got->parsed('Encode')) { 
        my $want_encoding = $got->value('Encode');
        $obj->*->{+Encoding} = getEncoding($obj, $class, $want_encoding);
    }

    $obj->ckParams($got)
        or $obj->croakError("$($class): " . $obj->error());


    $obj->saveStatus(STATUS_OK) ;

    my $status ;
    do {
        $obj->{+Compress} = $obj->mkComp($class, $got)
        or $obj->croakError("Failed making Compress");

        $obj->{+UnCompSize} = U64->new() ;
        $obj->{+CompSize} = U64->new() ;

        if ( $outType eq 'buffer') {
             $obj->{Buffer}->$  = ''
                unless $appendOutput ;
        }
        else {
            if ($outType eq 'handle') {
                $obj->{+FH} = $outValue ;
                IO::Handle::flush($outValue);
                $obj->{+Handle} = 1 ;
                if ($appendOutput)
                {
                    seek($obj->{?FH}, 0, SEEK_END)
                        or return $obj->saveErrorString(undef, "Cannot seek to end of output filehandle: $^OS_ERROR", $^OS_ERROR) ;

                }
            }
            elsif ($outType eq 'filename') {    
                my $mode = '>' ;
                $mode = '>>'
                    if $appendOutput;
                $obj->{+FH} = IO::File->new( "$outValue", "$mode")
                or return $obj->saveErrorString(undef, "cannot open file '$outValue': $^OS_ERROR", $^OS_ERROR) ;
                $obj->{+StdIO} = ($outValue eq '-'); 
            }
        }

        $obj->{+Header} = $obj->mkHeader($got) ;
        $obj->output( $obj->{Header} )
            or $obj->croakError("Failed writing header");
    };

    $obj->{+Closed} = 0 ;
    $obj->{+AutoClose} = $got->value('AutoClose') ;
    $obj->{+Output} = $outValue;
    $obj->{+ClassName} = $class;
    $obj->{+Got} = $got;
    $obj->{+OneShot} = 0 ;

    return $obj ;
}

sub ckOutputParam(@< @_) 
{
    my $self = shift @_ ;
    my $from = shift @_ ;
    my $outType = whatIsOutput(@_[0]);

    $self->croakError("$from: output parameter not a filename, filehandle or scalar ref")
        if ! $outType ;

    $self->croakError("$from: output filename is undef or null string")
        if $outType eq 'filename' && (! defined @_[0] || @_[0] eq '')  ;

    $self->croakError("$from: output buffer is read-only")
        if $outType eq 'buffer' && readonly( @_[0]->$);

    return 1;    
}


sub _def(@< @_)
{
    my $obj = shift @_ ;

    my $class= @(caller)[0] ;
    my $name = @(caller(1))[3] ;

    $obj->croakError("$name: expected at least 1 parameters\n")
        unless (nelems @_) +>= 1 ;

    my $input = shift @_ ;
    my $haveOut = (nelems @_) ;
    my $output = shift @_ ;

    my $x = Validator->new($class, $obj->{?Error}, $name, $input, $output)
        or return undef ;

    push @_, $output if $haveOut && $x->{?Hash};

    $obj->{+OneShot} = 1 ;

    my $got = $obj->checkParams($name, undef, < @_)
        or return undef ;

    $x->{+Got} = $got ;

    #    if ($x->{Hash})
    #    {
    #        while (my($k, $v) = each %$input)
    #        {
    #            $v = \$input->{$k} 
    #                unless defined $v ;
    #
    #            $obj->_singleTarget($x, 1, $k, $v, @_)
    #                or return undef ;
    #        }
    #
    #        return keys %$input ;
    #    }

    if ($x->{?GlobMap})
    {
        $x->{+oneInput} = 1 ;
        foreach my $pair (  $x->{Pairs}->@)
        {
            my @($from, $to) =  $pair->@ ;
            $obj->_singleTarget($x, 1, $from, $to, < @_)
                or return undef ;
        }

        return scalar nelems  $x->{?Pairs}->@ ;
    }

    if (! $x->{?oneOutput} )
    {
        my $inFile = ($x->{?inType} eq 'filenames' 
                      || $x->{?inType} eq 'filename');

        $x->{+inType} = $inFile ?? 'filename' !! 'buffer';

        foreach my $in (@($x->{?oneInput} ?? $input !! < $input->@))
        {
            my $out ;
            $x->{+oneInput} = 1 ;

            $obj->_singleTarget($x, $inFile, $in, \$out, < @_)
                or return undef ;

            push $output->@, \$out ;
        #if ($x->{outType} eq 'array')
        #  { push @$output, \$out }
        #else
        #  { $output->{$in} = \$out }
        }

        return 1 ;
    }

    # finally the 1 to 1 and n to 1
    return $obj->_singleTarget($x, 1, $input, $output, < @_);

    croak "should not be here" ;
}

sub _singleTarget(@< @_)
{
    my $obj             = shift @_ ;
    my $x               = shift @_ ;
    my $inputIsFilename = shift @_;
    my $input           = shift @_;

    if ($x->{?oneInput})
    {
        my $z = $obj->_create($x->{?Got}, < @_)
            or return undef ;


        defined $z->_wr2($input, $inputIsFilename) 
            or return $z->closeError(undef) ;

        return $z->close() ;
    }
    else
    {
        my $afterFirst = 0 ;
        my $inputIsFilename = ($x->{?inType} ne 'array');
        my $keep = $x->{Got}->clone();

        #for my $element ( ($x->{inType} eq 'hash') ? keys %$input : @$input)
        for my $element (  $input->@)
        {
            my $isFilename = isaFilename($element);

            if ( $afterFirst ++ )
            {
                defined addInterStream($obj, $element, $isFilename)
                    or return $obj->closeError(undef) ;
            }
            else
            {
                $obj->getFileInfo($x->{?Got}, $element)
                    if $isFilename;

                $obj->_create($x->{?Got}, < @_)
                    or return undef ;
            }

            defined $obj->_wr2($element, $isFilename) 
                or return $obj->closeError(undef) ;

            $obj->*->{+Got} = $keep->clone();
        }
        return $obj->close() ;
    }

}

sub _wr2(@< @_)
{
    my $self = shift @_ ;

    my $source = shift @_ ;
    my $inputIsFilename = shift @_;

    my $input = $source ;
    if (! $inputIsFilename)
    {
        $input = \$source 
            if ! ref $source;
    }

    if ( ref $input && ref $input eq 'SCALAR' )
    {
        return $self->syswrite($input, < @_) ;
    }

    if ( ! ref $input  || isaFilehandle($input))
    {
        my $isFilehandle = isaFilehandle($input) ;

        my $fh = $input ;

        if ( ! $isFilehandle )
        {
            $fh = IO::File->new( "$input", "<")
                or return $self->saveErrorString(undef, "cannot open file '$input': $^OS_ERROR", $^OS_ERROR) ;
        }
        binmode $fh if $self->{?Got}->valueOrDefault('BinModeIn') ;

        my $status ;
        my $buff ;
        my $count = 0 ;
        while (($status = read($fh, $buff, 16 * 1024)) +> 0) {
            $count += length $buff;
            defined $self->syswrite($buff, < @_) 
                or return undef ;
        }

        return $self->saveErrorString(undef, $^OS_ERROR, $^OS_ERROR) 
            if $status +< 0 ;

        if ( (!$isFilehandle || $self->{?AutoClose}) && ! ref $input && $input ne '-')
        {    
            $fh->close() 
                or return undef ;
        }

        return $count ;
    }

    croak "Should not be here";
    return undef;
}

sub addInterStream(@< @_)
{
    my $self = shift @_ ;
    my $input = shift @_ ;
    my $inputIsFilename = shift @_ ;

    if ($self->{?Got}->value('MultiStream'))
    {
        $self->getFileInfo($self->{?Got}, $input)
            #if isaFilename($input) and $inputIsFilename ;
            if isaFilename($input) ;

        # TODO -- newStream needs to allow gzip/zip header to be modified
        return $self->newStream();
    }
    elsif ($self->{?Got}->value('AutoFlush'))
    {
    #return $self->flush(Z_FULL_FLUSH);
    }

    return 1 ;
}

sub getFileInfo(...)
{
}

sub TIEHANDLE(@< @_)
{
    return @_[0] if ref(@_[0]);
    die "OOPS\n" ;
}

sub UNTIE(@< @_)
{
    my $self = shift @_ ;
}

sub DESTROY($self)
{
    $self->close() ;

    # TODO - memory leak with 5.8.0 - this isn't called until 
    #        global destruction
    #
     $self->% = %( () ) ;
    undef $self ;
}



sub filterUncompressed(...)
{
}

sub syswrite(@< @_)
{
    my $self = shift @_ ;

    my $buffer ;
    if (ref @_[0] ) {
        $self->croakError( $self->{?ClassName} . "::write: not a scalar reference" )
            unless ref @_[0] eq 'SCALAR' ;
        $buffer = @_[0] ;
    }
    else {
        $buffer = \@_[0] ;
    }


    if ((nelems @_) +> 1) {
        my $slen = defined $buffer->$ ?? length($buffer->$) !! 0;
        my $len = $slen;
        my $offset = 0;
        $len = @_[1] if @_[1] +< $len;

        if ((nelems @_) +> 2) {
            $offset = @_[2] || 0;
            $self->croakError($self->{?ClassName} . "::write: offset outside string") 
                if $offset +> $slen;
            if ($offset +< 0) {
                $offset += $slen;
                $self->croakError( $self->{?ClassName} . "::write: offset outside string") if $offset +< 0;
            }
            my $rem = $slen - $offset;
            $len = $rem if $rem +< $len;
        }

        $buffer = \substr($buffer->$, $offset, $len) ;
    }

    return 0 if ! defined $buffer->$ || length $buffer->$ == 0 ;

    if ($self->{?Encoding}) {
        $buffer->$ = $self->{?Encoding}->encode($buffer->$);
    }

    $self->filterUncompressed($buffer);

    my $buffer_length = defined $buffer->$ ?? length($buffer->$) !! 0 ;
    $self->{?UnCompSize}->add($buffer_length) ;

    my $outBuffer='';
    my $status = $self->{?Compress}->compr($buffer, $outBuffer) ;

    return $self->saveErrorString(undef, $self->{Compress}->{?Error}, 
        $self->{Compress}->{ErrorNo})
        if $status == STATUS_ERROR;

    $self->{?CompSize}->add(length $outBuffer) ;

    $self->output($outBuffer)
        or return undef;

    return $buffer_length;
}

sub print(@< @_)
{
    my $self = shift @_;

    #if (ref $self) {
    #    $self = $self{GLOB} ;
    #}

    if (defined $^OUTPUT_RECORD_SEPARATOR) {
        if (defined $^OUTPUT_FIELD_SEPARATOR) {
            defined $self->syswrite(join($^OUTPUT_FIELD_SEPARATOR, @_) . $^OUTPUT_RECORD_SEPARATOR);
        } else {
            defined $self->syswrite(join("", @_) . $^OUTPUT_RECORD_SEPARATOR);
        }
    } else {
        if (defined $^OUTPUT_FIELD_SEPARATOR) {
            defined $self->syswrite(join($^OUTPUT_FIELD_SEPARATOR, @_));
        } else {
            defined $self->syswrite(join("", @_));
        }
    }
}

sub printf(@< @_)
{
    my $self = shift @_;
    my $fmt = shift @_;
    defined $self->syswrite(sprintf($fmt, < @_));
}



sub flush(@< @_)
{
    my $self = shift @_ ;

    my $outBuffer='';
    my $status = $self->{?Compress}->flush($outBuffer, < @_) ;
    return $self->saveErrorString(0, $self->{Compress}->{?Error}, 
        $self->{Compress}->{ErrorNo})
        if $status == STATUS_ERROR;

    if ( defined $self->{?FH} ) {
        IO::Handle::clearerr($self->{?FH});
    }

    $self->{?CompSize}->add(length $outBuffer) ;

    $self->output($outBuffer)
        or return 0;

    if ( defined $self->{?FH} ) {
        defined IO::Handle::flush($self->{?FH})
            or return $self->saveErrorString(0, $^OS_ERROR, $^OS_ERROR); 
    }

    return 1;
}

sub newStream(@< @_)
{
    my $self = shift @_ ;

    $self->_writeTrailer()
        or return 0 ;

    my $got = $self->checkParams('newStream', $self->{?Got}, < @_)
        or return 0 ;    

    $self->ckParams($got)
        or $self->croakError("newStream: $self->{Error}");

    $self->{+Header} = $self->mkHeader($got) ;
    $self->output($self->{Header} )
        or return 0;

    my $status = $self->reset() ;
    return $self->saveErrorString(0, $self->{Compress}->{?Error}, 
        $self->{Compress}->{ErrorNo})
        if $status == STATUS_ERROR;

    $self->{UnCompSize}->reset();
    $self->{CompSize}->reset();

    return 1 ;
}

sub reset($self)
{
    return $self->{Compress}->reset() ;
}

sub _writeTrailer($self)
{

    my $trailer = '';

    my $status = $self->{?Compress}->close($trailer) ;
    return $self->saveErrorString(0, $self->{Compress}->{?Error}, $self->{Compress}->{ErrorNo})
        if $status == STATUS_ERROR;

    $self->{?CompSize}->add(length $trailer) ;

    $trailer .= $self->mkTrailer();
    defined $trailer
        or return 0;

    return $self->output($trailer);
}

sub _writeFinalTrailer($self)
{

    return $self->output($self->mkFinalTrailer());
}

sub close($self)
{

    return 1 if $self->{?Closed} || ! $self->{?Compress} ;
    $self->{+Closed} = 1 ;

    $self->_writeTrailer()
        or return 0 ;

    $self->_writeFinalTrailer()
        or return 0 ;

    $self->output( "", 1 )
        or return 0;

    if (defined $self->{?FH}) {

        #if (! $self->{Handle} || $self->{AutoClose}) {
        if ((! $self->{?Handle} || $self->{?AutoClose}) && ! $self->{?StdIO}) {
            $^OS_ERROR = 0 ;
            close($self->{?FH})
                or return $self->saveErrorString(0, $^OS_ERROR, $^OS_ERROR); 
        }
        delete $self->{FH} ;
        # This delete can set $! in older Perls, so reset the errno
        $^OS_ERROR = 0 ;
    }

    return 1;
}


#sub total_in
#sub total_out
#sub msg
#
#sub crc
#{
#    my $self = shift ;
#    return $self->{Compress}->crc32() ;
#}
#
#sub msg
#{
#    my $self = shift ;
#    return $self->{Compress}->msg() ;
#}
#
#sub dict_adler
#{
#    my $self = shift ;
#    return $self->{Compress}->dict_adler() ;
#}
#
#sub get_Level
#{
#    my $self = shift ;
#    return $self->{Compress}->get_Level() ;
#}
#
#sub get_Strategy
#{
#    my $self = shift ;
#    return $self->{Compress}->get_Strategy() ;
#}


sub tell($self)
{

    return $self->{UnCompSize}->get32bit() ;
}

sub eof($self)
{

    return $self->{?Closed} ;
}


sub seek(@< @_)
{
    my $self     = shift @_ ;
    my $position = shift @_;
    my $whence   = shift @_ ;

    my $here = $self->tell() ;
    my $target = 0 ;

    #use IO::Handle qw(SEEK_SET SEEK_CUR SEEK_END);
    use IO::Handle ;

    if ($whence == IO::Handle::SEEK_SET) {
        $target = $position ;
    }
    elsif ($whence == IO::Handle::SEEK_CUR || $whence == IO::Handle::SEEK_END) {
        $target = $here + $position ;
    }
    else {
        $self->croakError($self->{?ClassName} . "::seek: unknown value, $whence, for whence parameter");
    }

    # short circuit if seeking to current offset
    return 1 if $target == $here ;    

    # Outlaw any attempt to seek backwards
    $self->croakError($self->{?ClassName} . "::seek: cannot seek backwards")
        if $target +< $here ;

    # Walk the file to the new offset
    my $offset = $target - $here ;

    my $buffer ;
    defined $self->syswrite("\0" x $offset)
        or return 0;

    return 1 ;
}

sub binmode(...)
{
    1;
#    my $self     = shift ;
#    return defined $self->{FH} 
#            ? binmode $self->{FH} 
#            : 1 ;
}

sub fileno($self)
{
    return defined $self->{?FH} 
        ?? fileno($self->{?FH}) 
        !! undef ;
}

sub opened($self)
{
    return ! $self->{?Closed} ;
}

sub autoflush(@< @_)
{
    my $self     = shift @_ ;
    return defined $self->{?FH} 
        ?? $self->{?FH}->autoflush(< @_) 
        !! undef ;
}

sub input_line_number(...)
{
    return undef ;
}


sub _notAvailable(?$name)
{
    return sub { croak "$name Not Available: File opened only for output" ; } ;
}

*read     = _notAvailable('read');
*READ     = _notAvailable('read');
*readline = _notAvailable('readline');
*READLINE = _notAvailable('readline');
*getc     = _notAvailable('getc');
*GETC     = _notAvailable('getc');

*FILENO   = \&fileno;
*PRINT    = \&print;
*PRINTF   = \&printf;
*WRITE    = \&syswrite;
*write    = \&syswrite;
*SEEK     = \&seek; 
*TELL     = \&tell;
*EOF      = \&eof;
*CLOSE    = \&close;
*BINMODE  = \&binmode;

#*sysread  = \&_notAvailable;
#*syswrite = \&_write;

1; 

__END__

=head1 NAME


IO::Compress::Base - Base Class for IO::Compress modules 


=head1 SYNOPSIS

    use IO::Compress::Base ;

=head1 DESCRIPTION


This module is not intended for direct use in application code. Its sole
purpose if to to be sub-classed by IO::Compress modules.




=head1 SEE ALSO

L<Compress::Zlib>, L<IO::Compress::Gzip>, L<IO::Uncompress::Gunzip>, L<IO::Compress::Deflate>, L<IO::Uncompress::Inflate>, L<IO::Compress::RawDeflate>, L<IO::Uncompress::RawInflate>, L<IO::Compress::Bzip2>, L<IO::Uncompress::Bunzip2>, L<IO::Compress::Lzop>, L<IO::Uncompress::UnLzop>, L<IO::Compress::Lzf>, L<IO::Uncompress::UnLzf>, L<IO::Uncompress::AnyInflate>, L<IO::Uncompress::AnyUncompress>

L<Compress::Zlib::FAQ|Compress::Zlib::FAQ>

L<File::GlobMapper|File::GlobMapper>, L<Archive::Zip|Archive::Zip>,
L<Archive::Tar|Archive::Tar>,
L<IO::Zlib|IO::Zlib>





=head1 AUTHOR

This module was written by Paul Marquess, F<pmqs@cpan.org>. 



=head1 MODIFICATION HISTORY

See the Changes file.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2005-2007 Paul Marquess. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


