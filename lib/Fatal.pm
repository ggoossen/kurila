package Fatal;

use strict;
our($Debug, $VERSION);

$VERSION = 1.06;

$Debug = 0 unless defined $Debug;

sub import {
    my $self = shift(@_);
    my($sym, $pkg);
    $pkg = (caller)[[0]];
    foreach $sym (< @_) {
        &_make_fatal($sym, $pkg);
    }
};

sub fill_protos {
  my $proto = shift;
  my $n = -1;
  my ($isref, @out, @out1, $seen_semi);
  while ($proto =~ m/\S/) {
    $n++;
    push(@out1,\@($n,< @out)) if $seen_semi;
    push(@out, $1 . "\{\@_[$n]\}"), next if $proto =~ s/^\s*\\([\@%\$\&])//;
    push(@out, "\@_[$n]"), next if $proto =~ s/^\s*([_*\$&])//;
    push(@out, "\@_[[$n..nelems(\@_)-1]]"), last if $proto =~ s/^\s*(;\s*)?\@//;
    $seen_semi = 1, $n--, next if $proto =~ s/^\s*;//; # XXXX ????
    die "Unknown prototype letters: \"$proto\"";
  }
  push(@out1,\@($n+1,< @out));
  return @out1;
}

sub write_invocation {
  my ($core, $call, $name, < @argvs) = < @_;
  if ((nelems @argvs) == 1) {		# No optional arguments
    my @argv = @( < @{@argvs[0]} );
    shift @argv;
    return "\t" . one_invocation($core, $call, $name, < @argv) . ";\n";
  } else {
    my $else = "\t";
    my (@out, @argv, $n);
    while ((nelems @argvs)) {
      @argv = @( < @{shift @argvs} );
      $n = shift @argv;
      push @out, "{$else}if (nelems(\@_) == $n) \{\n";
      $else = "\t\} els";
      push @out, 
          "\t\treturn " . one_invocation($core, $call, $name, < @argv) . ";\n";
    }
    push @out, <<EOC;
	\}
	die "$name(\@_): Do not expect to get \$(nelems(\@_)) arguments";
EOC
    return join '', < @out;
  }
}

sub one_invocation {
  my ($core, $call, $name, < @argv) = < @_;
  return qq{$call({join ', ', <@argv}) || die "Can't $name(\{join ', ', map \{ dump::view(\$_) \} < \@_\})} . 
    ($core ? ': $!' : ', \$! is \"$!\"') . '"';
}

sub _make_fatal {
    my($sub, $pkg) = < @_;
    my($name, $code, $sref, $real_proto, $proto, $core, $call);
    my $ini = $sub;

    $sub = "{$pkg}::$sub" unless $sub =~ m/::/;
    $name = $sub;
    $name =~ s/.*::// or $name =~ s/^&//;
    print "# _make_fatal: sub=$sub pkg=$pkg name=$name\n" if $Debug;
    die "Bad subroutine name for Fatal: $name" unless $name =~ m/^\w+$/;
    if (defined(&$sub)) {	# user subroutine
	$sref = \&$sub;
	$proto = prototype $sref;
	$call = '&$sref';
    } elsif ($sub eq $ini && $sub !~ m/^CORE::GLOBAL::/) {
	# Stray user subroutine
	die "$sub is not a Perl subroutine" 
    } else {			# CORE subroutine
        $proto = try { prototype "CORE::$name" };
	die "$name is neither a builtin, nor a Perl subroutine" 
	  if $@;
	die "Cannot make the non-overridable builtin $name fatal"
	  if not defined $proto;
	$core = 1;
	$call = "CORE::$name";
    }
    if (defined $proto) {
      $real_proto = " ($proto)";
    } else {
      $real_proto = '';
      $proto = '@';
    }
    $code = <<EOS;
sub$real_proto \{
	local(\$!) = (0);
EOS
    my @protos = @( < fill_protos($proto) );
    $code .= write_invocation($core, $call, $name, < @protos);
    $code .= "\}\n";
    print $code if $Debug;
    {
      $code = eval("package $pkg; $code");
      die if $@;
      no warnings;   # to avoid: Subroutine foo redefined ...
      *{Symbol::fetch_glob($sub)} = $code;
    }
}

1;

__END__

=head1 NAME

Fatal - replace functions with equivalents which succeed or die

=head1 SYNOPSIS

    use Fatal qw(open close);

    sub juggle { . . . }
    import Fatal 'juggle';

=head1 DESCRIPTION

C<Fatal> provides a way to conveniently replace functions which normally
return a false value when they fail with equivalents which raise exceptions
if they are not successful.  This lets you use these functions without
having to test their return values explicitly on each call.  Exceptions
can be caught using C<eval{}>.  See L<perlfunc> and L<perlvar> for details.

The do-or-die equivalents are set up simply by calling Fatal's
C<import> routine, passing it the names of the functions to be
replaced.  You may wrap both user-defined functions and overridable
CORE operators (except C<exec>, C<system> which cannot be expressed
via prototypes) in this way.

=head1 BUGS

You should not fatalize functions that are called in list context, because this
module tests whether a function has failed by testing the boolean truth of its
return value in scalar context.

=head1 AUTHOR

Lionel Cons (CERN).

Prototype updates by Ilya Zakharevich <ilya@math.ohio-state.edu>.

=cut
