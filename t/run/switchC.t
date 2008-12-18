#!./perl -w

# Tests for the command-line switches

BEGIN {
    unless ('PerlIO::Layer'->find( 'perlio')) {
	print "1..0 # Skip: not perlio\n";
	exit 0;
    }
}

BEGIN { require "./test.pl"; }

plan(tests => 6);

my $r;

my @tmpfiles = @( () );
END { unlink < @tmpfiles }

my $b = pack("C*", unpack("U0C*", pack("U",256)));

$r = runperl( switches => \@( '-CO', '-w' ),
	      prog     => 'use utf8; print chr(256)',
              stderr   => 1 );
like( $r, qr/^$b(?:\r?\n)?$/s, '-CO: no warning on UTF-8 output' );

SKIP: do {
    if (defined env::var('PERL_UNICODE') &&
	(env::var('PERL_UNICODE') eq "" || env::var('PERL_UNICODE') =~ m/[SO]/)) {
	skip(qq[cannot test with PERL_UNICODE locale "" or /[SO]/], 1);
    }
    $r = runperl( switches => \@( '-CI', '-w' ),
		  prog     => 'use utf8; print ord( ~< *STDIN)',
		  stderr   => 1,
		  stdin    => $b );
    like( $r, qr/^256(?:\r?\n)?$/s, '-CI: read in UTF-8 input' );
};

$r = runperl( switches => \@( '-CE', '-w' ),
	      prog     => 'use utf8; warn chr(256)',
              stderr   => 1 );
like( $r, qr/^$b at -e line 1 character \d+.$/s, '-CE: UTF-8 stderr' );

$r = runperl( switches => \@( '-Co', '-w' ),
	      prog     => 'use utf8; open(F, q(>), q(out)) or die $!; print F chr(256); close F', stderr   => 1 ); like( $r, qr/^$/s, '-Co: auto-UTF-8 open for output' ); 
push @tmpfiles, "out";

$r = runperl( switches => \@( '-Ci', '-w' ),
	      prog     => 'use utf8; open(F, q(<), q(out)); print ord(~< *F); close F',
              stderr   => 1 );
like( $r, qr/^256(?:\r?\n)?$/s, '-Ci: auto-UTF-8 open for input' );

require utf8;
$r = runperl( switches => \@( '-CA', '-w' ),
	      prog     => 'use utf8; print ord shift(@ARGV)',
              stderr   => 1,
              args     => \@( utf8::chr(256) ) );
like( $r, qr/^256(?:\r?\n)?$/s, '-CA: @ARGV' );

