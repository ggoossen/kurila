#!./perl

eval 'use Errno';
die $^EVAL_ERROR if $^EVAL_ERROR and !env::var('PERL_CORE_MINITEST');

print $^STDOUT, "1..21\n";

do {
my $foo = $^STDOUT;
print $foo, "ok 1\n";
};

print $^STDOUT, "ok 2\n","ok 3\n","ok 4\n";
print $^STDOUT, "ok 5\n";

open(my $foo, ">-") or die;
print $foo, "ok 6\n";

printf $^STDOUT, "ok \%d\n",7;
printf($^STDOUT, "ok \%d\n",8);

my @a = @("ok \%d\%c",9,ord("\n"));
printf $^STDOUT, < @a;

@a[1] = 10;
printf $^STDOUT, < @a;

$^OUTPUT_FIELD_SEPARATOR = ' ';
$^OUTPUT_RECORD_SEPARATOR = "\n";

print $^STDOUT, "ok","11";

my @x = @("ok","12\nok","13\nok");
my @y = @("15\nok","16");
print $^STDOUT, < @x,"14\nok",< @y;
do {
    local $^OUTPUT_RECORD_SEPARATOR = "ok 17\n# null =>[\000]\nok 18\n";
    print $^STDOUT, "";
};

$^OUTPUT_RECORD_SEPARATOR = '';

if (!exists &Errno::EBADF) {
    print $^STDOUT, "ok 19 # skipped: no EBADF\n";
} else {
    $^OS_ERROR = 0;
    no warnings 'unopened';
    print \*NONEXISTENT, "foo";
    print $^STDOUT, "not " if ($^OS_ERROR != &Errno::EBADF( < @_ ));
    print $^STDOUT, "ok 19\n";
}

do {
    # Change 26009: pp_print didn't extend the stack
    #               before pushing its return value
    # to make sure only that these obfuscated sentences will not crash.

    map { print($^STDOUT, < reverse @($_)) }, @(('')x68);
    print $^STDOUT, "ok 20\n";

    map { print($^STDOUT, ) }, @(('')x68);
    print $^STDOUT, "ok 21\n";
};
