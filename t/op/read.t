#!./perl

# $RCSfile: read.t,v $$Revision: 4.1 $$Date: 92/08/07 18:28:17 $

BEGIN {
    chdir 't';
    @INC = '../lib';
    require './test.pl';
}
use strict;

plan tests => 2564;

open(FOO,'op/read.t') || open(FOO,'t/op/read.t') || open(FOO,':op:read.t') || die "Can't open op.read";
seek(FOO,4,0) or die "Seek failed: $!";
my $buf;
my $got = read(FOO,$buf,4);

is ($got, 4);
is ($buf, "perl");

seek (FOO,0,2) || seek(FOO,20000,0);
$got = read(FOO,$buf,4);

is ($got, 0);
is ($buf, "");

my $tmpfile = 'Op_read.tmp';

1 while unlink $tmpfile;

my (@values, @buffers) = ('', '');

foreach (65, 161, 253, 9786) {
    push @values, join "", map {chr $_} $_ .. $_ + 4;
    push @buffers, join "", map {chr $_} $_ + 5 .. $_ + 20;
}

foreach my $value (@values) {
    foreach my $initial_buffer (@buffers) {
	my @utf8 = 1;
	if ($value !~ tr/\0-\377//c) {
	    # It's all 8 bit
	    unshift @utf8, 0;
	}
	foreach my $utf8 (@utf8) {
	    1 while unlink $tmpfile;
	    open FH, ">$tmpfile" or die "Can't open $tmpfile: $!";
	    binmode FH, "utf8" if $utf8;
	    print FH $value;
	    close FH;
	    foreach my $offset (0, 3, 7, 22, -1, -3, -5, -7) {
		foreach my $length (0, 2, 5, 10) {
		    # Will read the lesser of the length of the file and the
		    # read length
		    my $will_read = $value;
		    if ($length < length $will_read) {
			substr ($will_read, $length) = '';
		    }
		    # Going to trash this so need a copy
		    my $buffer = $initial_buffer;

		    my $expect = $buffer;
		    if ($offset > 0) {
			# Right pad with NUL bytes
			$expect .= "\0" x $offset;
			substr ($expect, $offset) = '';
		    }
		    substr ($expect, $offset) = $will_read;

		    open FH, $tmpfile or die "Can't open $tmpfile: $!";
		    binmode FH, "utf8" if $utf8;
		    my $what = sprintf "%d into %d l $length o $offset",
			ord $value, ord $buffer;
		    $what .= ' u' if $utf8;
		    $got = read (FH, $buffer, $length, $offset);
		    is ($got, length $will_read, "got $what");
		    is ($buffer, $expect, "buffer $what");
		}
	    }
	}
    }
}



