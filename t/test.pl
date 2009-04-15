#
# t/test.pl - most of Test::More functionality without the fuss


# NOTE:
#
# Increment ($x++) has a certain amount of cleverness for things like
#
#   $x = 'zz';
#   $x++; # $x eq 'aaa';
#
# stands more chance of breaking than just a simple
#
#   $x = $x + 1
#
# In this file, we use the latter "Baby Perl" approach, and increment
# will be worked over by t/op/inc.t

use env;

our ($Level, $TODO, $NO_ENDING);

$Level = 1;
my $test = 1;
my $planned;
my $noplan;

$TODO = 0;
$NO_ENDING = 0;

# Use this instead of print to avoid interference while testing globals.
sub _print {
    local@($^OUTPUT_RECORD_SEPARATOR, $^OUTPUT_FIELD_SEPARATOR) = @(undef, '');
    print $^STDOUT, < @_;
}

sub _print_stderr {
    local@($^OUTPUT_RECORD_SEPARATOR, $^OUTPUT_FIELD_SEPARATOR) = @(undef, '');
    print $^STDERR, < @_;
}

sub plan {
    my $n;
    if ((nelems @_) == 1) {
	$n = shift;
	if ($n eq 'no_plan') {
	  undef $n;
	  $noplan = 1;
	}
    } else {
	my %plan = %( < @_ );
	$n = %plan{?tests};
    }
    _print "1..$n\n" unless $noplan;
    $planned = $n;
}

END {
    my $ran = $test - 1;
    if (!$NO_ENDING) {
	if (defined $planned && $planned != $ran) {
	    _print_stderr
		"# Looks like you planned $planned tests but ran $ran.\n";
	} elsif ($noplan) {
	    _print "1..$ran\n";
	}
    }
}

# Use this instead of "print STDERR" when outputing failure diagnostic
# messages
sub _diag {
    return unless (nelems @_);
    my @mess = map { m/^#/ ?? "$_\n" !! "# $_\n" },
    @+: map { split m/\n/ }, @_;
    my $func = $TODO ?? \&_print !! \&_print_stderr;
    $func->(< @mess);
}

sub diag {
    _diag(< @_);
}

sub info {
    my @mess = map { m/^#/ ?? "$_\n" !! "# $_\n" },
      @+: map { split m/\n/ }, @_;
    _print(< @mess);
}

sub skip_all {
    if ((nelems @_)) {
	_print "1..0 # Skipped: $(join ' ',@_)\n";
    } else {
	_print "1..0\n";
    }
    exit(0);
}

sub _ok {
    my @($pass, $where, ?$name, @< @mess) =  @_;
    # Do not try to microoptimize by factoring out the "not ".
    # VMS will avenge.
    my $out;
    if ($name) {
        # escape out '#' or it will interfere with '# skip' and such
        $name =~ s/#/\\#/g;
	$out = $pass ?? "ok $test - $name" !! "not ok $test - $name";
    } else {
	$out = $pass ?? "ok $test" !! "not ok $test";
    }

    $out .= " # TODO $TODO" if $TODO;
    _print "$out\n";

    unless ($pass) {
	_diag "# Failed $where\n";
    }

    # Ensure that the message is properly escaped.
    _diag < @mess;

    $test = $test + 1; # don't use ++

    return $pass;
}

sub _where {
    my @caller = @( caller($Level) );
    return "at @caller[1] line @caller[2]";
}

# DON'T use this for matches. Use like() instead.
sub ok ($pass, ?$name, @< @mess) {
    _ok($pass, _where(), $name, < @mess);
}

sub _q {
    my $x = shift;
    return dump::view($x);
}

sub _qq {
    my $x = shift;
    return dump::view($x);
};

# keys are the codes \n etc map to, values are 2 char strings such as \n
my %backslash_escape;
foreach my $x (split m//, q|nrtfa\'"|) {
    %backslash_escape{+ord eval "\"\\$x\""} = "\\$x";
}
# A way to display scalars containing control characters and Unicode.
# Trying to avoid setting $_, or relying on local $_ to work.
sub display {
    return dump::view(@_[0]);
}

sub is ($got, $expected, ?$name, @< @mess) {

    my $pass;
    if( !defined $got || !defined $expected ) {
        # undef only matches undef
        $pass = !defined $got && !defined $expected;
    }
    elsif (ref $got and ref $expected) {
        $pass = $got \== $expected;
    }
    else {
        local $^EVAL_ERROR = undef;
        $pass = try { $got eq $expected };
    }

    unless ($pass) {
	unshift(@mess, "#      got "._q($got)."\n",
		       "# expected "._q($expected)."\n");
    }
    _ok($pass, _where(), $name, < @mess);
}

sub isnt ($got, $isnt, ?$name, @< @mess) {
    my $pass;
    if( !defined $got || !defined $isnt ) {
        # undef only matches undef
        $pass = defined $got || defined $isnt;
    }
    elsif (ref $got and ref $isnt) {
        $pass = $got \!= $isnt;
    }
    else {
        $pass = $got ne $isnt;
    }

    unless( $pass ) {
        unshift(@mess, "# it should not be "._q($got)."\n",
                       "# but it is.\n");
    }
    _ok($pass, _where(), $name, < @mess);
}

sub cmp_ok ($got, $type, $expected, ?$name, @< @mess) {
    my $pass;
    do {
        local $^WARNING = 0;
        local($^EVAL_ERROR,$^OS_ERROR);   # don't interfere with $@
                        # eval() sometimes resets $!
        $pass = eval "\$got $type \$expected";
    };
    unless ($pass) {
        # It seems Irix long doubles can have 2147483648 and 2147483648
        # that stringify to the same thing but are acutally numerically
        # different. Display the numbers if $type isn't a string operator,
        # and the numbers are stringwise the same.
        # (all string operators have alphabetic names, so tr/a-z// is true)
        # This will also show numbers for some uneeded cases, but will
        # definately be helpful for things such as == and <= that fail
        if (not ref $got and not ref $expected
            and $got eq $expected and $type !~ m/[a-z]/) {
            unshift @mess, "# $got - $expected = " . ($got - $expected) . "\n";
        }
        unshift(@mess, "#      got "._q($got)."\n",
                       "# expected $type "._q($expected)."\n");
    }
    _ok($pass, _where(), $name, < @mess);
}

# Check that $got is within $range of $expected
# if $range is 0, then check it's exact
# else if $expected is 0, then $range is an absolute value
# otherwise $range is a fractional error.
# Here $range must be numeric, >= 0
# Non numeric ranges might be a useful future extension. (eg %)
sub within ($got, $expected, $range, $name, @< @mess) {
    my $pass;
    if (!defined $got or !defined $expected or !defined $range) {
        # This is a fail, but doesn't need extra diagnostics
    } elsif ($got !~ m/[0-9]/ or $expected !~ m/[0-9]/ or $range !~ m/[0-9]/) {
        # This is a fail
        unshift @mess, "# got, expected and range must be numeric\n";
    } elsif ($range +< 0) {
        # This is also a fail
        unshift @mess, "# range must not be negative\n";
    } elsif ($range == 0) {
        # Within 0 is ==
        $pass = $got == $expected;
    } elsif ($expected == 0) {
        # If expected is 0, treat range as absolute
        $pass = ($got +<= $range) && ($got +>= - $range);
    } else {
        my $diff = $got - $expected;
        $pass = abs ($diff / $expected) +< $range;
    }
    unless ($pass) {
        if ($got eq $expected) {
            unshift @mess, "# $got - $expected = " . ($got - $expected) . "\n";
        }
	unshift@mess, "#      got "._q($got)."\n",
		      "# expected "._q($expected)." (within "._q($range).")\n";
    }
    _ok($pass, _where(), $name, < @mess);
}

# Note: this isn't quite as fancy as Test::More::like().

sub like   (@< @a) { like_yn (0,< @a) }; # 0 for -
sub unlike (@< @a) { like_yn (1,< @a) }; # 1 for un-

sub like_yn ($flip, $got, $expected, ?$name, @< @mess) {
    my $pass;
    $pass = $got =~ m/$expected/ if !$flip;
    $pass = $got !~ m/$expected/ if $flip;
    unless ($pass) {
	unshift(@mess, "#      got '$got'\n",
		$flip
		?? "# expected !~ m/$expected/\n" !! "# expected m/$expected/\n");
    }
    local $Level = $Level + 1;
    _ok($pass, _where(), $name, < @mess);
}

sub pass {
    _ok(1, '', < @_);
}

sub fail {
    _ok(0, _where(), < @_);
}

sub curr_test {
    $test = shift if (nelems @_);
    return $test;
}

sub next_test {
  my $retval = $test;
  $test = $test + 1; # don't use ++
  $retval;
}

# Note: can't pass multipart messages since we try to
# be compatible with Test::More::skip().
sub skip {
    my $why = shift;
    my $n    = (nelems @_) ?? shift !! 1;
    for (1..$n) {
        _print "ok $test # skip: $why\n";
        $test = $test + 1;
    }
    local $^WARNING = 0;
    last SKIP;
}

sub todo_skip {
    my $why = shift;
    my $n   = (nelems @_) ?? shift !! 1;

    for (1..$n) {
        _print "not ok $test # TODO & SKIP: $why\n";
        $test = $test + 1;
    }
    local $^WARNING = 0;
    last TODO;
}

sub eq_array {
    my @($ra, $rb) =  @_;
    return 0 unless (nelems @$ra) == nelems(@$rb);
    for my $i (0..(nelems @$ra)-1) {
	next     if !defined $ra->[$i] && !defined $rb->[$i];
	return 0 if !defined $ra->[$i];
	return 0 if !defined $rb->[$i];
	return 0 unless $ra->[$i] eq $rb->[$i];
    }
    return 1;
}

sub eq_hash {
  my @($orig, $suspect) =  @_;
  my $fail;
  while (my @(?$key, ?$value) =@( each %$suspect)) {
    # Force a hash recompute if this perl's internals can cache the hash key.
    $key = "" . $key;
    if (exists $orig->{$key}) {
      if ($orig->{?$key} ne $value) {
        _print "# key ", _qq($key), " was ", _qq($orig->{?$key}),
                     " now ", _qq($value), "\n";
        $fail = 1;
      }
    } else {
      _print "# key ", _qq($key), " is ", _qq($value),
                   ", not in original.\n";
      $fail = 1;
    }
  }
  foreach (keys %$orig) {
    # Force a hash recompute if this perl's internals can cache the hash key.
    $_ = "" . $_;
    next if (exists $suspect->{$_});
    _print "# key ", < _qq($_), " was ", < _qq($orig->{?$_}), " now missing.\n";
    $fail = 1;
  }
  !$fail;
}

sub require_ok ($require) {
    eval <<REQUIRE_OK;
require $require;
REQUIRE_OK
    _ok(!$^EVAL_ERROR, _where(), "require $require");
}

sub use_ok ($use) {
    eval <<USE_OK;
use $use;
USE_OK
    _ok(!$^EVAL_ERROR, _where(), "use $use");
}

# runperl - Runs a separate perl interpreter.
# Arguments :
#   switches => [ command-line switches ]
#   nolib    => 1 # don't use -I../lib (included by default)
#   prog     => one-liner (avoid quotes)
#   progs    => [ multi-liner (avoid quotes) ]
#   progfile => perl script
#   stdin    => string to feed the stdin
#   stderr   => redirect stderr to stdout
#   args     => [ command-line arguments to the perl program ]
#   verbose  => print the command line

my $is_mswin    = $^OS_NAME eq 'MSWin32';
my $is_netware  = $^OS_NAME eq 'NetWare';
my $is_macos    = $^OS_NAME eq 'MacOS';
my $is_vms      = $^OS_NAME eq 'VMS';
my $is_cygwin   = $^OS_NAME eq 'cygwin';

sub _quote_args {
    my @($runperl, $args) =  @_;

    foreach ( @$args) {
	# In VMS protect with doublequotes because otherwise
	# DCL will lowercase -- unless already doublequoted.
       $_ = q(").$_.q(") if $is_vms && !m/^\"/ && length($_) +> 0;
	$$runperl .= ' ' . $_;
    }
}

sub _create_runperl { # Create the string to qx in runperl().
    my %args = %( < @_ );
    my $runperl = $^EXECUTABLE_NAME =~ m/\s/ ?? qq{"$^EXECUTABLE_NAME"} !! $^EXECUTABLE_NAME;
    #- this allows, for example, to set PERL_RUNPERL_DEBUG=/usr/bin/valgrind
    if (env::var('PERL_RUNPERL_DEBUG')) {
	$runperl = "$(env::var('PERL_RUNPERL_DEBUG')) $runperl";
    }
    unless (%args{?nolib}) {
	if ($is_macos) {
	    $runperl .= ' -I::lib';
	    # Use UNIX style error messages instead of MPW style.
	    $runperl .= ' -MMac::err=unix' if %args{?stderr};
	}
	else {
	    $runperl .= ' "-I../lib"'; # doublequotes because of VMS
	}
    }
    if (%args{?switches}) {
	local $Level = 2;
	die "test.pl:runperl(): 'switches' must be an ARRAYREF " . _where()
	    unless ref %args{?switches} eq "ARRAY";
	_quote_args(\$runperl, %args{?switches});
    }
    if (defined %args{?prog}) {
	die "test.pl:runperl(): both 'prog' and 'progs' cannot be used " . _where()
	    if defined %args{?progs};
        %args{+progs} = \@(%args{?prog})
    }
    if (defined %args{?progs}) {
	die "test.pl:runperl(): 'progs' must be an ARRAYREF " . _where()
	    unless ref %args{?progs} eq "ARRAY";
        foreach my $prog ( @{%args{progs}}) {
            if ($is_mswin || $is_netware || $is_vms) {
                $runperl .= qq ( -e "$prog" );
            }
            else {
                $runperl .= qq ( -e '$prog' );
            }
        }
    } elsif (defined %args{?progfile}) {
	$runperl .= qq( "%args{?progfile}");
    } else {
	# You probaby didn't want to be sucking in from the upstream stdin
	die "test.pl:runperl(): none of prog, progs, progfile, args, "
	    . " switches or stdin specified"
	    unless defined %args{?args} or defined %args{?switches}
		or defined %args{?stdin};
    }
    if (defined %args{?stdin}) {
	# so we don't try to put literal newlines and crs onto the
	# command line.
	%args{+stdin} =~ s/\n/\\n/g;
	%args{+stdin} =~ s/\r/\\r/g;

	if ($is_mswin || $is_netware || $is_vms) {
	    $runperl = qq{$^EXECUTABLE_NAME -e "print \\\$^STDOUT, qq(} .
		%args{?stdin} . q{)" | } . $runperl;
	}
	elsif ($is_macos) {
	    # MacOS can only do two processes under MPW at once;
	    # the test itself is one; we can't do two more, so
	    # write to temp file
	    my $stdin = qq{$^EXECUTABLE_NAME -e 'print \$^STDOUT, qq(} . %args{?stdin} . qq{)' > teststdin; };
	    if (%args{?verbose}) {
		my $stdindisplay = $stdin;
		$stdindisplay =~ s/\n/\n\#/g;
		_print_stderr "# $stdindisplay\n";
	    }
	    `$stdin`;
	    $runperl .= q{ < teststdin };
	}
	else {
	    $runperl = qq{$^EXECUTABLE_NAME -e 'print \$^STDOUT, qq(} .
		%args{?stdin} . q{)' | } . $runperl;
	}
    }
    if (defined %args{?args}) {
	_quote_args(\$runperl, %args{?args});
    }
    $runperl .= ' 2>&1'          if  %args{?stderr} && !$is_macos;
    $runperl .= " \x[B3] Dev:Null" if !%args{?stderr} &&  $is_macos;
    if (%args{?verbose}) {
	my $runperldisplay = $runperl;
	$runperldisplay =~ s/\n/\n\#/g;
	_print_stderr "# $runperldisplay\n";
    }
    return $runperl;
}

sub runperl {
    die "test.pl:runperl() does not take a hashref"
	if ref @_[0] and ref @_[0] eq 'HASH';
    my $runperl = _create_runperl( < @_ );
    my $result = `$runperl`;
    $result =~ s/\n\n/\n/ if $is_vms; # XXX pipes sometimes double these
    return $result;
}

*run_perl = \&runperl; # Nice alias.

sub DIE {
    _print_stderr "# $(join ' ',@_)\n";
    exit 1;
}

# A somewhat safer version of the sometimes wrong $^X.
my $Perl;
sub which_perl {
    unless (defined $Perl) {
	$Perl = $^EXECUTABLE_NAME;

	# VMS should have 'perl' aliased properly
	return $Perl if $^OS_NAME eq 'VMS';

	my $exe;
        our %Config;
	eval "require Config; Config->import";
	if ($^EVAL_ERROR) {
	    warn "test.pl had problems loading Config: $^EVAL_ERROR";
	    $exe = '';
	} else {
	    $exe = %Config{?_exe};
	}
       $exe = '' unless defined $exe;

	# This doesn't absolutize the path: beware of future chdirs().
	# We could do File::Spec->abs2rel() but that does getcwd()s,
	# which is a bit heavyweight to do here.

	if ($Perl =~ m/^perl\Q$exe\E$/i) {
	    my $perl = "perl$exe";
	    eval "require File::Spec";
	    if ($^EVAL_ERROR) {
		warn "test.pl had problems loading File::Spec: $^EVAL_ERROR";
		$Perl = "./$perl";
	    } else {
		$Perl = 'File::Spec'->catfile( <'File::Spec'->curdir(), $perl);
	    }
	}

	# Build up the name of the executable file from the name of
	# the command.

	if ($Perl !~ m/\Q$exe\E$/i) {
	    $Perl .= $exe;
	}

	warn "which_perl: cannot find $Perl from $^EXECUTABLE_NAME" unless -f $Perl;

	# For subcommands to use.
	env::var('PERLEXE' ) = $Perl;
    }
    return $Perl;
}

sub unlink_all {
    foreach my $file ( @_) {
        1 while unlink $file;
        _print_stderr "# Couldn't unlink '$file': $^OS_ERROR\n" if -f $file;
    }
}


my $tmpfile = "misctmp000";
1 while -f ++$tmpfile;
END { unlink_all $tmpfile }

#
# _fresh_perl
#
# The $resolve must be a subref that tests the first argument
# for success, or returns the definition of success (e.g. the
# expected scalar) if given no arguments.
#

sub _fresh_perl {
    my@($prog, $resolve, $runperl_args, $name) =  @_;

    $runperl_args ||= \%();
    $runperl_args->{+progfile} = $tmpfile;
    $runperl_args->{+stderr} = 1;

    open my $test_fh, ">", "$tmpfile" or die "Cannot open $tmpfile: $^OS_ERROR";

    # VMS adjustments
    if( $^OS_NAME eq 'VMS' ) {
        $prog =~ s#/dev/null#NL:#;

        # VMS file locking
        $prog =~ s{if \(-e _ and -f _ and -r _\)}
                  {if (-e _ and -f _)}
    }

    print $test_fh, $prog;
    close $test_fh or die "Cannot close $tmpfile: $^OS_ERROR";

    my $results = runperl(< %$runperl_args);
    my $status = $^CHILD_ERROR;

    # Clean up the results into something a bit more predictable.
    $results =~ s/\n+$//;
    $results =~ s/at\s+misctmp\d+\s+line/at - line/g;
    $results =~ s/of\s+misctmp\d+\s+aborted/of - aborted/g;

    # bison says 'parse error' instead of 'syntax error',
    # various yaccs may or may not capitalize 'syntax'.
    $results =~ s/^(syntax|parse) error/syntax error/mig;

    if ($^OS_NAME eq 'VMS') {
        # some tests will trigger VMS messages that won't be expected
        $results =~ s/\n?%[A-Z]+-[SIWEF]-[A-Z]+,.*//;

        # pipes double these sometimes
        $results =~ s/\n\n/\n/g;
    }

    my $pass = $resolve->($results);
    unless ($pass) {
        _diag "# PROG: \n$prog\n";
        _diag "# EXPECTED:\n", $resolve->(), "\n";
        _diag "# GOT:\n$results\n";
        _diag "# STATUS: $status\n";
    }

    # Use the first line of the program as a name if none was given
    unless( $name ) {
        my $first_line;
        @($first_line, $name) = @: $prog =~ m/^((.{1,50}).*)/;
        $name .= '...' if length $first_line +> length $name;
    }

    _ok($pass, _where(), "fresh_perl - $name");
}

#
# fresh_perl_is
#
# Combination of run_perl() and is().
#

sub fresh_perl_is {
    my@($prog, $expected, ?$runperl_args, ?$name) =  @_;
    local $Level = 2;
    $expected =~ s/\n+$//; # is also removed from program output
    _fresh_perl($prog,
		sub { (nelems @_) ?? @_[0] eq $expected !! $expected },
		$runperl_args, $name);
}

#
# fresh_perl_like
#
# Combination of run_perl() and like().
#

sub fresh_perl_like {
    my@($prog, $expected, $runperl_args, $name) =  @_;
    local $Level = 2;
    _fresh_perl($prog,
		sub { (nelems @_) ??
			  @_[0] =~ (ref $expected ?? $expected !! m/$expected/) !!
		          $expected },
		$runperl_args, $name);
}

sub can_ok ($proto, @< @methods) {
    my $class = ref $proto || $proto;

    unless( nelems @methods ) {
        return _ok( 0, < _where(), "$class->can(...)" );
    }

    my @nok = @( () );
    foreach my $method ( @methods) {
        local($^OS_ERROR, $^EVAL_ERROR);  # don't interfere with caller's $@
                        # eval sometimes resets $!
        try { $proto->can($method) } || push @nok, $method;
    }

    my $name;
    $name = (nelems @methods) == 1 ?? "$class->can('@methods[0]')"
                          !! "$class->can(...)";

    _ok( !nelems @nok, _where(), $name );
}

sub isa_ok ($object, $class, ?$obj_name) {
    my $diag;
    $obj_name = 'The object' unless defined $obj_name;
    my $name = "$obj_name isa $class";
    if( !defined $object ) {
        $diag = "$obj_name isn't defined";
    }
    elsif( !ref $object ) {
        $diag = "$obj_name isn't a reference";
    }
    else {
        # We can't use UNIVERSAL::isa because we want to honor isa() overrides
        local($^EVAL_ERROR, $^OS_ERROR);  # eval sometimes resets $!
        my $rslt = try { $object->isa($class) };
        if( $^EVAL_ERROR ) {
            if( $^EVAL_ERROR->{?description} =~ m/^Can't call method "isa" on unblessed reference/ ) {
                if( !UNIVERSAL::isa($object, $class) ) {
                    my $ref = ref $object;
                    $diag = "$obj_name isn't a '$class' it's a '$ref'";
                }
            } else {
                die <<WHOA;
WHOA! I tried to call ->isa on your object and got some weird error.
This should never happen.  Please contact the author immediately.
Here's the error.
$^EVAL_ERROR
WHOA
            }
        }
        elsif( !$rslt ) {
            my $ref = ref $object;
            $diag = "$obj_name isn't a '$class' it's a '$ref'";
        }
    }

    _ok( !$diag, _where(), $name );
}

sub dies_not ($e, ?$name) {
    local $Level = 2;
    if (try { $e->(); 1; }) {
        return ok(1, $name);
    }
    diag $^EVAL_ERROR->message;
    return ok(0, $name);
}

sub dies_like ($e, $qr, ?$name) {
    if (try { $e->(); 1; }) {
        local $Level = 2;
        diag "didn't die";
        return ok(0, $name);
    }
    my $err = $^EVAL_ERROR->{?description};
    return like_yn(0, $err, $qr );
}

sub eval_dies_like ($e, $qr, ?$name) {
  TODO:
    do {
        todo_skip("Compile time abortion are known to leak memory", 1) if env::var('PERL_VALGRIND');
        
        eval "$e";
        my $err = $^EVAL_ERROR;
        if (not $err) {
            local $Level = 2;
            diag "didn't die";
            return ok(0, $name);
        }
        return like_yn(0, $err->{description}, $qr, $name );
    };
}

1;
