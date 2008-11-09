#!./perl

BEGIN {
    require './test.pl';
}

plan tests => 57;

our (@foo, $foo, $c, @bar, $got, %chop, %chomp, $x, $y);

$_ = 'abc';
$c = foo();
is ($c . $_, 'cab', 'optimized');

$_ = 'abc';
$c = chop($_);
is ($c . $_ , 'cab', 'unoptimized');

sub foo {
    chop;
}

@foo = @("hi \n","there\n","!\n");
@bar = @foo;
chop(@bar);
is (join('', @bar), 'hi there!');

$foo = "\n";
chop($foo, @foo);
is (join('', @($foo,< @foo)), 'hi there!');

$_ = "foo\n\n";
$got = chomp();
ok ($got == 1) or print "# got $got\n";
is ($_, "foo\n");

$_ = "foo\n";
$got = chomp();
ok ($got == 1) or print "# got $got\n";
is ($_, "foo");

$_ = "foo";
$got = chomp();
ok ($got == 0) or print "# got $got\n";
is ($_, "foo");

$_ = "foo";
$/ = "oo";
$got = chomp();
ok ($got == 2) or print "# got $got\n";
is ($_, "f");

$_ = "bar";
$/ = "oo";
$got = chomp();
ok ($got == 0) or print "# got $got\n";
is ($_, "bar");

$_ = "f\n\n\n\n\n";
$/ = "";
$got = chomp();
ok ($got == 5) or print "# got $got\n";
is ($_, "f");

$_ = "f\n\n";
$/ = "";
$got = chomp();
ok ($got == 2) or print "# got $got\n";
is ($_, "f");

$_ = "f\n";
$/ = "";
$got = chomp();
ok ($got == 1) or print "# got $got\n";
is ($_, "f");

$_ = "f";
$/ = "";
$got = chomp();
ok ($got == 0) or print "# got $got\n";
is ($_, "f");

$_ = "xx";
$/ = "xx";
$got = chomp();
ok ($got == 2) or print "# got $got\n";
is ($_, "");

$_ = "axx";
$/ = "xx";
$got = chomp();
ok ($got == 2) or print "# got $got\n";
is ($_, "a");

$_ = "axx";
$/ = "yy";
$got = chomp();
ok ($got == 0) or print "# got $got\n";
is ($_, "axx");

# This case once mistakenly behaved like paragraph mode.
$_ = "ab\n";
$/ = \3;
$got = chomp();
ok ($got == 0) or print "# got $got\n";
is ($_, "ab\n");

# Go Unicode.

do {
    use utf8;

$_ = "abc\x{1234}";
chop;
is ($_, "abc", "Go Unicode");

$_ = "abc\x{1234}d";
chop;
is ($_, "abc\x{1234}");

$_ = "\x{1234}\x{2345}";
chop;
is ($_, "\x{1234}");

};

# chomp should not stringify references unless it decides to modify them
$_ = \@();
$/ = "\n";
dies_like( sub { $got = chomp(); }, qr/reference as string/, "chomp ref" );
is (ref($_), "ARRAY", "chomp ref (no modify)");
$/ = ")";  # the last char of something like "ARRAY(0x80ff6e4)"
dies_like( sub { $got = chomp(); }, qr/reference as string/, "chomp ref no modify" );
is (ref($_), "ARRAY", "chomp ref (no modify)");

$/ = "\n";

%chomp = %("One" => "One", "Two\n" => "Two", "" => "");
%chop = %("One" => "On", "Two\n" => "Two", "" => "");

foreach (keys %chomp) {
  my $key = $_;
  try {chomp $_};
  if ($@) {
    my $err = $@;
    $err =~ s/\n$//s;
    fail ("\$\@ = \"$err\"");
  } else {
    is ($_, %chomp{?$key}, "chomp hash key");
  }
}

foreach (keys %chop) {
  my $key = $_;
  try {chop $_};
  if ($@) {
    my $err = $@;
    $err =~ s/\n$//s;
    fail ("\$\@ = \"$err\"");
  } else {
    is ($_, %chop{?$key}, "chop hash key");
  }
}

# chop and chomp can't be lvalues
eval 'chop($x) = 1;';
ok($@->{?description} =~ m/Can\'t modify.*chop.*in.*assignment/);
eval 'chomp($x) = 1;';
ok($@->{?description} =~ m/Can\'t modify.*chom?p.*in.*assignment/);
eval 'chop($x, $y) = (1, 2);';
ok($@->{?description} =~ m/Can\'t modify.*chop.*in.*assignment/);
eval 'chomp($x, $y) = (1, 2);';
ok($@->{?description} =~ m/Can\'t modify.*chom?p.*in.*assignment/);

do {
    use utf8;
    # returns length in code-points, but not in bytes.
    $/ = "\x{100}";
    $a = "A$/";
    $b = chomp $a;
    is ($b, 1);

    $/ = "\x{100}\x{101}";
    $a = "A$/";
    $b = chomp $a;
    is ($b, 2);

    # returns length in bytes, not in code-points.
    use utf8;
    $/ = "\x{100}";
    no utf8;
    $a = "A$/";
    is( chomp($a), 2);

    use utf8;
    $/ = "\x{100}\x{101}";
    no utf8;
    $a = "A$/";
    is( chomp($a), 4);
};

do {
    # [perl #36569] chop fails on decoded string with trailing nul
    my $asc = "perl\0";
    my $utf = "perl".pack('U',0); # marked as utf8
    is(chop($asc), "\0", "chopping ascii NUL");
    is(chop($utf), "\0", "chopping utf8 NUL");
    is($asc, "perl", "chopped ascii NUL");
    is($utf, "perl", "chopped utf8 NUL");
};

do {
    # Change 26011: Re: A surprising segfault
    # to make sure only that these obfuscated sentences will not crash.

    map chop(), @( ('')x68);
    ok(1, "extend sp in pp_chop");

    map chomp(), @( ('')x68);
    ok(1, "extend sp in pp_chomp");
};
