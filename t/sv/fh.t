#!./perl

BEGIN {
    require './test.pl';
}

plan tests => 8;

# symbolic filehandles should only result in glob entries with FH constructors

$|=1;
my $a = "SYM000";
ok(!defined(fileno($a)));
ok(!defined *{$a});

select select Symbol::fetch_glob($a);
ok(defined *{$a});

$a++;
ok(!close $a);
ok(!defined *{$a});

{
    no strict 'refs';
    ok(open(Symbol::fetch_glob($a), ">&STDOUT"));
    ok(defined *{$a});
}

ok(close $a);

