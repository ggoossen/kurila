#!/usr/bin/perl -w

# The following hash values are internally used:
#   _e: exponent (BigInt)
#   _m: mantissa (absolute BigInt)
# sign: +,-,"NaN" if not a number
#   _a: accuracy
#   _p: precision
#   _f: flags, used to signal MBI not to touch our private parts
# _cow: Copy-On-Write (NRY)

package Math::BigFloat;

$VERSION = '1.23';
require 5.005;
use Exporter;
use Math::BigInt qw/objectify/;
@ISA =       qw( Exporter Math::BigInt);
# can not export bneg/babs since the are only in MBI
@EXPORT_OK = qw( 
                bcmp 
                badd bmul bdiv bmod bnorm bsub
		bgcd blcm bround bfround
		bpow bnan bzero bfloor bceil 
		bacmp bstr binc bdec binf
		is_odd is_even is_nan is_inf is_positive is_negative
		is_zero is_one sign
               ); 

#@EXPORT = qw( );
use strict;
use vars qw/$AUTOLOAD $accuracy $precision $div_scale $round_mode/;
my $class = "Math::BigFloat";

use overload
'<=>'	=>	sub { $_[2] ?
                      ref($_[0])->bcmp($_[1],$_[0]) : 
                      ref($_[0])->bcmp($_[0],$_[1])},
'int'	=>	sub { $_[0]->as_number() },		# 'trunc' to bigint
;

##############################################################################
# global constants, flags and accessory

use constant MB_NEVER_ROUND => 0x0001;

# are NaNs ok?
my $NaNOK=1;
# constant for easier life
my $nan = 'NaN'; 

# class constants, use Class->constant_name() to access
$round_mode = 'even'; # one of 'even', 'odd', '+inf', '-inf', 'zero' or 'trunc'
$accuracy   = undef;
$precision  = undef;
$div_scale  = 40;

# in case we call SUPER::->foo() and this wants to call modify()
# sub modify () { 0; }

{
  # valid method aliases for AUTOLOAD
  my %methods = map { $_ => 1 }  
   qw / fadd fsub fmul fdiv fround ffround fsqrt fmod fstr fsstr fpow fnorm
        fneg fint facmp fcmp fzero fnan finf finc fdec
	fceil ffloor
      /;
  # valid method's that need to be hand-ed up (for AUTOLOAD)
  my %hand_ups = map { $_ => 1 }  
   qw / is_nan is_inf is_negative is_positive
        accuracy precision div_scale round_mode fabs babs
      /;

  sub method_alias { return exists $methods{$_[0]||''}; } 
  sub method_hand_up { return exists $hand_ups{$_[0]||''}; } 
}

##############################################################################
# constructors

sub new 
  {
  # create a new BigFloat object from a string or another bigfloat object. 
  # _e: exponent
  # _m: mantissa
  # sign  => sign (+/-), or "NaN"

  my $class = shift;
 
  my $wanted = shift; # avoid numify call by not using || here
  return $class->bzero() if !defined $wanted;      # default to 0
  return $wanted->copy() if ref($wanted) eq $class;

  my $round = shift; $round = 0 if !defined $round; # no rounding as default
  my $self = {}; bless $self, $class;
  # shortcut for bigints and its subclasses
  if ((ref($wanted)) && (ref($wanted) ne $class))
    {
    $self->{_m} = $wanted->as_number();		# get us a bigint copy
    $self->{_e} = Math::BigInt->new(0);
    $self->{_m}->babs();
    $self->{sign} = $wanted->sign();
    return $self->bnorm();
    }
  # got string
  # handle '+inf', '-inf' first
  if ($wanted =~ /^[+-]?inf$/)
    {
    $self->{_e} = Math::BigInt->new(0);
    $self->{_m} = Math::BigInt->new(0);
    $self->{sign} = $wanted;
    $self->{sign} = '+inf' if $self->{sign} eq 'inf';
    return $self->bnorm();
    }
  #print "new string '$wanted'\n";
  my ($mis,$miv,$mfv,$es,$ev) = Math::BigInt::_split(\$wanted);
  if (!ref $mis)
    {
    die "$wanted is not a number initialized to $class" if !$NaNOK;
    $self->{_e} = Math::BigInt->new(0);
    $self->{_m} = Math::BigInt->new(0);
    $self->{sign} = $nan;
    }
  else
    {
    # make integer from mantissa by adjusting exp, then convert to bigint
    $self->{_e} = Math::BigInt->new("$$es$$ev");	# exponent
    $self->{_m} = Math::BigInt->new("$$mis$$miv$$mfv"); # create mantissa
    # 3.123E0 = 3123E-3, and 3.123E-2 => 3123E-5
    $self->{_e} -= CORE::length($$mfv); 		
    $self->{sign} = $self->{_m}->sign(); $self->{_m}->babs();
    }
  #print "$wanted => $self->{sign} $self->{value}\n";
  $self->bnorm();	# first normalize
  # if any of the globals is set, round to them and thus store them insid $self
  $self->round($accuracy,$precision,$class->round_mode)
   if defined $accuracy || defined $precision;
  return $self;
  }

sub bnan
  {
  # create a bigfloat 'NaN', if given a BigFloat, set it to 'NaN'
  my $self = shift;
  $self = $class if !defined $self;
  if (!ref($self))
    {
    my $c = $self; $self = {}; bless $self, $c;
    }
  $self->{_m} = Math::BigInt->bzero();
  $self->{_e} = Math::BigInt->bzero();
  $self->{sign} = $nan;
  return $self;
  }

sub binf
  {
  # create a bigfloat '+-inf', if given a BigFloat, set it to '+-inf'
  my $self = shift;
  my $sign = shift; $sign = '+' if !defined $sign || $sign ne '-';

  $self = $class if !defined $self;
  if (!ref($self))
    {
    my $c = $self; $self = {}; bless $self, $c;
    }
  $self->{_m} = Math::BigInt->bzero();
  $self->{_e} = Math::BigInt->bzero();
  $self->{sign} = $sign.'inf';
  return $self;
  }

sub bone
  {
  # create a bigfloat '+-1', if given a BigFloat, set it to '+-1'
  my $self = shift;
  my $sign = shift; $sign = '+' if !defined $sign || $sign ne '-';

  $self = $class if !defined $self;
  if (!ref($self))
    {
    my $c = $self; $self = {}; bless $self, $c;
    }
  $self->{_m} = Math::BigInt->bone();
  $self->{_e} = Math::BigInt->bzero();
  $self->{sign} = $sign;
  return $self;
  }

sub bzero
  {
  # create a bigfloat '+0', if given a BigFloat, set it to 0
  my $self = shift;
  $self = $class if !defined $self;
  if (!ref($self))
    {
    my $c = $self; $self = {}; bless $self, $c;
    }
  $self->{_m} = Math::BigInt->bzero();
  $self->{_e} = Math::BigInt->bone();
  $self->{sign} = '+';
  return $self;
  }

##############################################################################
# string conversation

sub bstr 
  {
  # (ref to BFLOAT or num_str ) return num_str
  # Convert number from internal format to (non-scientific) string format.
  # internal format is always normalized (no leading zeros, "-0" => "+0")
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);
  #my $x = shift; my $class = ref($x) || $x;
  #$x = $class->new(shift) unless ref($x);

  #die "Oups! e was $nan" if $x->{_e}->{sign} eq $nan;
  #die "Oups! m was $nan" if $x->{_m}->{sign} eq $nan;
  if ($x->{sign} !~ /^[+-]$/)
    {
    return $x->{sign} unless $x->{sign} eq '+inf';      # -inf, NaN
    return 'inf';                                       # +inf
    }
 
  my $es = '0'; my $len = 1; my $cad = 0; my $dot = '.';

  my $not_zero = !$x->is_zero();
  if ($not_zero)
    {
    $es = $x->{_m}->bstr();
    $len = CORE::length($es);
    if (!$x->{_e}->is_zero())
#      {
#      $es = $x->{sign}.$es if $x->{sign} eq '-'; 
#      }
#    else
      {
      if ($x->{_e}->sign() eq '-')
        {
        $dot = '';
        if ($x->{_e} <= -$len)
          {
          # print "style: 0.xxxx\n";
          my $r = $x->{_e}->copy(); $r->babs()->bsub( CORE::length($es) );
          $es = '0.'. ('0' x $r) . $es; $cad = -($len+$r);
          }
        else
          {
          # print "insert '.' at $x->{_e} in '$es'\n";
          substr($es,$x->{_e},0) = '.'; $cad = $x->{_e};
          }
        }
      else
        {
        # expand with zeros
        $es .= '0' x $x->{_e}; $len += $x->{_e}; $cad = 0;
        }
      }
    } # if not zero
  $es = $x->{sign}.$es if $x->{sign} eq '-';
  # if set accuracy or precision, pad with zeros
  if ((defined $x->{_a}) && ($not_zero))
    {
    # 123400 => 6, 0.1234 => 4, 0.001234 => 4
    my $zeros = $x->{_a} - $cad;		# cad == 0 => 12340
    $zeros = $x->{_a} - $len if $cad != $len;
    #print "acc padd $x->{_a} $zeros (len $len cad $cad)\n";
    $es .= $dot.'0' x $zeros if $zeros > 0;
    }
  elsif ($x->{_p} || 0 < 0)
    {
    # 123400 => 6, 0.1234 => 4, 0.001234 => 6
    my $zeros = -$x->{_p} + $cad;
    #print "pre padd $x->{_p} $zeros (len $len cad $cad)\n";
    $es .= $dot.'0' x $zeros if $zeros > 0;
    }
  return $es;
  }

sub bsstr
  {
  # (ref to BFLOAT or num_str ) return num_str
  # Convert number from internal format to scientific string format.
  # internal format is always normalized (no leading zeros, "-0E0" => "+0E0")
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);
  #my $x = shift; my $class = ref($x) || $x;
  #$x = $class->new(shift) unless ref($x);

  #die "Oups! e was $nan" if $x->{_e}->{sign} eq $nan;
  #die "Oups! m was $nan" if $x->{_m}->{sign} eq $nan;
  if ($x->{sign} !~ /^[+-]$/)
    {
    return $x->{sign} unless $x->{sign} eq '+inf';      # -inf, NaN
    return 'inf';                                       # +inf
    }
  my $sign = $x->{_e}->{sign}; $sign = '' if $sign eq '-';
  my $sep = 'e'.$sign;
  return $x->{_m}->bstr().$sep.$x->{_e}->bstr();
  }
    
sub numify 
  {
  # Make a number from a BigFloat object
  # simple return string and let Perl's atoi()/atof() handle the rest
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);
  return $x->bsstr(); 
  }

##############################################################################
# public stuff (usually prefixed with "b")

# really? Just for exporting them is not what I had in mind
#sub babs
#  {
#  $class->SUPER::babs($class,@_);
#  }
#sub bneg
#  {
#  $class->SUPER::bneg($class,@_);
#  }

# tels 2001-08-04 
# todo: this must be overwritten and return NaN for non-integer values
# band(), bior(), bxor(), too
#sub bnot
#  {
#  $class->SUPER::bnot($class,@_);
#  }

sub bcmp 
  {
  # Compares 2 values.  Returns one of undef, <0, =0, >0. (suitable for sort)
  # (BFLOAT or num_str, BFLOAT or num_str) return cond_code
  my ($self,$x,$y) = objectify(2,@_);

  if (($x->{sign} !~ /^[+-]$/) || ($y->{sign} !~ /^[+-]$/))
    {
    # handle +-inf and NaN
    return undef if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));
    return 0 if ($x->{sign} eq $y->{sign}) && ($x->{sign} =~ /^[+-]inf$/);
    return +1 if $x->{sign} eq '+inf';
    return -1 if $x->{sign} eq '-inf';
    return -1 if $y->{sign} eq '+inf';
    return +1 if $y->{sign} eq '-inf';
    }

  # check sign for speed first
  return 1 if $x->{sign} eq '+' && $y->{sign} eq '-';	# does also 0 <=> -y
  return -1 if $x->{sign} eq '-' && $y->{sign} eq '+';	# does also -x <=> 0

  # shortcut 
  my $xz = $x->is_zero();
  my $yz = $y->is_zero();
  return 0 if $xz && $yz;				# 0 <=> 0
  return -1 if $xz && $y->{sign} eq '+';		# 0 <=> +y
  return 1 if $yz && $x->{sign} eq '+';			# +x <=> 0

  # adjust so that exponents are equal
  my $lxm = $x->{_m}->length();
  my $lym = $y->{_m}->length();
  my $lx = $lxm + $x->{_e};
  my $ly = $lym + $y->{_e};
  # print "x $x y $y lx $lx ly $ly\n";
  my $l = $lx - $ly; $l = -$l if $x->{sign} eq '-';
  # print "$l $x->{sign}\n";
  return $l <=> 0 if $l != 0;
  
  # lengths (corrected by exponent) are equal
  # so make mantissa euqal length by padding with zero (shift left)
  my $diff = $lxm - $lym;
  my $xm = $x->{_m};		# not yet copy it
  my $ym = $y->{_m};
  if ($diff > 0)
    {
    $ym = $y->{_m}->copy()->blsft($diff,10);
    }
  elsif ($diff < 0)
    {
    $xm = $x->{_m}->copy()->blsft(-$diff,10);
    }
  my $rc = $xm->bcmp($ym);
  $rc = -$rc if $x->{sign} eq '-';		# -124 < -123
  return $rc <=> 0;
  }

sub bacmp 
  {
  # Compares 2 values, ignoring their signs. 
  # Returns one of undef, <0, =0, >0. (suitable for sort)
  # (BFLOAT or num_str, BFLOAT or num_str) return cond_code
  my ($self,$x,$y) = objectify(2,@_);

  # handle +-inf and NaN's
  if ($x->{sign} !~ /^[+-]$/ || $y->{sign} !~ /^[+-]/)
    {
    return undef if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));
    return 0 if ($x->is_inf() && $y->is_inf());
    return 1 if ($x->is_inf() && !$y->is_inf());
    return -1 if (!$x->is_inf() && $y->is_inf());
    }

  # shortcut 
  my $xz = $x->is_zero();
  my $yz = $y->is_zero();
  return 0 if $xz && $yz;				# 0 <=> 0
  return -1 if $xz && !$yz;				# 0 <=> +y
  return 1 if $yz && !$xz;				# +x <=> 0

  # adjust so that exponents are equal
  my $lxm = $x->{_m}->length();
  my $lym = $y->{_m}->length();
  my $lx = $lxm + $x->{_e};
  my $ly = $lym + $y->{_e};
  # print "x $x y $y lx $lx ly $ly\n";
  my $l = $lx - $ly; # $l = -$l if $x->{sign} eq '-';
  # print "$l $x->{sign}\n";
  return $l <=> 0 if $l != 0;
  
  # lengths (corrected by exponent) are equal
  # so make mantissa euqal length by padding with zero (shift left)
  my $diff = $lxm - $lym;
  my $xm = $x->{_m};		# not yet copy it
  my $ym = $y->{_m};
  if ($diff > 0)
    {
    $ym = $y->{_m}->copy()->blsft($diff,10);
    }
  elsif ($diff < 0)
    {
    $xm = $x->{_m}->copy()->blsft(-$diff,10);
    }
  my $rc = $xm->bcmp($ym);
  # $rc = -$rc if $x->{sign} eq '-';		# -124 < -123
  return $rc <=> 0;

#  # signs are ignored, so check length
#  # length(x) is length(m)+e aka length of non-fraction part
#  # the longer one is bigger
#  my $l = $x->length() - $y->length();
#  #print "$l\n";
#  return $l if $l != 0;
#  #print "equal lengths\n";
#
#  # if both are equal long, make full compare
#  # first compare only the mantissa
#  # if mantissa are equal, compare fractions
#  
#  return $x->{_m} <=> $y->{_m} || $x->{_e} <=> $y->{_e};
  }

sub badd 
  {
  # add second arg (BFLOAT or string) to first (BFLOAT) (modifies first)
  # return result as BFLOAT
  my ($self,$x,$y,$a,$p,$r) = objectify(2,@_);

  # inf and NaN handling
  if (($x->{sign} !~ /^[+-]$/) || ($y->{sign} !~ /^[+-]$/))
    {
    # NaN first
    return $x->bnan() if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));
    # inf handline
    if (($x->{sign} =~ /^[+-]inf$/) && ($y->{sign} =~ /^[+-]inf$/))
      {
      # + and + => +, - and - => -, + and - => 0, - and + => 0
      return $x->bzero() if $x->{sign} ne $y->{sign};
      return $x;
      }
    # +-inf + something => +inf
    # something +-inf => +-inf
    $x->{sign} = $y->{sign}, return $x if $y->{sign} =~ /^[+-]inf$/;
    return $x;
    }

  # speed: no add for 0+y or x+0
  return $x if $y->is_zero();				# x+0
  if ($x->is_zero())					# 0+y
    {
    # make copy, clobbering up x (modify in place!)
    $x->{_e} = $y->{_e}->copy();
    $x->{_m} = $y->{_m}->copy();
    $x->{sign} = $y->{sign} || $nan;
    return $x->round($a,$p,$r,$y);
    }
 
  # take lower of the two e's and adapt m1 to it to match m2
  my $e = $y->{_e}; $e = Math::BigInt::bzero() if !defined $e;	# if no BFLOAT
  $e = $e - $x->{_e};
  my $add = $y->{_m}->copy();
  if ($e < 0)
    {
    # print "e < 0\n";
    #print "\$x->{_m}: $x->{_m} ";
    #print "\$x->{_e}: $x->{_e}\n";
    my $e1 = $e->copy()->babs();
    $x->{_m} *= (10 ** $e1);
    $x->{_e} += $e;			# need the sign of e
    #$x->{_m} += $y->{_m};
    #print "\$x->{_m}: $x->{_m} ";
    #print "\$x->{_e}: $x->{_e}\n";
    }
  elsif ($e > 0)
    {
    # print "e > 0\n";
    #print "\$x->{_m}: $x->{_m} \$y->{_m}: $y->{_m} \$e: $e ",ref($e),"\n";
    $add *= (10 ** $e);
    #$x->{_m} += $y->{_m} * (10 ** $e);
    #print "\$x->{_m}: $x->{_m}\n";
    }
  # else: both e are same, so leave them
  #print "badd $x->{sign}$x->{_m} +  $y->{sign}$add\n";
  # fiddle with signs
  $x->{_m}->{sign} = $x->{sign};
  $add->{sign} = $y->{sign};
  # finally do add/sub
  $x->{_m} += $add;
  # re-adjust signs
  $x->{sign} = $x->{_m}->{sign};
  $x->{_m}->{sign} = '+';
  #$x->bnorm();				# delete trailing zeros
  return $x->round($a,$p,$r,$y);
  }

sub bsub 
  {
  # (BigFloat or num_str, BigFloat or num_str) return BigFloat
  # subtract second arg from first, modify first
  my ($self,$x,$y) = objectify(2,@_);

  $x->badd($y->bneg()); # badd does not leave internal zeros
  $y->bneg();           # refix y, assumes no one reads $y in between
  return $x;  		# badd() already normalized and rounded
  }

sub binc
  {
  # increment arg by one
  my ($self,$x,$a,$p,$r) = ref($_[0]) ? (ref($_[0]),@_) : objectify(1,@_);
  $x->badd($self->bone())->round($a,$p,$r);
  }

sub bdec
  {
  # decrement arg by one
  my ($self,$x,$a,$p,$r) = ref($_[0]) ? (ref($_[0]),@_) : objectify(1,@_);
  $x->badd($self->bone('-'))->round($a,$p,$r);
  } 

sub blcm 
  { 
  # (BFLOAT or num_str, BFLOAT or num_str) return BFLOAT
  # does not modify arguments, but returns new object
  # Lowest Common Multiplicator

  my ($self,@arg) = objectify(0,@_);
  my $x = $self->new(shift @arg);
  while (@arg) { $x = _lcm($x,shift @arg); } 
  $x;
  }

sub bgcd 
  { 
  # (BFLOAT or num_str, BFLOAT or num_str) return BINT
  # does not modify arguments, but returns new object
  # GCD -- Euclids algorithm Knuth Vol 2 pg 296
   
  my ($self,@arg) = objectify(0,@_);
  my $x = $self->new(shift @arg);
  while (@arg) { $x = _gcd($x,shift @arg); } 
  $x;
  }

sub is_zero
  {
  # return true if arg (BFLOAT or num_str) is zero (array '+', '0')
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);

  return 1 if $x->{sign} eq '+' && $x->{_m}->is_zero();
  return 0;
  }

sub is_one
  {
  # return true if arg (BFLOAT or num_str) is +1 (array '+', '1')
  # or -1 if signis given
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);

  my $sign = shift || ''; $sign = '+' if $sign ne '-';
  return 1
   if ($x->{sign} eq $sign && $x->{_e}->is_zero() && $x->{_m}->is_one()); 
  return 0;
  }

sub is_odd
  {
  # return true if arg (BFLOAT or num_str) is odd or false if even
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);
  
  return 0 if $x->{sign} !~ /^[+-]$/;			# NaN & +-inf aren't
  return 1 if ($x->{_e}->is_zero() && $x->{_m}->is_odd()); 
  return 0;
  }

sub is_even
  {
  # return true if arg (BINT or num_str) is even or false if odd
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);

  return 0 if $x->{sign} !~ /^[+-]$/;			# NaN & +-inf aren't
  return 1 if $x->{_m}->is_zero();			# 0e1 is even
  return 1 if ($x->{_e}->is_zero() && $x->{_m}->is_even()); # 123.45 is never
  return 0;
  }

sub bmul 
  { 
  # multiply two numbers -- stolen from Knuth Vol 2 pg 233
  # (BINT or num_str, BINT or num_str) return BINT
  my ($self,$x,$y,$a,$p,$r) = objectify(2,@_);

  # print "mbf bmul $x->{_m}e$x->{_e} $y->{_m}e$y->{_e}\n";
  return $x->bnan() if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));

  # handle result = 0
  return $x->bzero() if $x->is_zero() || $y->is_zero();
  # inf handling
  if (($x->{sign} =~ /^[+-]inf$/) || ($y->{sign} =~ /^[+-]inf$/))
    {
    # result will always be +-inf:
    # +inf * +/+inf => +inf, -inf * -/-inf => +inf
    # +inf * -/-inf => -inf, -inf * +/+inf => -inf
    return $x->binf() if ($x->{sign} =~ /^\+/ && $y->{sign} =~ /^\+/);
    return $x->binf() if ($x->{sign} =~ /^-/ && $y->{sign} =~ /^-/);
    return $x->binf('-');
    }

  # aEb * cEd = (a*c)E(b+d)
  $x->{_m} = $x->{_m} * $y->{_m};
  #print "m: $x->{_m}\n";
  $x->{_e} = $x->{_e} + $y->{_e};
  #print "e: $x->{_m}\n";
  # adjust sign:
  $x->{sign} = $x->{sign} ne $y->{sign} ? '-' : '+';
  #print "s: $x->{sign}\n";
  $x->bnorm();
  return $x->round($a,$p,$r,$y);
  }

sub bdiv 
  {
  # (dividend: BFLOAT or num_str, divisor: BFLOAT or num_str) return 
  # (BFLOAT,BFLOAT) (quo,rem) or BINT (only rem)
  my ($self,$x,$y,$a,$p,$r) = objectify(2,@_);


  # x / +-inf => 0, reminder x
  return wantarray ? ($x->bzero(),$x->copy()) : $x->bzero()
   if $y->{sign} =~ /^[+-]inf$/;

  # NaN if x == NaN or y == NaN or x==y==0
  return wantarray ? ($x->bnan(),bnan()) : $x->bnan()
   if (($x->is_nan() || $y->is_nan()) ||
      ($x->is_zero() && $y->is_zero()));

  # 5 / 0 => +inf, -6 / 0 => -inf
  return wantarray
   ? ($x->binf($x->{sign}),$self->bnan()) : $x->binf($x->{sign})
   if ($x->{sign} =~ /^[+-]$/ && $y->is_zero());

  # promote BigInts and it's subclasses (except when already a BigFloat)
  $y = $self->new($y) unless $y->isa('Math::BigFloat'); 

  # old, broken way
  # $y = $class->new($y) if ref($y) ne $self;		# promote bigints

  # print "mbf bdiv $x ",ref($x)," ",$y," ",ref($y),"\n"; 
  # we need to limit the accuracy to protect against overflow

  my $fallback = 0;
  my $scale = 0;
#  print "s=$scale a=",$a||'undef'," p=",$p||'undef'," r=",$r||'undef',"\n";
  my @params = $x->_find_round_parameters($a,$p,$r,$y);

  # no rounding at all, so must use fallback
  if (scalar @params == 1)
    {
    # simulate old behaviour
    $scale = $self->div_scale()+1; 	# at least one more for proper round
    $params[1] = $self->div_scale();	# and round to it as accuracy
    $params[3] = $r;			# round mode by caller or undef
    $fallback = 1;			# to clear a/p afterwards
    }
  else
    {
    # the 4 below is empirical, and there might be cases where it is not
    # enough...
    $scale = abs($params[1] || $params[2]) + 4;	# take whatever is defined
    }
 # print "s=$scale a=",$params[1]||'undef'," p=",$params[2]||'undef'," f=$fallback\n";
  my $lx = $x->{_m}->length(); my $ly = $y->{_m}->length();
  $scale = $lx if $lx > $scale;
  $scale = $ly if $ly > $scale;
#  print "scale $scale $lx $ly\n";
  my $diff = $ly - $lx;
  $scale += $diff if $diff > 0;		# if lx << ly, but not if ly << lx!

  return wantarray ? ($x,$self->bzero()) : $x if $x->is_zero();

  $x->{sign} = $x->{sign} ne $y->sign() ? '-' : '+'; 

  # check for / +-1 ( +/- 1E0)
  if ($y->is_one())
    {
    return wantarray ? ($x,$self->bzero()) : $x;
    }

  # calculate the result to $scale digits and then round it
  # a * 10 ** b / c * 10 ** d => a/c * 10 ** (b-d)
  #$scale = 82;
  #print "self: $self x: $x ref(x) ", ref($x)," m: $x->{_m}\n";
  $x->{_m}->blsft($scale,10);
  #print "m: $x->{_m} $y->{_m}\n";
  $x->{_m}->bdiv( $y->{_m} );	# a/c
  #print "m: $x->{_m}\n";
  #print "e: $x->{_e} $y->{_e} ",$scale,"\n";
  $x->{_e}->bsub($y->{_e});	# b-d
  #print "e: $x->{_e}\n";
  $x->{_e}->bsub($scale);	# correct for 10**scale
  #print "after div: m: $x->{_m} e: $x->{_e}\n";
  $x->bnorm();			# remove trailing 0's
  #print "after norm: m: $x->{_m} e: $x->{_e}\n";

  # shortcut to not run trough _find_round_parameters again
  if (defined $params[1])
    {
    $x->bround($params[1],undef,$params[3]);	# then round accordingly
    }
  else
    {
    $x->bfround($params[2],$params[3]);		# then round accordingly
    }
  if ($fallback)
    {
    # clear a/p after round, since user did not request it
    $x->{_a} = undef; $x->{_p} = undef;
    }
  
  if (wantarray)
    {
    my $rem = $x->copy();
    $rem->bmod($y,$params[1],$params[2],$params[3]);
    if ($fallback)
      {
      # clear a/p after round, since user did not request it
      $rem->{_a} = undef; $rem->{_p} = undef;
      }
    return ($x,$rem);
    }
  return $x;
  }

sub bmod 
  {
  # (dividend: BFLOAT or num_str, divisor: BFLOAT or num_str) return reminder 
  my ($self,$x,$y,$a,$p,$r) = objectify(2,@_);

  return $x->bnan() if ($x->{sign} eq $nan || $y->is_nan() || $y->is_zero());
  return $x->bzero() if $y->is_one();

  # XXX tels: not done yet
  return $x->round($a,$p,$r,$y);
  }

sub bsqrt
  { 
  # calculate square root; this should probably
  # use a different test to see whether the accuracy we want is...
  my ($self,$x,$a,$p,$r) = ref($_[0]) ? (ref($_[0]),@_) : objectify(1,@_);

  return $x->bnan() if $x->{sign} eq 'NaN' || $x->{sign} =~ /^-/; # <0, NaN
  return $x if $x->{sign} eq '+inf';				  # +inf
  return $x if $x->is_zero() || $x == 1;

  # we need to limit the accuracy to protect against overflow (ignore $p)
  my ($scale) = $x->_scale_a($self->accuracy(),$self->round_mode,$a,$r); 
  my $fallback = 0;
  if (!defined $scale)
    {
    # simulate old behaviour
    $scale = $self->div_scale()+1; 	# one more for proper riund
    $a = $self->div_scale();		# and round to it
    $fallback = 1;			# to clear a/p afterwards
    }
  my $lx = $x->{_m}->length();
  $scale = $lx if $scale < $lx;
  my $e = Math::BigFloat->new("1E-$scale");	# make test variable
  return $x->bnan() if $e->sign() eq 'NaN';

  # start with some reasonable guess
  #$x *= 10 ** ($len - $org->{_e}); $x /= 2;	# !?!?
  $lx = $lx+$x->{_e};
  $lx = 1 if $lx < 1;
  my $gs = Math::BigFloat->new('1'. ('0' x $lx));	
  
#   print "first guess: $gs (x $x) scale $scale\n";
 
  my $diff = $e;
  my $y = $x->copy();
  my $two = Math::BigFloat->new(2);
  # promote BigInts and it's subclasses (except when already a BigFloat)
  $y = $self->new($y) unless $y->isa('Math::BigFloat'); 
  # old, broken way
  # $x = Math::BigFloat->new($x) if ref($x) ne $class;	# promote BigInts
  my $rem;
  # $scale = 2;
  while ($diff >= $e)
    {
    return $x->bnan() if $gs->is_zero();
    $rem = $y->copy(); $rem->bdiv($gs,$scale); 
    #print "y $y gs $gs ($gs->{_a}) rem (y/gs)\n $rem\n";
    $x = ($rem + $gs);
    #print "x $x rem $rem gs $gs gsa: $gs->{_a}\n";
    $x->bdiv($two,$scale);
    #print "x $x (/2)\n";
    $diff = $x->copy()->bsub($gs)->babs();
    $gs = $x->copy();
    }
#  print "before $x $x->{_a} ",$a||'a undef'," ",$p||'p undef',"\n";
  $x->round($a,$p,$r);
#  print "after $x $x->{_a} ",$a||'a undef'," ",$p||'p undef',"\n";
  if ($fallback)
    {
    # clear a/p after round, since user did not request it
    $x->{_a} = undef; $x->{_p} = undef;
    }
  $x;
  }

sub bpow 
  {
  # (BFLOAT or num_str, BFLOAT or num_str) return BFLOAT
  # compute power of two numbers, second arg is used as integer
  # modifies first argument

  my ($self,$x,$y,$a,$p,$r) = objectify(2,@_);

  return $x if $x->{sign} =~ /^[+-]inf$/;
  return $x->bnan() if $x->{sign} eq $nan || $y->{sign} eq $nan;
  return $x->bone() if $y->is_zero();
  return $x         if $x->is_one() || $y->is_one();
  my $y1 = $y->as_number();		# make bigint (trunc)
  if ($x == -1)
    {
    # if $x == -1 and odd/even y => +1/-1  because +-1 ^ (+-1) => +-1
    return $y1->is_odd() ? $x : $x->babs(1);
    }
  return $x if $x->is_zero() && $y->{sign} eq '+'; # 0**y => 0 (if not y <= 0)
  # 0 ** -y => 1 / (0 ** y) => / 0! (1 / 0 => +inf)
  return $x->binf() if $x->is_zero() && $y->{sign} eq '-';

  # calculate $x->{_m} ** $y and $x->{_e} * $y separately (faster)
  $y1->babs();
  $x->{_m}->bpow($y1);
  $x->{_e}->bmul($y1);
  $x->{sign} = $nan if $x->{_m}->{sign} eq $nan || $x->{_e}->{sign} eq $nan;
  $x->bnorm();
  if ($y->{sign} eq '-')
    {
    # modify $x in place!
    my $z = $x->copy(); $x->bzero()->binc();
    return $x->bdiv($z,$a,$p,$r);	# round in one go (might ignore y's A!)
    }
  return $x->round($a,$p,$r,$y);
  }

###############################################################################
# rounding functions

sub bfround
  {
  # precision: round to the $Nth digit left (+$n) or right (-$n) from the '.'
  # $n == 0 means round to integer
  # expects and returns normalized numbers!
  my $x = shift; my $self = ref($x) || $x; $x = $self->new(shift) if !ref($x);

  return $x if $x->modify('bfround');
  
  my ($scale,$mode) = $x->_scale_p($self->precision(),$self->round_mode(),@_);
  return $x if !defined $scale;			# no-op

  # never round a 0, +-inf, NaN
  return $x if $x->{sign} !~ /^[+-]$/ || $x->is_zero();
  # print "MBF bfround $x to scale $scale mode $mode\n";

  # don't round if x already has lower precision
  return $x if (defined $x->{_p} && $x->{_p} < 0 && $scale < $x->{_p});

  $x->{_p} = $scale;			# remember round in any case
  $x->{_a} = undef;			# and clear A
  if ($scale < 0)
    {
    # print "bfround scale $scale e $x->{_e}\n";
    # round right from the '.'
    return $x if $x->{_e} >= 0;			# nothing to round
    $scale = -$scale;				# positive for simplicity
    my $len = $x->{_m}->length();		# length of mantissa
    my $dad = -$x->{_e};			# digits after dot
    my $zad = 0;				# zeros after dot
    $zad = -$len-$x->{_e} if ($x->{_e} < -$len);# for 0.00..00xxx style
    #print "scale $scale dad $dad zad $zad len $len\n";

    # number  bsstr   len zad dad	
    # 0.123   123e-3	3   0 3
    # 0.0123  123e-4	3   1 4
    # 0.001   1e-3      1   2 3
    # 1.23    123e-2	3   0 2
    # 1.2345  12345e-4	5   0 4

    # do not round after/right of the $dad
    return $x if $scale > $dad;			# 0.123, scale >= 3 => exit

    # round to zero if rounding inside the $zad, but not for last zero like:
    # 0.0065, scale -2, round last '0' with following '65' (scale == zad case)
    return $x->bzero() if $scale < $zad;
    if ($scale == $zad)			# for 0.006, scale -3 and trunc
      {
      $scale = -$len-1;
      }
    else
      {
      # adjust round-point to be inside mantissa
      if ($zad != 0)
        {
	$scale = $scale-$zad;
        }
      else
        {
        my $dbd = $len - $dad; $dbd = 0 if $dbd < 0;	# digits before dot
	$scale = $dbd+$scale;
        }
      }
    # print "round to $x->{_m} to $scale\n";
    }
  else
    {
    # 123 => 100 means length(123) = 3 - $scale (2) => 1

    # calculate digits before dot
    my $dbt = $x->{_m}->length(); $dbt += $x->{_e} if $x->{_e}->sign() eq '-';
    # if not enough digits before dot, round to zero
    return $x->bzero() if ($scale > $dbt) && ($dbt < 0);
    # scale always >= 0 here
    if ($dbt == 0)
      {
      # 0.49->bfround(1): scale == 1, dbt == 0: => 0.0
      # 0.51->bfround(0): scale == 0, dbt == 0: => 1.0
      # 0.5->bfround(0):  scale == 0, dbt == 0: => 0
      # 0.05->bfround(0): scale == 0, dbt == 0: => 0
      # print "$scale $dbt $x->{_m}\n";
      $scale = -$x->{_m}->length();
      }
    elsif ($dbt > 0)
      {
      # correct by subtracting scale
      $scale = $dbt - $scale;
      }
    else
      {
      $scale = $x->{_m}->length() - $scale;
      }
    }
  # print "using $scale for $x->{_m} with '$mode'\n";
  # pass sign to bround for rounding modes '+inf' and '-inf'
  $x->{_m}->{sign} = $x->{sign};
  $x->{_m}->bround($scale,$mode);
  $x->{_m}->{sign} = '+';		# fix sign back
  $x->bnorm();
  }

sub bround
  {
  # accuracy: preserve $N digits, and overwrite the rest with 0's
  my $x = shift; my $self = ref($x) || $x; $x = $self->new(shift) if !ref($x);
  
  die ('bround() needs positive accuracy') if ($_[0] || 0) < 0;

  my ($scale,$mode) = $x->_scale_a($self->accuracy(),$self->round_mode(),@_);
  return $x if !defined $scale;				# no-op
  
  return $x if $x->modify('bround');
  
  # scale is now either $x->{_a}, $accuracy, or the user parameter
  # test whether $x already has lower accuracy, do nothing in this case 
  # but do round if the accuracy is the same, since a math operation might
  # want to round a number with A=5 to 5 digits afterwards again
  return $x if defined $_[0] && defined $x->{_a} && $x->{_a} < $_[0];

  # print "bround $scale $mode\n";
  # 0 => return all digits, scale < 0 makes no sense
  return $x if ($scale <= 0);		
  # never round a 0, +-inf, NaN
  return $x if $x->{sign} !~ /^[+-]$/ || $x->is_zero();	

  # if $e longer than $m, we have 0.0000xxxyyy style number, and must
  # subtract the delta from scale, to simulate keeping the zeros
  # -5 +5 => 1; -10 +5 => -4
  my $delta = $x->{_e} + $x->{_m}->length() + 1; 
  
  # if we should keep more digits than the mantissa has, do nothing
  return $x if $x->{_m}->length() <= $scale;

  # pass sign to bround for '+inf' and '-inf' rounding modes
  $x->{_m}->{sign} = $x->{sign};
  $x->{_m}->bround($scale,$mode);	# round mantissa
  $x->{_m}->{sign} = '+';		# fix sign back
  $x->{_a} = $scale;			# remember rounding
  $x->{_p} = undef;			# and clear P
  $x->bnorm();				# del trailing zeros gen. by bround()
  }

sub bfloor
  {
  # return integer less or equal then $x
  my ($self,$x,$a,$p,$r) = ref($_[0]) ? (ref($_[0]),@_) : objectify(1,@_);

  return $x if $x->modify('bfloor');
   
  return $x if $x->{sign} !~ /^[+-]$/;	# nan, +inf, -inf

  # if $x has digits after dot
  if ($x->{_e}->{sign} eq '-')
    {
    $x->{_m}->brsft(-$x->{_e},10);
    $x->{_e}->bzero();
    $x-- if $x->{sign} eq '-';
    }
  return $x->round($a,$p,$r);
  }

sub bceil
  {
  # return integer greater or equal then $x
  my ($self,$x,$a,$p,$r) = ref($_[0]) ? (ref($_[0]),@_) : objectify(1,@_);

  return $x if $x->modify('bceil');
  return $x if $x->{sign} !~ /^[+-]$/;	# nan, +inf, -inf

  # if $x has digits after dot
  if ($x->{_e}->{sign} eq '-')
    {
    $x->{_m}->brsft(-$x->{_e},10);
    $x->{_e}->bzero();
    $x++ if $x->{sign} eq '+';
    }
  return $x->round($a,$p,$r);
  }

###############################################################################

sub DESTROY
  {
  # going through AUTOLOAD for every DESTROY is costly, so avoid it by empty sub
  }

sub AUTOLOAD
  {
  # make fxxx and bxxx work
  # my $self = $_[0];
  my $name = $AUTOLOAD;

  $name =~ s/.*:://;	# split package
  #print "$name\n";
  no strict 'refs';
  if (!method_alias($name))
    {
    if (!defined $name)
      {
      # delayed load of Carp and avoid recursion	
      require Carp;
      Carp::croak ("Can't call a method without name");
      }
    # try one level up, but subst. bxxx() for fxxx() since MBI only got bxxx()
    if (!method_hand_up($name))
      {
      # delayed load of Carp and avoid recursion	
      require Carp;
      Carp::croak ("Can't call $class\-\>$name, not a valid method");
      }
    # try one level up, but subst. bxxx() for fxxx() since MBI only got bxxx()
    $name =~ s/^f/b/;
    return &{'Math::BigInt'."::$name"}(@_);
    }
  my $bname = $name; $bname =~ s/^f/b/;
  *{$class."\:\:$name"} = \&$bname;
  &$bname;	# uses @_
  }

sub exponent
  {
  # return a copy of the exponent
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);

  if ($x->{sign} !~ /^[+-]$/)
    {
    my $s = $x->{sign}; $s =~ s/^[+-]//;
    return $self->new($s);	 		# -inf, +inf => +inf
    }
  return $x->{_e}->copy();
  }

sub mantissa
  {
  # return a copy of the mantissa
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);
 
  if ($x->{sign} !~ /^[+-]$/)
    {
    my $s = $x->{sign}; $s =~ s/^[+]//;
    return $self->new($s); 			# -inf, +inf => +inf
    }
  my $m = $x->{_m}->copy();		# faster than going via bstr()
  $m->bneg() if $x->{sign} eq '-';

  return $m;
  }

sub parts
  {
  # return a copy of both the exponent and the mantissa
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);

  if ($x->{sign} !~ /^[+-]$/)
    {
    my $s = $x->{sign}; $s =~ s/^[+]//; my $se = $s; $se =~ s/^[-]//;
    return ($self->new($s),$self->new($se)); # +inf => inf and -inf,+inf => inf
    }
  my $m = $x->{_m}->copy();	# faster than going via bstr()
  $m->bneg() if $x->{sign} eq '-';
  return ($m,$x->{_e}->copy());
  }

##############################################################################
# private stuff (internal use only)

sub import
  {
  my $self = shift;
  for ( my $i = 0; $i < @_ ; $i++ )
    {
    if ( $_[$i] eq ':constant' )
      {
      # this rest causes overlord er load to step in
      # print "overload @_\n";
      overload::constant float => sub { $self->new(shift); }; 
      splice @_, $i, 1; last;
      }
    }
  # any non :constant stuff is handled by our parent, Exporter
  # even if @_ is empty, to give it a chance
  #$self->SUPER::import(@_);      	# does not work (would call MBI)
  $self->export_to_level(1,$self,@_);	# need this instead
  }

sub bnorm
  {
  # adjust m and e so that m is smallest possible
  # round number according to accuracy and precision settings
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);

  return $x if $x->{sign} !~ /^[+-]$/;		# inf, nan etc

  my $zeros = $x->{_m}->_trailing_zeros();	# correct for trailing zeros 
  if ($zeros != 0)
    {
    $x->{_m}->brsft($zeros,10); $x->{_e} += $zeros;
    }
  # for something like 0Ey, set y to 1, and -0 => +0
  $x->{sign} = '+', $x->{_e}->bone() if $x->{_m}->is_zero();
  # this is to prevent automatically rounding when MBI's globals are set
  $x->{_m}->{_f} = MB_NEVER_ROUND;
  $x->{_e}->{_f} = MB_NEVER_ROUND;
  # 'forget' that mantissa was rounded via MBI::bround() in MBF's bfround()
  $x->{_m}->{_a} = undef; $x->{_e}->{_a} = undef;
  $x->{_m}->{_p} = undef; $x->{_e}->{_p} = undef;
  return $x;					# MBI bnorm is no-op
  }
 
##############################################################################
# internal calculation routines

sub as_number
  {
  # return a bigint representation of this BigFloat number
  my $x = shift; my $class = ref($x) || $x; $x = $class->new(shift) unless ref($x);

  my $z;
  if ($x->{_e}->is_zero())
    {
    $z = $x->{_m}->copy();
    $z->{sign} = $x->{sign};
    return $z;
    }
  $z = $x->{_m}->copy();
  if ($x->{_e} < 0)
    {
    $z->brsft(-$x->{_e},10);
    } 
  else
    {
    $z->blsft($x->{_e},10);
    }
  $z->{sign} = $x->{sign};
  return $z;
  }

sub length
  {
  my $x = shift;
  my $class = ref($x) || $x;
  $x = $class->new(shift) unless ref($x);

  return 1 if $x->{_m}->is_zero();
  my $len = $x->{_m}->length();
  $len += $x->{_e} if $x->{_e}->sign() eq '+';
  if (wantarray())
    {
    my $t = Math::BigInt::bzero();
    $t = $x->{_e}->copy()->babs() if $x->{_e}->sign() eq '-';
    return ($len,$t);
    }
  return $len;
  }

1;
__END__

=head1 NAME

Math::BigFloat - Arbitrary size floating point math package

=head1 SYNOPSIS

  use Math::BigFloat;

  # Number creation	
  $x = Math::BigInt->new($str);	# defaults to 0
  $nan  = Math::BigInt->bnan(); # create a NotANumber
  $zero = Math::BigInt->bzero();# create a "+0"

  # Testing
  $x->is_zero();		# return whether arg is zero or not
  $x->is_nan();			# return whether arg is NaN or not
  $x->is_one();			# true if arg is +1
  $x->is_one('-');		# true if arg is -1
  $x->is_odd();			# true if odd, false for even
  $x->is_even();		# true if even, false for odd
  $x->is_positive();		# true if >= 0
  $x->is_negative();		# true if <  0
  $x->is_inf(sign)		# true if +inf or -inf (sign default '+')
  $x->bcmp($y);			# compare numbers (undef,<0,=0,>0)
  $x->bacmp($y);		# compare absolutely (undef,<0,=0,>0)
  $x->sign();			# return the sign, either +,- or NaN

  # The following all modify their first argument:

  # set 
  $x->bzero();			# set $i to 0
  $x->bnan();			# set $i to NaN

  $x->bneg();			# negation
  $x->babs();			# absolute value
  $x->bnorm();			# normalize (no-op)
  $x->bnot();			# two's complement (bit wise not)
  $x->binc();			# increment x by 1
  $x->bdec();			# decrement x by 1
  
  $x->badd($y);			# addition (add $y to $x)
  $x->bsub($y);			# subtraction (subtract $y from $x)
  $x->bmul($y);			# multiplication (multiply $x by $y)
  $x->bdiv($y);			# divide, set $i to quotient
				# return (quo,rem) or quo if scalar

  $x->bmod($y);			# modulus
  $x->bpow($y);			# power of arguments (a**b)
  $x->blsft($y);		# left shift
  $x->brsft($y);		# right shift 
				# return (quo,rem) or quo if scalar
  
  $x->band($y);			# bit-wise and
  $x->bior($y);			# bit-wise inclusive or
  $x->bxor($y);			# bit-wise exclusive or
  $x->bnot();			# bit-wise not (two's complement)
  
  $x->bround($N); 		# accuracy: preserver $N digits
  $x->bfround($N);		# precision: round to the $Nth digit

  # The following do not modify their arguments:

  bgcd(@values);		# greatest common divisor
  blcm(@values);		# lowest common multiplicator
  
  $x->bstr();			# return string
  $x->bsstr();			# return string in scientific notation
  
  $x->exponent();		# return exponent as BigInt
  $x->mantissa();		# return mantissa as BigInt
  $x->parts();			# return (mantissa,exponent) as BigInt

  $x->length();			# number of digits (w/o sign and '.')
  ($l,$f) = $x->length();	# number of digits, and length of fraction	

=head1 DESCRIPTION

All operators (inlcuding basic math operations) are overloaded if you
declare your big floating point numbers as

  $i = new Math::BigFloat '12_3.456_789_123_456_789E-2';

Operations with overloaded operators preserve the arguments, which is
exactly what you expect.

=head2 Canonical notation

Input to these routines are either BigFloat objects, or strings of the
following four forms:

=over 2

=item *

C</^[+-]\d+$/>

=item *

C</^[+-]\d+\.\d*$/>

=item *

C</^[+-]\d+E[+-]?\d+$/>

=item *

C</^[+-]\d*\.\d+E[+-]?\d+$/>

=back

all with optional leading and trailing zeros and/or spaces. Additonally,
numbers are allowed to have an underscore between any two digits.

Empty strings as well as other illegal numbers results in 'NaN'.

bnorm() on a BigFloat object is now effectively a no-op, since the numbers 
are always stored in normalized form. On a string, it creates a BigFloat 
object.

=head2 Output

Output values are BigFloat objects (normalized), except for bstr() and bsstr().

The string output will always have leading and trailing zeros stripped and drop
a plus sign. C<bstr()> will give you always the form with a decimal point,
while C<bsstr()> (for scientific) gives you the scientific notation.

	Input			bstr()		bsstr()
	'-0'			'0'		'0E1'
   	'  -123 123 123'	'-123123123'	'-123123123E0'
	'00.0123'		'0.0123'	'123E-4'
	'123.45E-2'		'1.2345'	'12345E-4'
	'10E+3'			'10000'		'1E4'

Some routines (C<is_odd()>, C<is_even()>, C<is_zero()>, C<is_one()>,
C<is_nan()>) return true or false, while others (C<bcmp()>, C<bacmp()>)
return either undef, <0, 0 or >0 and are suited for sort.

Actual math is done by using BigInts to represent the mantissa and exponent.
The sign C</^[+-]$/> is stored separately. The string 'NaN' is used to 
represent the result when input arguments are not numbers, as well as 
the result of dividing by zero.

=head2 C<mantissa()>, C<exponent()> and C<parts()>

C<mantissa()> and C<exponent()> return the said parts of the BigFloat 
as BigInts such that:

	$m = $x->mantissa();
	$e = $x->exponent();
	$y = $m * ( 10 ** $e );
	print "ok\n" if $x == $y;

C<< ($m,$e) = $x->parts(); >> is just a shortcut giving you both of them.

A zero is represented and returned as C<0E1>, B<not> C<0E0> (after Knuth).

Currently the mantissa is reduced as much as possible, favouring higher
exponents over lower ones (e.g. returning 1e7 instead of 10e6 or 10000000e0).
This might change in the future, so do not depend on it.

=head2 Accuracy vs. Precision

See also: L<Rounding|Rounding>.

Math::BigFloat supports both precision and accuracy. (here should follow
a short description of both).

Precision: digits after the '.', laber, schwad
Accuracy: Significant digits blah blah

Since things like sqrt(2) or 1/3 must presented with a limited precision lest
a operation consumes all resources, each operation produces no more than
C<Math::BigFloat::precision()> digits.

In case the result of one operation has more precision than specified,
it is rounded. The rounding mode taken is either the default mode, or the one
supplied to the operation after the I<scale>:

	$x = Math::BigFloat->new(2);
	Math::BigFloat::precision(5);		# 5 digits max
	$y = $x->copy()->bdiv(3);		# will give 0.66666
	$y = $x->copy()->bdiv(3,6);		# will give 0.666666
	$y = $x->copy()->bdiv(3,6,'odd');	# will give 0.666667
	Math::BigFloat::round_mode('zero');
	$y = $x->copy()->bdiv(3,6);		# will give 0.666666

=head2 Rounding

=over 2

=item ffround ( +$scale )

Rounds to the $scale'th place left from the '.', counting from the dot.
The first digit is numbered 1. 

=item ffround ( -$scale )

Rounds to the $scale'th place right from the '.', counting from the dot.

=item ffround ( 0 )

Rounds to an integer.

=item fround  ( +$scale )

Preserves accuracy to $scale digits from the left (aka significant digits)
and pads the rest with zeros. If the number is between 1 and -1, the
significant digits count from the first non-zero after the '.'

=item fround  ( -$scale ) and fround ( 0 )

These are effetively no-ops.

=back

All rounding functions take as a second parameter a rounding mode from one of
the following: 'even', 'odd', '+inf', '-inf', 'zero' or 'trunc'.

The default rounding mode is 'even'. By using
C<< Math::BigFloat::round_mode($round_mode); >> you can get and set the default
mode for subsequent rounding. The usage of C<$Math::BigFloat::$round_mode> is
no longer supported.
The second parameter to the round functions then overrides the default
temporarily. 

The C<< as_number() >> function returns a BigInt from a Math::BigFloat. It uses
'trunc' as rounding mode to make it equivalent to:

	$x = 2.5;
	$y = int($x) + 2;

You can override this by passing the desired rounding mode as parameter to
C<as_number()>:

	$x = Math::BigFloat->new(2.5);
	$y = $x->as_number('odd');	# $y = 3

=head1 EXAMPLES
 
  # not ready yet

=head1 Autocreating constants

After C<use Math::BigFloat ':constant'> all the floating point constants
in the given scope are converted to C<Math::BigFloat>. This conversion
happens at compile time.

In particular

  perl -MMath::BigFloat=:constant -e 'print 2E-100,"\n"'

prints the value of C<2E-100>.  Note that without conversion of 
constants the expression 2E-100 will be calculated as normal floating point 
number.

=head1 BUGS

=over 2

=item *

The following does not work yet:

	$m = $x->mantissa();
	$e = $x->exponent();
	$y = $m * ( 10 ** $e );
	print "ok\n" if $x == $y;

=item *

There is no fmod() function yet.

=back

=head1 CAVEAT

=over 1

=item stringify, bstr()

Both stringify and bstr() now drop the leading '+'. The old code would return
'+1.23', the new returns '1.23'. See the documentation in L<Math::BigInt> for
reasoning and details.

=item bdiv

The following will probably not do what you expect:

	print $c->bdiv(123.456),"\n";

It prints both quotient and reminder since print works in list context. Also,
bdiv() will modify $c, so be carefull. You probably want to use
	
	print $c / 123.456,"\n";
	print scalar $c->bdiv(123.456),"\n";  # or if you want to modify $c

instead.

=item Modifying and =

Beware of:

	$x = Math::BigFloat->new(5);
	$y = $x;

It will not do what you think, e.g. making a copy of $x. Instead it just makes
a second reference to the B<same> object and stores it in $y. Thus anything
that modifies $x will modify $y, and vice versa.

	$x->bmul(2);
	print "$x, $y\n";	# prints '10, 10'

If you want a true copy of $x, use:
	
	$y = $x->copy();

See also the documentation in L<overload> regarding C<=>.

=item bpow

C<bpow()> now modifies the first argument, unlike the old code which left
it alone and only returned the result. This is to be consistent with
C<badd()> etc. The first will modify $x, the second one won't:

	print bpow($x,$i),"\n"; 	# modify $x
	print $x->bpow($i),"\n"; 	# ditto
	print $x ** $i,"\n";		# leave $x alone 

=back

=head1 LICENSE

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHORS

Mark Biggar, overloaded interface by Ilya Zakharevich.
Completely rewritten by Tels http://bloodgate.com in 2001.

=cut
