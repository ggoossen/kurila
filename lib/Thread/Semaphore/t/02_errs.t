use strict;
use warnings;

BEGIN {
    if (%ENV{'PERL_CORE'}){
        chdir('t');
        unshift(@INC, '../lib');
    }
}

use Thread::Semaphore;

use Test::More 'tests' => 12;

my $err = qr/^Semaphore .* is not .* integer: /;

try { Thread::Semaphore->new(undef); };
like($@ && $@->message, $err);
try { Thread::Semaphore->new(0.5); };
like($@ && $@->message, $err);
try { Thread::Semaphore->new('foo'); };
like($@ && $@->message, $err);

my $s = Thread::Semaphore->new();
ok($s, 'New semaphore');

try { $s->down(undef); };
like($@->message, $err);
try { $s->down(-1); };
like($@->message, $err);
try { $s->down(1.5); };
like($@->message, $err);
try { $s->down('foo'); };
like($@->message, $err);

try { $s->up(undef); };
like($@->message, $err);
try { $s->up(-1); };
like($@->message, $err);
try { $s->up(1.5); };
like($@->message, $err);
try { $s->up('foo'); };
like($@->message, $err);

# EOF
