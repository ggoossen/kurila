use strict;
use warnings;

BEGIN {
    if (%ENV{'PERL_CORE'}){
        chdir('t');
        unshift(@INC, '../lib');
    }
}

use Thread::Queue;

use Test::More 'tests' => 26;

my $q = Thread::Queue->new( <1..10);
ok($q, 'New queue');

try { $q->dequeue(undef); };
like($@->message, qr/Invalid 'count'/);
try { $q->dequeue(0); };
like($@->message, qr/Invalid 'count'/);
try { $q->dequeue(0.5); };
like($@->message, qr/Invalid 'count'/);
try { $q->dequeue(-1); };
like($@->message, qr/Invalid 'count'/);
try { $q->dequeue('foo'); };
like($@->message, qr/Invalid 'count'/);

try { $q->dequeue_nb(undef); };
like($@->message, qr/Invalid 'count'/);
try { $q->dequeue_nb(0); };
like($@->message, qr/Invalid 'count'/);
try { $q->dequeue_nb(-0.5); };
like($@->message, qr/Invalid 'count'/);
try { $q->dequeue_nb(-1); };
like($@->message, qr/Invalid 'count'/);
try { $q->dequeue_nb('foo'); };
like($@->message, qr/Invalid 'count'/);

try { $q->peek(undef); };
like($@->message, qr/Invalid 'index'/);
try { $q->peek(3.3); };
like($@->message, qr/Invalid 'index'/);
try { $q->peek('foo'); };
like($@->message, qr/Invalid 'index'/);

try { $q->insert(); };
like($@->message, qr/Invalid 'index'/);
try { $q->insert(undef); };
like($@->message, qr/Invalid 'index'/);
try { $q->insert(.22); };
like($@->message, qr/Invalid 'index'/);
try { $q->insert('foo'); };
like($@->message, qr/Invalid 'index'/);

try { $q->extract(undef); };
like($@->message, qr/Invalid 'index'/);
try { $q->extract('foo'); };
like($@->message, qr/Invalid 'index'/);
try { $q->extract(1.1); };
like($@->message, qr/Invalid 'index'/);
try { $q->extract(0, undef); };
like($@->message, qr/Invalid 'count'/);
try { $q->extract(0, 0); };
like($@->message, qr/Invalid 'count'/);
try { $q->extract(0, 3.3); };
like($@->message, qr/Invalid 'count'/);
try { $q->extract(0, -1); };
like($@->message, qr/Invalid 'count'/);
try { $q->extract(0, 'foo'); };
like($@->message, qr/Invalid 'count'/);

# EOF
