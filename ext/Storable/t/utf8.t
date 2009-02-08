#!./perl -w
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

use Config;

BEGIN {
    if (env::var('PERL_CORE')){
	chdir('t') if -d 't';
	push $^INCLUDE_PATH, '../ext/Storable/t';
    } else {
	unshift $^INCLUDE_PATH, 't';
    }
    require 'st-dump.pl';
}


use utf8;

use Storable < qw(thaw freeze);

use Test::More tests => 5;

my $x = chr(1234);
is $x, ${thaw freeze \$x};

# Long scalar
$x = join '', map {chr $_}, @( ( <0..1023));
is $x, ${thaw freeze \$x};

# Char in the range 127-255 (probably) in utf8
$x = chr (175) . chr (256);
chop $x;
is $x, ${thaw freeze \$x};

# Storable needs to cope if a frozen string happens to be internall utf8
# encoded

$x = chr 256;
my $data = freeze \$x;
is $x, ${thaw $data};

$data .= chr 256;
chop $data;
is $x, ${thaw $data};

