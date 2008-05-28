#!./perl

BEGIN { require './test.pl' };
plan tests => 1;
use strict;

ok 1;

# eval qq(use strict 'garbage');
# like($@->{description}, qr/^Unknown 'strict' tag\(s\) 'garbage'/);

# eval qq(no strict 'garbage');
# like($@->{description}, qr/^Unknown 'strict' tag\(s\) 'garbage'/);

# eval qq(use strict qw(foo bar));
# like($@->{description}, qr/^Unknown 'strict' tag\(s\) 'foo bar'/);

# eval qq(no strict qw(foo bar));
# like($@->{description}, qr/^Unknown 'strict' tag\(s\) 'foo bar'/);
