#!./perl

require "./test.pl";
plan( tests => 49 );

our (@b, @a, @foo, @bar, $c, $d, %c, $x);

@foo = @(1, 2, 3, 4);
cmp_ok(@foo[0], '==', 1, 'first elem');
cmp_ok(@foo[3], '==', 4, 'last elem');

$_ = join(':', @foo);
cmp_ok($_, 'eq', '1:2:3:4', 'join list');

@($a,$b,$c,$d) = @(1,2,3,4);
cmp_ok("$a;$b;$c;$d", 'eq', '1;2;3;4', 'list assign');

@($c,$b,$a) =  split(m/ /,"111 222 333");
cmp_ok("$a;$b;$c",'eq','333;222;111','list split on space');

@($a,$b,$c) = @($c,$b,$a);
cmp_ok("$a;$b;$c",'eq','111;222;333','trio rotate');

@($a, $b) = @($b, $a);
cmp_ok("$a-$b",'eq','222-111','duo swap');

@($a, $b) = $: @($b, $a) = @($a, $b);
cmp_ok("$a-$b",'eq','222-111','duo swap swap');

@($a, @b[+1], %c{+2}, $d) = @(1, 2, 3, 4);
cmp_ok($a,'==',1,'assign scalar in list');
cmp_ok(@b[1],'==',2,'assign aelem in list');
cmp_ok(%c{?2},'==',3,'assign helem in list');
cmp_ok($d,'==',4,'assign last scalar in list');

@foo = @(1,2,3,4,5,6,7,8);
@($a, $b, $c, $d, ...) =  @foo;
cmp_ok("$a/$b/$c/$d",'eq','1/2/3/4','long list assign');

@foo = @(1,2);
@($a, $b, ?$c, ?$d) =  @foo;
cmp_ok($a,'==',1,'short list 1 defined');
cmp_ok($b,'==',2,'short list 2 defined');
ok(!defined($c),'short list 3 undef');
ok(!defined($d),'short list 4 undef');

@foo = $: @bar = @(1);
cmp_ok(join(':', @(< @foo,< @bar)),'eq','1:1','list reassign');

@foo = $: @bar = @(2,3);
cmp_ok(join(':', @(join('+', @foo),join('-', @bar))),'eq','2+3:2-3','long list reassign');

@foo = @( () );
@foo = @( 1+2+3 );
cmp_ok(join(':', @foo),'eq','6','scalar assign to array');

do {
    my ($a, $b, $c);
    for my $x (0..2) {
        @($a, $b, $c) = 
              $x == 0 ??  @('a','b','c')
            !! $x == 1 ??  @('d','e','f')
            !!            @('g','h','i')
        ;
        if ($x == 0) {
            cmp_ok($a,'eq','a','ternary for a 1');
            cmp_ok($b,'eq','b','ternary for b 1');
            cmp_ok($c,'eq','c','ternary for c 1');
        }
        if ($x == 1) {
            cmp_ok($a,'eq','d','ternary for a 2');
            cmp_ok($b,'eq','e','ternary for b 2');
            cmp_ok($c,'eq','f','ternary for c 2');
        }
        if ($x == 2) {
            cmp_ok($a,'eq','g','ternary for a 3');
            cmp_ok($b,'eq','h','ternary for b 3');
            cmp_ok($c,'eq','i','ternary for c 3');
        }
    }
};

do {
    my ($a, $b, $c);
    for my $x (0..2) {
        @($a, $b, $c) = do {
            if ($x == 0) {
                @('a','b','c');
            }
            elsif ($x == 1) {
                @('d','e','f');
            }
            else {
                @('g','h','i');
            }
        };
        if ($x == 0) {
            cmp_ok($a,'eq','a','block for a 1');
            cmp_ok($b,'eq','b','block for b 1');
            cmp_ok($c,'eq','c','block for c 1');
        }
        if ($x == 1) {
            cmp_ok($a,'eq','d','block for a 2');
            cmp_ok($b,'eq','e','block for b 2');
            cmp_ok($c,'eq','f','block for c 2');
        }
        if ($x == 2) {
            cmp_ok($a,'eq','g','block for a 3');
            cmp_ok($b,'eq','h','block for b 3');
            cmp_ok($c,'eq','i','block for c 3');
        }
    }
};

$x = 666;
@a = @($x == 12345 || (1,2,3));
cmp_ok(join('*', @a),'eq','1*2*3','logical or f');

@a = @($x == $x || (4,5,6));
cmp_ok(join('*', @a),'eq','1','logical or t');

cmp_ok(join('', @(1,2,(3,4,5))),'eq','12345','list ..(...)');
cmp_ok(join('', @((1,2,3,4,5))),'eq','12345','list (.....)');
cmp_ok(join('', @((1,2,3,4),5)),'eq','12345','list (....).');
cmp_ok(join('', @(1,(2,3,4),5)),'eq','12345','list .(...).');
cmp_ok(join('', @(1,2,(3,4),5)),'eq','12345','list ..(..).');
cmp_ok(join('', @(1,2,3,(4),5)),'eq','12345','list ...(.).');
cmp_ok(join('', @((1,2),3,(4,5))),'eq','12345','list (..).(..)');

do {
    my @a = @(0, undef, undef, 3);
    my @b = @a[[@(1,2)]];
    my @c = @(0, undef, undef, 3)[[1..2]];
    cmp_ok(scalar(nelems @b),'==',scalar(nelems @c),'slice and slice');
    cmp_ok(scalar(nelems @c),'==',2,'slice len');
};

