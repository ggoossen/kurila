
use Test::More tests => 3;

eval 'use kurila';
ok ! $@, "'use kurila' without version";

eval "use kurila v1.4";
ok ! $@, "'use kurila 1.4'";

eval "use kurila v1.99";
like $@->{description}, qr/only version/;
