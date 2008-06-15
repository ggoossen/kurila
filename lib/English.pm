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
	*ARG
	*LAST_PAREN_MATCH
	*INPUT_LINE_NUMBER
	*NR
	*INPUT_RECORD_SEPARATOR
	*RS
	*OUTPUT_AUTOFLUSH
	*OUTPUT_FIELD_SEPARATOR
	*OFS
	*OUTPUT_RECORD_SEPARATOR
	*ORS
	*LIST_SEPARATOR
	*SUBSCRIPT_SEPARATOR
	*SUBSEP
	*CHILD_ERROR
	*OS_ERROR
	*ERRNO
	*EXTENDED_OS_ERROR
	*EVAL_ERROR
	*PROCESS_ID
	*PID
	*REAL_USER_ID
	*UID
	*EFFECTIVE_USER_ID
	*EUID
	*REAL_GROUP_ID
	*GID
	*EFFECTIVE_GROUP_ID
	*EGID
	*PROGRAM_NAME
	*PERL_VERSION
	*COMPILING
	*DEBUGGING
	*SYSTEM_FD_MAX
	*INPLACE_EDIT
	*PERLDB
	*BASETIME
	*WARNING
	*EXECUTABLE_NAME
	*OSNAME
	*LAST_REGEXP_CODE_RESULT
	*EXCEPTIONS_BEING_CAUGHT
	*LAST_SUBMATCH_RESULT
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

# The ground of all being. @ARG is deprecated (5.005 makes @_ lexical)

	*ARG					= *_	;

# Matching.

	*LAST_PAREN_MATCH			= *+	;
	*LAST_SUBMATCH_RESULT			= *^N ;
	*LAST_MATCH_START			= *-{ARRAY} ;
	*LAST_MATCH_END				= *+{ARRAY} ;

# Input.

	*INPUT_LINE_NUMBER			= *.	;
	    *NR					= *.	;
	*INPUT_RECORD_SEPARATOR			= */	;
	    *RS					= */	;

# Output.

	*OUTPUT_AUTOFLUSH			= *|	;
	*OUTPUT_FIELD_SEPARATOR			= *,	;
	    *OFS				= *,	;
	*OUTPUT_RECORD_SEPARATOR		= *\	;
	    *ORS				= *\	;

# Interpolation "constants".

	*LIST_SEPARATOR				= *"	;
	*SUBSCRIPT_SEPARATOR			= *;	;
	    *SUBSEP				= *;	;

# Error status.

	*CHILD_ERROR				= *?	;
	*OS_ERROR				= *!	;
	    *ERRNO				= *!	;
	*OS_ERROR				= *!	;
	    *ERRNO				= *!	;
	*EXTENDED_OS_ERROR			= *^E	;
	*EVAL_ERROR				= *@	;

# Process info.

	*PROCESS_ID				= *$	;
	    *PID				= *$	;
	*REAL_USER_ID				= *<	;
	    *UID				= *<	;
	*EFFECTIVE_USER_ID			= *>	;
	    *EUID				= *>	;
	*REAL_GROUP_ID				= *^GID	;
	*EFFECTIVE_GROUP_ID			= *^EGID	;
	*PROGRAM_NAME				= *0	;

# Internals.

	*PERL_VERSION				= *^V	;
	*COMPILING				= *^C	;
	*DEBUGGING				= *^D	;
	*SYSTEM_FD_MAX				= *^F	;
	*INPLACE_EDIT				= *^I	;
	*PERLDB					= *^P	;
	*LAST_REGEXP_CODE_RESULT		= *^R	;
	*EXCEPTIONS_BEING_CAUGHT		= *^S	;
	*BASETIME				= *^T	;
	*WARNING				= *^W	;
	*EXECUTABLE_NAME			= *^X	;
	*OSNAME					= *^O	;

# Deprecated.

#	*ARRAY_BASE				= *[	;
#	*OFMT					= *#	;
#	*OLD_PERL_VERSION			= *]	;

1;
