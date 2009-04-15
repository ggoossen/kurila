#!./perl
#
#  Copyright (c) 2002 Slaven Rezic
#
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

use Config;

sub BEGIN {
    if (env::var('PERL_CORE')){
       chdir('t') if -d 't';
       $^INCLUDE_PATH = @('.', '../lib');
    } else {
       unshift $^INCLUDE_PATH, 't';
    }
}

BEGIN {
    if (!eval q{
       use Test::More;
       1;
    }) {
       print $^STDOUT, "1..0 # skip: tests only work with Test::More\n";
       exit;
    }
}

BEGIN { plan tests => 1 }

my @warns;
$^WARN_HOOK = sub { push @warns, shift };
$^DIE_HOOK  = sub { require Carp; warn < Carp::longmess(); warn "Evil die!" };

require Storable;

Storable::dclone(\%(foo => "bar"));

is(join("", @warns), "", "__DIE__ is not evil here");
