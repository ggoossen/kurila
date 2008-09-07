#!./perl -w

BEGIN {
    require "./test.pl";

    plan ('no_plan');

    use_ok('Config');
}

use strict;

# Some (safe?) bets.

ok(nkeys %Config +> 500, "Config has more than 500 entries");

my ($first) = Config::config_sh() =~ m/^(\S+)=/m;
die "Can't find first entry in Config::config_sh()" unless defined $first;
print "# First entry is '$first'\n";

# It happens that the we know what the first key should be. This is somewhat
# cheating, but there was briefly a bug where the key got a bonus newline.
my ($first_each) = each %Config;
is($first_each, $first, "First key from each is correct");
ok(exists(%Config{$first_each}), "First key exists");
ok(!exists(%Config{"\n$first"}),
   "Check that first key with prepended newline isn't falsely existing");

is(%Config{PERL_REVISION}, undef, "No PERL_REVISION");
is(%Config{KURILA_VERSION}, 1, "KURILA_REVISION 1");

ok( exists %Config{cc},      "has cc");

ok( exists %Config{ccflags}, "has ccflags");

ok(!exists %Config{python},  "has no python");

ok( exists %Config{d_fork},  "has d_fork");

ok(!exists %Config{d_bork},  "has no d_bork");

like(%Config{ivsize}, qr/^(4|8)$/, "ivsize is 4 or 8 (it is %Config{ivsize})");

# byteorder is virtual, but it has rules.

like(%Config{byteorder}, qr/^(1234|4321|12345678|87654321)$/,
     "byteorder is 1234 or 4321 or 12345678 or 87654321 "
     . "(it is %Config{byteorder})");

is(length %Config{byteorder}, %Config{ivsize},
   "byteorder is as long as ivsize (which is %Config{ivsize})");

# ccflags_nolargefiles is virtual, too.

ok(exists %Config{ccflags_nolargefiles}, "has ccflags_nolargefiles");

# Utility functions.

{
    # make sure we can export what we say we can export.
    package Foo;
    my @exports = qw(myconfig config_sh config_vars config_re);
    Config->import(< @exports);
    foreach my $func ( @exports) {
	main::ok( __PACKAGE__->can($func), "$func exported" );
    }
}

like(Config::myconfig(), qr/osname=\Q%Config{osname}\E/,   "myconfig");
like(Config::config_sh(), qr/osname='\Q%Config{osname}\E'/, "config_sh");
like(Config::config_sh(), qr/byteorder='[1-8]+'/,
     "config_sh has a valid byteorder");
foreach my $line ( Config::config_re('c.*')) {
  like($line,                  qr/^c.*?=.*$/,                   'config_re' );
}

my ($out1, $out2);
{
    my $out = \$("");
    open my $fakeout, '>>', $out or die;
    local *STDOUT = *$fakeout{IO};

    Config::config_vars('cc');	# non-regex test of essential cfg-var
    $out1 = $$out;
    $$out = "";

    Config::config_vars('d_bork');	# non-regex, non-existent cfg-var
    $out2 = $$out;
    $$out = "";
}

like($out1, qr/^cc='\Q%Config{cc}\E';/, "found config_var cc");
like($out2, qr/^d_bork='UNKNOWN';/, "config_var d_bork is UNKNOWN");

# Read-only.

undef $@;
try { %Config{d_bork} = 'borkbork' };
like($@->{description}, qr/Config is read-only/, "no STORE");

ok(!exists %Config{d_bork}, "still no d_bork");

undef $@;
try { delete %Config{d_fork} };
like($@->{description}, qr/Config is read-only/, "no DELETE");

ok( exists %Config{d_fork}, "still d_fork");

undef $@;
try { %Config = %() };
like($@->{description}, qr/Config is read-only/, "no CLEAR");

ok( exists %Config{d_fork}, "still d_fork");

{
    package FakeOut;

    sub TIEHANDLE {
	bless(\(my $text), @_[0]);
    }

    sub clear {
	${ @_[0] } = '';
    }

    sub PRINT {
	my $self = shift;
	$$self .= join('', @_);
    }
}

# Signal-related variables
# (this is actually a regression test for Configure.)

is(nelems @(%Config{sig_num_init}  =~ m/,/g), %Config{sig_size}, "sig_num_init size");
is(nelems @(%Config{sig_name_init} =~ m/,/g), %Config{sig_size}, "sig_name_init size");

# Test the troublesome virtual stuff
my @virtual = qw(byteorder ccflags_nolargefiles ldflags_nolargefiles
                    libs_nolargefiles libswanted_nolargefiles);

# Also test that the first entry in config.sh is found correctly. There was
# special casing code for this

foreach my $pain (@($first, < @virtual)) {
  # No config var is named with anything that is a regexp metachar
  ok(exists %Config{$pain}, "\$config('$pain') exists");

  my @result = @( %Config{$pain} );
  is (nelems @result, 1, "single result for \$config('$pain')");

  @result = Config::config_re($pain);
  is (nelems @result, 1, "single result for config_re('$pain')");
  like (@result[0], qr/^$pain=(['"])\Q%Config{$pain}\E\1$/, # grr '
	"which is the expected result for $pain");
}

# Check that config entries appear correctly in @INC
# TestInit.pm has probably already messed with our @INC
# This little bit of evil is to avoid a @ in the program, in case it confuses
# shell 1 liners. Perl 1 rules.
my ($path, $ver, < @orig_inc)
  = < split m/\n/,
    runperl (nolib=>1,
	     prog=>'print qq{$^X\n$^V\n}; print qq{$_\n} while $_ = shift @INC');

die "This perl is $^V at $^X; other perl is $ver (at $path) "
  . '- failed to find this perl' unless $^V eq $ver;

my %orig_inc;
 <%orig_inc{[ @orig_inc]} = @();

my $failed;
# This is the order that directories are pushed onto @INC in perl.c:
foreach my $lib (qw(applibexp archlibexp privlibexp sitearchexp sitelibexp
		     vendorarchexp vendorlibexp vendorlib_stem)) {
  my $dir = %Config{$lib};
  SKIP: {
    skip "lib $lib not in \@INC on Win32" if $^O eq 'MSWin32';
    skip "lib $lib not defined" unless defined $dir;
    skip "lib $lib not set" unless length $dir;
    # So we expect to find it in @INC

    ok (exists %orig_inc{$dir}, "Expect $lib '$dir' to be in \@INC")
      or $failed++;
  }
}
_diag ('@INC is:', @orig_inc) if $failed;
