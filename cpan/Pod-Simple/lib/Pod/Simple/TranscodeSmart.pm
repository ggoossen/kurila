
## Anything before 5.8.0 is GIMPY!
## This module is to be use()'d only by Pod::Simple::Transcode

package Pod::Simple::TranscodeSmart

use Pod::Simple
require Encode

sub is_dumb  {0}
sub is_smart {1}

sub all_encodings
    return Encode->encodings: ':all'


sub encoding_is_available
    return Encode::resolve_alias: @_[1]


sub encmodver
    return "Encode.pm v" .($Encode::VERSION || '?')


sub make_transcoder
    my $e = @_[1]
    die: "WHAT ENCODING!?!?" unless $e
    return sub (@< @_)
        foreach my $x ( @_)
            $x = Encode::decode: $e, $x
        
        return
    



1


