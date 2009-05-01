package ExtUtils::Constant::XS;

our ($VERSION, %XS_Constant, %XS_TypeSet, @ISA, @EXPORT_OK);
use ExtUtils::Constant::Utils 'perl_stringify';
require ExtUtils::Constant::Base;


@ISA = qw(ExtUtils::Constant::Base Exporter);
@EXPORT_OK = qw(%XS_Constant %XS_TypeSet);

$VERSION = '0.02';

=head1 NAME

ExtUtils::Constant::Base - base class for ExtUtils::Constant objects

=head1 SYNOPSIS

    require ExtUtils::Constant::XS;

=head1 DESCRIPTION

ExtUtils::Constant::XS overrides ExtUtils::Constant::Base to generate C
code for XS modules' constants.

=head1 BUGS

Nothing is documented.

Probably others.

=head1 AUTHOR

Nicholas Clark <nick@ccl4.org> based on the code in C<h2xs> by Larry Wall and
others

=cut

# '' is used as a flag to indicate non-ascii macro names, and hence the need
# to pass in the utf8 on/off flag.
%XS_Constant = %(
        ''    => '',
            IV    => 'PUSHi(iv)',
            UV    => 'PUSHu((UV)iv)',
            NV    => 'PUSHn(nv)',
            PV    => 'PUSHp(pv, strlen(pv))',
            PVN   => 'PUSHp(pv, iv)',
            SV    => 'PUSHs(sv)',
            YES   => 'PUSHs(&PL_sv_yes)',
            NO    => 'PUSHs(&PL_sv_no)',
            UNDEF => '',	# implicit undef
    );

%XS_TypeSet = %(
        IV    => '*iv_return = ',
            UV    => '*iv_return = (IV)',
            NV    => '*nv_return = ',
            PV    => '*pv_return = ',
            PVN   => \@('*pv_return = ', '*iv_return = (IV)'),
            SV    => '*sv_return = ',
            YES   => undef,
            NO    => undef,
            UNDEF => undef,
    );

sub header(...) {
    my $start = 1;
    my @lines;
    push @lines, "#define PERL_constant_NOTFOUND\t$start\n"; $start++;
    push @lines, "#define PERL_constant_NOTDEF\t$start\n"; $start++;
    foreach (sort keys %XS_Constant) {
        next if $_ eq '';
        push @lines, "#define PERL_constant_IS$_\t$start\n"; $start++;
    }

    return join '', @lines;
}

sub valid_type($self, $type) {
    return exists %XS_TypeSet{$type};
}

# This might actually be a return statement
sub assignment_clause_for_type(@< @_) {
    my $self = shift @_;
    my $args = shift @_;
    my $type = $args->{?type};
    my $typeset = %XS_TypeSet{?$type};
    if (ref $typeset) {
        die "Type $type is aggregate, but only single value given"
            if (nelems @_) == 1;
        return map {"$typeset->[$_]@_[$_];"}, 0 .. ((nelems $typeset->@)-1);
    } elsif (defined $typeset) {
        die "Aggregate value given for type $type"
            if (nelems @_) +> 1;
        return "$typeset@_[0];";
    }
    return ();
}

sub return_statement_for_type($self, $type) {
    # In the future may pass in an options hash
    $type = $type->{?type} if ref $type;
    "return PERL_constant_IS$type;";
}

sub return_statement_for_notdef(...) {
    # my ($self) = @_;
    "return PERL_constant_NOTDEF;";
}

sub return_statement_for_notfound(...) {
    # my ($self) = @_;
    "return PERL_constant_NOTFOUND;";
}

sub default_type(...) {
    'IV';
}

sub macro_from_name($self, $item) {
    my $macro = $item->{?name};
    $macro = $item->{?value} unless defined $macro;
    $macro;
}

sub macro_from_item($self, $item) {
    my $macro = $item->{?macro};
    $macro = $self->macro_from_name($item) unless defined $macro;
    $macro;
}

# Keep to the traditional perl source macro
sub memEQ(...) {
    "memEQ";
}

sub params($self, $what) {
    foreach (sort keys $what->%) {
        warn "ExtUtils::Constant doesn't know how to handle values of type $_" unless defined %XS_Constant{?$_};
    }
    my $params = \%();
    $params->{+''} = 1 if $what->{?''};
    $params->{+IV} = 1 if $what->{?IV} || $what->{?UV} || $what->{?PVN};
    $params->{+NV} = 1 if $what->{?NV};
    $params->{+PV} = 1 if $what->{?PV} || $what->{?PVN};
    $params->{+SV} = 1 if $what->{?SV};
    return $params;
}


sub C_constant_prefix_param(...) {
    "aTHX_ ";
}

sub C_constant_prefix_param_defintion(...) {
    "pTHX_ ";
}

sub namelen_param_definition(@< @_) {
    'STRLEN ' . @_[0] -> namelen_param;
}

sub C_constant_other_params_defintion($self, $params) {
    my $body = '';
    $body .= ", IV *iv_return" if $params->{?IV};
    $body .= ", NV *nv_return" if $params->{?NV};
    $body .= ", const char **pv_return" if $params->{?PV};
    $body .= ", SV **sv_return" if $params->{?SV};
    $body;
}

sub C_constant_other_params($self, $params) {
    my $body = '';
    $body .= ", iv_return" if $params->{?IV};
    $body .= ", nv_return" if $params->{?NV};
    $body .= ", pv_return" if $params->{?PV};
    $body .= ", sv_return" if $params->{?SV};
    $body;
}

sub dogfood($self, $args, @< @items) {
    my @($package, $subname, $default_type, $what, $indent, $breakout) = 
            $args->{[qw(package subname default_type what indent breakout)]};
    my $result = <<"EOT";
  /* When generated this function returned values for the list of names given
     in this section of perl code.  Rather than manually editing these functions
     to add or remove constants, which would result in this comment and section
     of code becoming inaccurate, we recommend that you edit this section of
     code, and use it to regenerate a new set of constant functions which you
     then use to replace the originals.

     Regenerate these constant functions by feeding this entire source file to
     perl -x

#!$^EXECUTABLE_NAME -w
use ExtUtils::Constant qw (constant_types C_constant XS_constant);

EOT
    $result .= $self->dump_names (\%(default_type=>$default_type, what=>$what,
            indent=>0, declare_types=>1),
        < @items);
    $result .= <<'EOT';

print constant_types(), "\n"; # macro defs
EOT
    $package = perl_stringify($package);
    $result .=
        "foreach (C_constant (\"$package\", '$subname', '$default_type', \$types, ";
    # The form of the indent parameter isn't defined. (Yet)
    if (defined $indent) {
        require Data::Dumper;
        $Data::Dumper::Terse=1;
        $Data::Dumper::Terse=1; # Not used once. :-)
        chomp ($indent = Data::Dumper::Dumper ($indent));
        $result .= $indent;
    } else {
        $result .= 'undef';
    }
    $result .= ", $breakout" . ', @names) ) {
    print $_, "\n"; # C constant subs
}
print "\n#### XS Section:\n";
print XS_constant ("' . $package . '", $types);
__END__
   */

';

    $result;
}

1;
