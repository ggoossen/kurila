#!./perl

BEGIN {
    require './test.pl';
}

plan tests => 5;

# symbolic filehandles should only result in glob entries with FH constructors

$^OUTPUT_AUTOFLUSH=1;
my $a = \*SYM000;
ok(!defined(fileno($a)));

select select $a;
ok(defined *{$a});

do {
    my $b = \*SYM001;
    ok(open($b, ">&", \*STDOUT));
    ok(defined *{$b});
    ok(close $b);
};

