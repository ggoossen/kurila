package Encode::ucs_2le;
use strict;
our $VERSION = do { my @r = (q$Revision: 1.0 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

use base 'Encode::Encoding';

__PACKAGE__->Define(qw(UTF-16LE UCS-2LE ucs2-le));

sub decode
{
 my ($obj,$str,$chk) = @_;
 my $uni   = '';
 while (length($str))
 {
  my $code = unpack('v',substr($str,0,2,'')) & 0xffff;
  $uni .= chr($code);
 }
 $_[1] = $str if $chk;
 utf8::upgrade($uni);
 return $uni;
}

sub encode
{
 my ($obj,$uni,$chk) = @_;
 my $str   = '';
 while (length($uni))
 {
  my $ch = substr($uni,0,1,'');
  my $x  = ord($ch);
  unless ($x < 32768)
  {
   last if ($chk);
   $x = 0;
  }
  $str .= pack('v',$x);
 }
 $_[1] = $uni if $chk;
 return $str;
}
1;
__END__

=head1 NAME

Encode::ucs2_le -- for internal use only

=cut
