package English;

our $VERSION = '1.04';

require Exporter;
our @ISA = @( qw(Exporter) );

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

our @MINIMAL_EXPORT = @( qw(
	$LAST_PAREN_MATCH
	$INPUT_RECORD_SEPARATOR
	$RS
	$OUTPUT_AUTOFLUSH
	$OUTPUT_FIELD_SEPARATOR
	$OFS
	$OUTPUT_RECORD_SEPARATOR
	$ORS
	$LIST_SEPARATOR
	$SUBSCRIPT_SEPARATOR
	$SUBSEP
	$CHILD_ERROR
	$OS_ERROR
	%OS_ERROR_FLAGS
	$ERRNO
	%ERRNO_FLAGS
	$EXTENDED_OS_ERROR
	$PROCESS_ID
	$PID
	$REAL_USER_ID
	$UID
	$EFFECTIVE_USER_ID
	$EUID
	$REAL_GROUP_ID
	$GID
	$EFFECTIVE_GROUP_ID
	$EGID
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
	@LAST_MATCH_START
	@LAST_MATCH_END
) );

# Grandfather $NAME import
sub import {
    my $this = shift;
    my @list = @( grep { ! m/^-no_match_vars$/ } < @_ ) ;
    local $Exporter::ExportLevel = 1;
    *EXPORT = \@MINIMAL_EXPORT ;
    Exporter::import($this,grep {s/^\$/*/} < @list);
}

# Matching.

	*LAST_PAREN_MATCH			= *+{SCALAR}	;
	*LAST_SUBMATCH_RESULT			= *^N{SCALAR} ;
	*LAST_MATCH_START			= *-{ARRAY} ;
	*LAST_MATCH_END				= *+{ARRAY} ;

# Input.

	*INPUT_RECORD_SEPARATOR			= */{SCALAR}	;
	    *RS					= */{SCALAR}	;

# Output.

	*OUTPUT_AUTOFLUSH			= *|{SCALAR}	;
	*OUTPUT_FIELD_SEPARATOR			= *,{SCALAR}	;
	    *OFS				= *,{SCALAR}	;
	*OUTPUT_RECORD_SEPARATOR		= *\{SCALAR}	;
	    *ORS				= *\{SCALAR}	;

# Interpolation "constants".

	*LIST_SEPARATOR				= *"{SCALAR}	;
	*SUBSCRIPT_SEPARATOR			= *;{SCALAR}	;
	    *SUBSEP				= *;{SCALAR}	;

# Error status.

	*CHILD_ERROR				= *?{SCALAR}	;
	*OS_ERROR				= *!{SCALAR}	;
	    *ERRNO				= *!{SCALAR}	;
	*OS_ERROR_FLAGS				= *!{HASH}	;
	    *ERRNO_FLAGS				= *!{HASH}	;
	*EXTENDED_OS_ERROR			= *^E{SCALAR}	;

# Process info.

	*PROCESS_ID				= *{\(*$)}{SCALAR}	;
	    *PID				= *{\(*$)}{SCALAR}	;
	*REAL_USER_ID				= *<{SCALAR}	;
	    *UID				= *<{SCALAR}	;
	*EFFECTIVE_USER_ID			= *>{SCALAR}	;
	    *EUID				= *>{SCALAR}	;
	*REAL_GROUP_ID				= *^GID{SCALAR}	;
	*EFFECTIVE_GROUP_ID			= *^EGID{SCALAR}	;
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
