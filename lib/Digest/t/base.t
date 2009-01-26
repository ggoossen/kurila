#!perl -w

use Test < qw(plan ok);
plan tests => 12;

do {
   package LenDigest;
   require Digest::base;
   our (@ISA);
   @ISA = qw(Digest::base);

   sub new {
	my $class = shift;
	my $str = "";
	bless \$str, $class;
   }

   sub add {
	my $self = shift;
	$$self .= join("", @_);
	return $self;
   }

   sub digest {
	my $self = shift;
	my $len = length($$self);
	my $first = ($len +> 0) ?? substr($$self, 0, 1) !! "X";
	$$self = "";
	return sprintf "$first\%04d", $len;
   }
};

my $ctx = LenDigest->new;
ok($ctx->digest, "X0000");

my $EBCDIC = ord('A') == 193;

if ($EBCDIC) {
    ok($ctx->hexdigest, "e7f0f0f0f0");
    ok($ctx->b64digest, "5/Dw8PA");
} else {
    ok($ctx->hexdigest, "5830303030");
    ok($ctx->b64digest, "WDAwMDA");
}

$ctx->add("foo");
ok($ctx->digest, "f0003");

$ctx->add("foo");
ok($ctx->hexdigest, $EBCDIC ?? "86f0f0f0f3" !! "6630303033");

$ctx->add("foo");
ok($ctx->b64digest, $EBCDIC ?? "hvDw8PM" !! "ZjAwMDM");

open(my $fh, ">", "xxtest$^PID") || die;
binmode($fh);
print $fh "abc" x 100, "\n";
close($fh) || die;

open($fh, "<", "xxtest$^PID") || die;
$ctx->addfile(\*$fh);
close($fh);
unlink("xxtest$^PID") || warn;

ok($ctx->digest, "a0301");

try {
    $ctx->add_bits("1010");
};
ok($^EVAL_ERROR->{?description} =~ m/^Number of bits must be multiple of 8/);

$ctx->add_bits($EBCDIC ?? "11100100" !! "01010101");
ok($ctx->digest, "U0001");

try {
    $ctx->add_bits("abc", 12);
};
ok($^EVAL_ERROR->{?description} =~ m/^Number of bits must be multiple of 8/);

$ctx->add_bits("abc", 16);
ok($ctx->digest, "a0002");

$ctx->add_bits("abc", 32);
ok($ctx->digest, "a0003");
