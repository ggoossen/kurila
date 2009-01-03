#!./perl -i.inplace
# note the extra switch, for the test below

use Test::More tests => 16;

use English < qw( -no_match_vars ) ;
use Config;
use Errno;

"abc" =~ m/b/;

our $threads;

is( $PROGRAM_NAME, $^PROGRAM_NAME, '$PROGRAM_NAME' );
is( $BASETIME, $^BASETIME, '$BASETIME' );

is( $PERL_VERSION, $^PERL_VERSION, '$PERL_VERSION' );
is( $DEBUGGING, $^DEBUGGING, '$DEBUGGING' );

is( $WARNING, 0, '$WARNING' );
like( $EXECUTABLE_NAME, qr/perl/i, '$EXECUTABLE_NAME' );
is( $OSNAME, config_value("osname"), '$OSNAME' );

# may be non-portable
ok( $SYSTEM_FD_MAX +>= 2, '$SYSTEM_FD_MAX should be at least 2' );

is( $INPLACE_EDIT, '.inplace', '$INPLACE_EDIT' );

'aabbcc' =~ m/(.{2}).+(.{2})(?{ 9 })/;
is( $LAST_REGEXP_CODE_RESULT, 9, '$LAST_REGEXP_CODE_RESULT' );

ok( !$PERLDB, '$PERLDB should be false' );

try { is( $EXCEPTIONS_BEING_CAUGHT, 1, '$EXCEPTIONS_BEING_CAUGHT' ) };
ok( !$EXCEPTIONS_BEING_CAUGHT, '$EXCEPTIONS_BEING_CAUGHT should be false' );

package C;

use English < qw( -no_match_vars ) ;

"abc" =~ m/b/;

do {
  our ($PREMATCH, $MATCH, $POSTMATCH);
  main::ok( !$PREMATCH, '$PREMATCH disabled' );
  main::ok( !$MATCH, '$MATCH disabled' );
  main::ok( !$POSTMATCH, '$POSTMATCH disabled' );
};

__END__
This is a line.
This is a paragraph.

This is a second paragraph.
It has several lines.
