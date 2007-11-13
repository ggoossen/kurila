
use Test::More tests => 3;

eval 'use kurila';
ok ! $@, "'use kurila' without version";

eval "use kurila 1.4";
ok ! $@, "'use kurila 1.4'";

eval "use kurila 1.99";
like $@, qr/only version/;
