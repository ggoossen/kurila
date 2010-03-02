#!./perl -w

BEGIN 
    require "./test.pl"

    plan: 'no_plan'

    use_ok: 'Config'



# Some (safe?) bets.

ok: (nelems: (config_keys: )) +> 500, "Config has more than 500 entries"

my (@: $first) = @: (Config::config_sh: ) =~ m/^(\S+)=/m
die: "Can't find first entry in Config::config_sh()" unless defined $first
print: $^STDOUT, "# First entry is '$first'\n"

# It happens that the we know what the first key should be. This is somewhat
# cheating, but there was briefly a bug where the key got a bonus newline.
my (@: $first_each, ...) =  (config_keys: )
is: $first_each, $first, "First key from each is correct"

ok:  defined (config_value: "cc"),      "has cc"

ok:  defined (config_value: "ccflags"), "has ccflags"

ok: !defined (config_value: "python"),  "has no python"

ok:  defined (config_value: "d_fork"),  "has d_fork"

ok: !defined (config_value: "d_bork"),  "has no d_bork"

like: (config_value: "ivsize"), qr/^(4|8)$/, "ivsize is 4 or 8"

# byteorder is virtual, but it has rules.

like: (config_value: "byteorder"), qr/^(1234|4321|12345678|87654321)$/
      "byteorder is 1234 or 4321 or 12345678 or 87654321 "

is: length (config_value: "byteorder"), (config_value: "ivsize")
    "byteorder is as long as ivsize"

# ccflags_nolargefiles is virtual, too.

ok: defined (config_value: "ccflags_nolargefiles"), "has ccflags_nolargefiles"

# Utility functions.

do
    # make sure we can export what we say we can export.
    package Foo
    my @exports = qw(myconfig config_sh config_vars config_re)
    Config->import: < @exports
    foreach my $func ( @exports)
        main::ok:  (__PACKAGE__->can: $func), "$func exported" 
    


like: (Config::myconfig: ), qr/osname=\Q$((config_value: "osname"))\E/,   "myconfig"
like: (Config::config_sh: ), qr/osname='\Q$((config_value: "osname"))\E'/, "config_sh"
like: (Config::config_sh: ), qr/byteorder='[1-8]+'/
      "config_sh has a valid byteorder"
foreach my $line ( (Config::config_re: 'c.*'))
    like: $line,                  qr/^c.*?=.*$/,                   'config_re' 


my ($out1, $out2)
do
    my $out = \$("")
    open: my $fakeout, '>>', $out or die: 
    local $^STDOUT = $fakeout->*{IO}

    Config::config_vars: 'cc'	# non-regex test of essential cfg-var
    $out1 = $out->$
    $out->$ = ""

    Config::config_vars: 'd_bork'	# non-regex, non-existent cfg-var
    $out2 = $out->$
    $out->$ = ""


like: $out1, qr/^cc='\Q$((config_value: "cc"))\E';/, "found config_var cc"
like: $out2, qr/^d_bork='undef';/, "config_var d_bork is UNKNOWN"

do
    package FakeOut

    sub TIEHANDLE
        bless: \(my $text), @_[0]
    

    sub clear
        @_[0]->$ = ''
    

    sub PRINT
        my $self = shift
        $self->$ .= join: '', @_
    


# Signal-related variables
# (this is actually a regression test for Configure.)

is: (nelems: @: (config_value: "sig_num_init")  =~ m/,/g), (config_value: "sig_size"), "sig_num_init size"
is: (nelems: @: (config_value: "sig_name_init") =~ m/,/g), (config_value: "sig_size"), "sig_name_init size"

# Test the troublesome virtual stuff
my @virtual = qw(byteorder ccflags_nolargefiles ldflags_nolargefiles
                    libs_nolargefiles libswanted_nolargefiles)

# Also test that the first entry in config.sh is found correctly. There was
# special casing code for this

foreach my $pain (@: $first, < @virtual)
    # No config var is named with anything that is a regexp metachar
    ok: defined (config_value: $pain), "\$config('$pain') exists"

    my @result = Config::config_re: $pain
    is: nelems @result, 1, "single result for config_re('$pain')"
    like: @result[0], qr/^$pain=(['"])\Q$((config_value: $pain))\E\1$/ # grr '
          "which is the expected result for $pain"


# Check that config entries appear correctly in $^INCLUDE_PATH
# TestInit.pm has probably already messed with our $^INCLUDE_PATH
# This little bit of evil is to avoid a @ in the program, in case it confuses
# shell 1 liners. Perl 1 rules.
my @: $path, $ver, @< @orig_inc
    =  split: m/\n/
              runperl: nolib=>1
                       prog=>'print $^STDOUT, qq{$^EXECUTABLE_NAME\n$^PERL_VERSION\n}; print $^STDOUT, qq{$_\n} while $_ = shift $^INCLUDE_PATH'

die: "This perl is $^PERL_VERSION at $^EXECUTABLE_NAME; other perl is $ver (at $path) "
         . '- failed to find this perl' unless $^PERL_VERSION eq $ver

my %orig_inc
%orig_inc{[ @orig_inc]} =@:  $@

my $failed
# This is the order that directories are pushed onto $^INCLUDE_PATH in perl.c:
foreach my $lib (qw(applibexp archlibexp privlibexp sitearchexp sitelibexp
		     vendorarchexp vendorlibexp vendorlib_stem))
    my $dir = config_value: $lib
    :SKIP do
        skip: "lib $lib not in \$^INCLUDE_PATH on Win32" if $^OS_NAME eq 'MSWin32'
        skip: "lib $lib not defined" unless defined $dir
        skip: "lib $lib not set" unless length $dir
        # So we expect to find it in $^INCLUDE_PATH

        ok: exists %orig_inc{$dir}, "Expect $lib '$dir' to be in \$^INCLUDE_PATH"
            or $failed++
    

_diag: '$^INCLUDE_PATH is:', @orig_inc if $failed
