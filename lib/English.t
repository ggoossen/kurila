#!./perl -i.inplace
# note the extra switch, for the test below

use Test::More tests => 34;

use English < qw( -no_match_vars ) ;
use Config;
use Errno;

is( $PID, $$, '$PID' );

"abc" =~ m/b/;

{
our ($PREMATCH, $MATCH, $POSTMATCH);

ok( !$PREMATCH, '$PREMATCH undefined' );
ok( !$MATCH, '$MATCH undefined' );
ok( !$POSTMATCH, '$POSTMATCH undefined' );
}

$OFS = " ";
$ORS = "\n";

{
	local(*IN, *OUT);
	if ($^O ne 'dos') {
	    pipe(IN, 'OUT');
	} else {
	    open(OUT, ">", "en.tmp");
	}
	select(OUT);
	$| = 1;
	print 'ok', '7';

	# since $| is 1, this should be true
	ok( $OUTPUT_AUTOFLUSH, '$OUTPUT_AUTOFLUSH should be true' );

	my $close = close OUT;
	ok( !($close) == $CHILD_ERROR, '$CHILD_ERROR should be false' );

	open(IN, "<", "en.tmp") if ($^O eq 'dos');
	my $foo = ~< *IN;
	like( $foo, qr/ok 7/, '$OFS' );

	# chomp is true because $ORS is "\n"
	ok( chomp($foo), '$ORS should be \n' );
}

undef $OUTPUT_FIELD_SEPARATOR;

our $threads;
if ($threads) { $" = "\n" } else { $LIST_SEPARATOR = "\n" };
my @foo = @(8, 9);
@foo = split(m/\n/, join $", @foo );
is( @foo[0], 8, '$"' );
is( @foo[1], 9, '$LIST_SEPARATOR' );

undef $OUTPUT_RECORD_SEPARATOR;

is( $UID, $<, '$UID' );
is( $REAL_GROUP_ID, $^GID, '$GID' );
is( $EUID, $>, '$EUID' );
is( $EFFECTIVE_GROUP_ID, $^EGID, '$EGID' );

is( $PROGRAM_NAME, $0, '$PROGRAM_NAME' );
is( $BASETIME, $^T, '$BASETIME' );

is( $PERL_VERSION, $^V, '$PERL_VERSION' );
is( $DEBUGGING, $^D, '$DEBUGGING' );

is( $WARNING, 0, '$WARNING' );
like( $EXECUTABLE_NAME, qr/perl/i, '$EXECUTABLE_NAME' );
is( $OSNAME, %Config{osname}, '$OSNAME' );

# may be non-portable
ok( $SYSTEM_FD_MAX +>= 2, '$SYSTEM_FD_MAX should be at least 2' );

is( $INPLACE_EDIT, '.inplace', '$INPLACE_EDIT' );

'aabbcc' =~ m/(.{2}).+(.{2})(?{ 9 })/;
is( $LAST_REGEXP_CODE_RESULT, 9, '$LAST_REGEXP_CODE_RESULT' );

ok( !$PERLDB, '$PERLDB should be false' );

{
	local $INPUT_RECORD_SEPARATOR = "\n\n";
	like( ~< *DATA, qr/a paragraph./, '$INPUT_RECORD_SEPARATOR' );
}
like( ~< *DATA, qr/second paragraph..\z/s, '$INPUT_RECORD_SEPARATOR' );

try { is( $EXCEPTIONS_BEING_CAUGHT, 1, '$EXCEPTIONS_BEING_CAUGHT' ) };
ok( !$EXCEPTIONS_BEING_CAUGHT, '$EXCEPTIONS_BEING_CAUGHT should be false' );

try { local *F; my $f = 'asdasdasd'; ++$f while -e $f; open(F, "<", $f); };
is( $OS_ERROR, $ERRNO, '$OS_ERROR' );
ok( %OS_ERROR_FLAGS{ENOENT}, '%OS_ERROR_FLAGS(ENOENT should be set)' );

package C;

use English < qw( -no_match_vars ) ;

"abc" =~ m/b/;

{
  our ($PREMATCH, $MATCH, $POSTMATCH);
  main::ok( !$PREMATCH, '$PREMATCH disabled' );
  main::ok( !$MATCH, '$MATCH disabled' );
  main::ok( !$POSTMATCH, '$POSTMATCH disabled' );
}

__END__
This is a line.
This is a paragraph.

This is a second paragraph.
It has several lines.
