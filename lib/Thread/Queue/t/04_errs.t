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

my $q = Thread::Queue->new(1..10);
ok($q, 'New queue');

eval { $q->dequeue(undef); };
like($@->message, qr/Invalid 'count'/);
eval { $q->dequeue(0); };
like($@->message, qr/Invalid 'count'/);
eval { $q->dequeue(0.5); };
like($@->message, qr/Invalid 'count'/);
eval { $q->dequeue(-1); };
like($@->message, qr/Invalid 'count'/);
eval { $q->dequeue('foo'); };
like($@->message, qr/Invalid 'count'/);

eval { $q->dequeue_nb(undef); };
like($@->message, qr/Invalid 'count'/);
eval { $q->dequeue_nb(0); };
like($@->message, qr/Invalid 'count'/);
eval { $q->dequeue_nb(-0.5); };
like($@->message, qr/Invalid 'count'/);
eval { $q->dequeue_nb(-1); };
like($@->message, qr/Invalid 'count'/);
eval { $q->dequeue_nb('foo'); };
like($@->message, qr/Invalid 'count'/);

eval { $q->peek(undef); };
like($@->message, qr/Invalid 'index'/);
eval { $q->peek(3.3); };
like($@->message, qr/Invalid 'index'/);
eval { $q->peek('foo'); };
like($@->message, qr/Invalid 'index'/);

eval { $q->insert(); };
like($@->message, qr/Invalid 'index'/);
eval { $q->insert(undef); };
like($@->message, qr/Invalid 'index'/);
eval { $q->insert(.22); };
like($@->message, qr/Invalid 'index'/);
eval { $q->insert('foo'); };
like($@->message, qr/Invalid 'index'/);

eval { $q->extract(undef); };
like($@->message, qr/Invalid 'index'/);
eval { $q->extract('foo'); };
like($@->message, qr/Invalid 'index'/);
eval { $q->extract(1.1); };
like($@->message, qr/Invalid 'index'/);
eval { $q->extract(0, undef); };
like($@->message, qr/Invalid 'count'/);
eval { $q->extract(0, 0); };
like($@->message, qr/Invalid 'count'/);
eval { $q->extract(0, 3.3); };
like($@->message, qr/Invalid 'count'/);
eval { $q->extract(0, -1); };
like($@->message, qr/Invalid 'count'/);
eval { $q->extract(0, 'foo'); };
like($@->message, qr/Invalid 'count'/);

# EOF
