#!./perl -w

use Test::More tests => 11;

BEGIN {
    use_ok("Errno");
}

BAIL_OUT("No errno's are exported") unless (nelems @Errno::EXPORT_OK);

my $err = @Errno::EXPORT_OK[0];
my $num = &{*{Symbol::fetch_glob("Errno::$err")}};

is($num, &{*{Symbol::fetch_glob("Errno::$err")}});

$! = $num;
ok(exists %!{$err});

$! = 0;
ok(! %!{$err});

ok(join(",",sort keys(%!)) eq join(",",sort < @Errno::EXPORT_OK));

try { exists %!{''} };
ok(! $@);

try {%!{$err} = "qunckkk" };
like($@->{description}, qr/^ERRNO hash is read only!/);

try {delete %!{$err}};
like($@->{description}, qr/^ERRNO hash is read only!/);

$! = Errno::EINPROGRESS();
is( %!{EINPROGRESS}, Errno::EINPROGRESS );

# The following tests are in trouble if some OS picks errno values
# through Acme::MetaSyntactic::batman
is(%!{EFLRBBB}, "");
ok(! exists(%!{EFLRBBB}));
