#!./perl

BEGIN { require "./test.pl"; }

plan(tests => 19);

use File::Spec;

my $devnull = 'File::Spec'->devnull;

open(TRY, ">", 'Io_argv1.tmp') || (die "Can't open temp file: $!");
print TRY "a line\n";
close TRY or die "Could not close: $!";

{
    my $x = runperl(
	prog	=> 'while (~< *ARGV) { print $_; }',
	stdin	=> "foo\n",
	args	=> \@( 'Io_argv1.tmp', '-' ),
    );
    is($x, "a line\nfoo\n", '   from a file and STDIN');

    $x = runperl(
	prog	=> 'while (~< *ARGV) { print $_; }',
	stdin	=> "foo\n",
    );
    is($x, "foo\n", '   from just STDIN');
}

{
    # 5.10 stopped autovivifying scalars in globs leading to a
    # segfault when $ARGV is written to.
    runperl( prog => 'eof()', stdin => "nothing\n" );
    is( 0+$?, 0, q(eof() doesn't segfault) );
}

open(TRY, ">", 'Io_argv1.tmp') or die "Can't open temp file: $!";
close TRY or die "Could not close: $!";
open(TRY, ">", 'Io_argv2.tmp') or die "Can't open temp file: $!";
close TRY or die "Could not close: $!";
@ARGV = @('Io_argv1.tmp', 'Io_argv2.tmp');
$^I = '_bak';   # not .bak which confuses VMS
$/ = undef;
my $i = 4;
while ( ~< *ARGV) {
    s/^/ok $i\n/;
    ++$i;
    print;
    next_test();
}
open(TRY, "<", 'Io_argv1.tmp') or die "Can't open temp file: $!";
print while ~< *TRY;
open(TRY, "<", 'Io_argv2.tmp') or die "Can't open temp file: $!";
print while ~< *TRY;
close TRY or die "Could not close: $!";
undef $^I;

ok( eof TRY );

{
    no warnings 'once';
    ok( eof NEVEROPENED,    'eof() true on unopened filehandle' );
}

open STDIN, "<", 'Io_argv1.tmp' or die $!;
@ARGV = @( () );
ok( !eof(),     'STDIN has something' );

is( ~< *ARGV, "ok 4\n" );

open STDIN, '<', $devnull or die $!;
@ARGV = @( () );
ok( eof(),      'eof() true with empty @ARGV' );

@ARGV = @('Io_argv1.tmp');
ok( !eof() );

@ARGV = @($devnull, $devnull);
ok( !eof() );

close ARGV or die $!;
ok( eof(),      'eof() true after closing ARGV' );

{
    local $/;
    open F, "<", 'Io_argv1.tmp' or die "Could not open Io_argv1.tmp: $!";
    ~< *F;	# set $. = 1
    is( ~< *F, undef );

    open F, "<", $devnull or die;
    ok( defined( ~< *F) );

    is( ~< *F, undef );
    is( ~< *F, undef );

    open F, "<", $devnull or die;	# restart cycle again
    ok( defined( ~< *F) );
    is( ~< *F, undef );
    close F or die "Could not close: $!";
}

END {
    1 while unlink 'Io_argv1.tmp', 'Io_argv1.tmp_bak',
	'Io_argv2.tmp', 'Io_argv2.tmp_bak', 'Io_argv3.tmp';
}
