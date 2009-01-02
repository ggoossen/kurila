package English;

our $VERSION = '1.04';

require Exporter;
our @ISA = qw(Exporter);

=head1 NAME

English - use nice English (or awk) names for ugly punctuation variables

=head1 SYNOPSIS

    use English qw( -no_match_vars ) ;  # Avoids regex performance penalty
    use English;
    ...
    if ($ERRNO =~ /denied/) { ... }

=head1 DESCRIPTION

This module provides aliases for the built-in variables whose
names no one seems to like to read.  Variables with side-effects
which get triggered just by accessing them (like $0) will still 
be affected.

For those variables that have an B<awk> version, both long
and short English alternatives are provided.  For example, 
the C<$/> variable can be referred to either $RS or 
$INPUT_RECORD_SEPARATOR if you are using the English module.

See L<perlvar> for a complete list of these.

=cut

no warnings;

my $globbed_match ;

our @MINIMAL_EXPORT = qw(
	$EXTENDED_OS_ERROR
	$PROGRAM_NAME
	$PERL_VERSION
	$COMPILING
	$DEBUGGING
	$SYSTEM_FD_MAX
	$INPLACE_EDIT
	$PERLDB
	$BASETIME
	$WARNING
	$EXECUTABLE_NAME
	$OSNAME
	$LAST_REGEXP_CODE_RESULT
	$EXCEPTIONS_BEING_CAUGHT
	$LAST_SUBMATCH_RESULT
);

# Grandfather $NAME import
sub import {
    my $this = shift;
    my @list = grep { ! m/^-no_match_vars$/ } @_ ;
    local $Exporter::ExportLevel = 1;
    *EXPORT = \@MINIMAL_EXPORT ;
    Exporter::import($this,< grep {s/^\$/*/} @list);
}

# Matching.

	*LAST_SUBMATCH_RESULT			= *^N{SCALAR} ;

# Error status.

	*EXTENDED_OS_ERROR			= *^E{SCALAR}	;

# Process info.

	*PROGRAM_NAME				= *0{SCALAR}	;

# Internals.

	*PERL_VERSION				= *^V{SCALAR}	;
	*COMPILING				= *^C{SCALAR}	;
	*DEBUGGING				= *^D{SCALAR}	;
	*SYSTEM_FD_MAX				= *^F{SCALAR}	;
	*INPLACE_EDIT				= *^I{SCALAR}	;
	*PERLDB					= *^P{SCALAR}	;
	*LAST_REGEXP_CODE_RESULT		= *^R{SCALAR}	;
	*EXCEPTIONS_BEING_CAUGHT		= *^S{SCALAR}	;
	*BASETIME				= *^T{SCALAR}	;
	*WARNING				= *^W{SCALAR}	;
	*EXECUTABLE_NAME			= *^X{SCALAR}	;
	*OSNAME					= *^O{SCALAR}	;

1;
