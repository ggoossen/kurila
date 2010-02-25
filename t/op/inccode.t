#!./perl -w

# Tests for the coderef-in-$^INCLUDE_PATH feature

use Config

my $can_fork   = 0
my $minitest   = env::var: 'PERL_CORE_MINITEST'
my $has_perlio = config_value: "useperlio"

if (!$minitest)
    if ((config_value: "d_fork") && try { require POSIX; 1 } )
        $can_fork = 1
    


use File::Spec

require "./test.pl"
plan: tests => 45 + !$minitest * (3 + 7 * $can_fork)

my @tempfiles = $@

sub get_temp_fh
    my $f = "DummyModule0000"
    1 while -e ++$f
    push: @tempfiles, $f
    open: my $fh, ">", "$f" or die: "Can't create $f: $^OS_ERROR"
    print: $fh, "package ".(substr: @_[0],0,-3).";\n1;\n"
    print: $fh, @_[1] if (nelems @_) +> 1
    close $fh or die: "Couldn't close: $^OS_ERROR"
    open: $fh, "<", $f or die: "Can't open $f: $^OS_ERROR"
    return $fh


END { 1 while (unlink: < @tempfiles) }

sub fooinc($self, $filename)
    if ((substr: $filename,0,3) eq 'Foo')
        return get_temp_fh: $filename
    else
        return undef
    


push: $^INCLUDE_PATH, \&fooinc

my $evalret = try { require Bar; 1 }
ok:  !$evalret,      'Trying non-magic package' 

$evalret = try { require Foo; 1 }
die: $^EVAL_ERROR if $^EVAL_ERROR
ok:  $evalret,                      'require Foo; magic via code ref'  
ok:  exists $^INCLUDED{'Foo.pm'},         '  $^INCLUDED sees Foo.pm' 
is:  ref $^INCLUDED{?'Foo.pm'}, 'CODE',    '  val Foo.pm is a coderef in $^INCLUDED' 
cmp_ok:  $^INCLUDED{?'Foo.pm'}, '\==', \&fooinc,	   '  val Foo.pm is correct in $^INCLUDED' 

$evalret = eval "use Foo1; 1;"
die: $^EVAL_ERROR if $^EVAL_ERROR
ok:  $evalret,                      'use Foo1' 
ok:  exists $^INCLUDED{'Foo1.pm'},        '  $^INCLUDED sees Foo1.pm' 
is:  ref $^INCLUDED{?'Foo1.pm'}, 'CODE',   '  val Foo1.pm is a coderef in $^INCLUDED' 
cmp_ok:  $^INCLUDED{?'Foo1.pm'}, '\==', \&fooinc,     '  val Foo1.pm is correct in $^INCLUDED' 

$evalret = try { evalfile 'Foo2.pl'; 1 }
die: $^EVAL_ERROR if $^EVAL_ERROR
ok:  $evalret,                      'do "Foo2.pl"' 
ok:  exists $^INCLUDED{'Foo2.pl'},        '  $^INCLUDED sees Foo2.pl' 
is:  ref $^INCLUDED{?'Foo2.pl'}, 'CODE',   '  val Foo2.pl is a coderef in $^INCLUDED' 
cmp_ok:  $^INCLUDED{?'Foo2.pl'}, '\==', \&fooinc,     '  val Foo2.pl is correct in $^INCLUDED' 

pop $^INCLUDE_PATH


sub fooinc2($self, $filename)
    if ((substr: $filename, 0, (length: $self->[1])) eq $self->[1])
        return get_temp_fh: $filename
    else
        return undef
    


my $arrayref = \@:  \&fooinc2, 'Bar' 
push: $^INCLUDE_PATH, $arrayref

$evalret = try { require Foo; 1; }
die: $^EVAL_ERROR if $^EVAL_ERROR
ok:  $evalret,                     'Originally loaded packages preserved' 
$evalret = try { require Foo3; 1; }
ok:  !$evalret,                    'Original magic INC purged' 

$evalret = try { require Bar; 1 }
die: $^EVAL_ERROR if $^EVAL_ERROR
ok:  $evalret,                     'require Bar; magic via array ref' 
ok:  exists $^INCLUDED{'Bar.pm'},        '  $^INCLUDED sees Bar.pm' 
is:  ref $^INCLUDED{?'Bar.pm'}, 'ARRAY',  '  val Bar.pm is an arrayref in $^INCLUDED' 
cmp_ok:  $^INCLUDED{?'Bar.pm'}, '\==', $arrayref,    '  val Bar.pm is correct in $^INCLUDED' 

(ok:  eval "use Bar1; 1;",          'use Bar1' ); die: if $^EVAL_ERROR
ok:  exists $^INCLUDED{'Bar1.pm'},       '  $^INCLUDED sees Bar1.pm' 
is:  ref $^INCLUDED{?'Bar1.pm'}, 'ARRAY', '  val Bar1.pm is an arrayref in $^INCLUDED' 
cmp_ok:  $^INCLUDED{?'Bar1.pm'}, '\==', $arrayref,   '  val Bar1.pm is correct in $^INCLUDED' 

ok:  try { evalfile 'Bar2.pl'; 1 },     'do "Bar2.pl"' 
ok:  exists $^INCLUDED{'Bar2.pl'},       '  $^INCLUDED sees Bar2.pl' 
is:  ref $^INCLUDED{?'Bar2.pl'}, 'ARRAY', '  val Bar2.pl is an arrayref in $^INCLUDED' 
cmp_ok:  $^INCLUDED{?'Bar2.pl'}, '\==', $arrayref,   '  val Bar2.pl is correct in $^INCLUDED' 

pop $^INCLUDE_PATH

sub FooLoader::INC($self, $filename)
    if ((substr: $filename,0,4) eq 'Quux')
        return get_temp_fh: $filename
    else
        return undef
    


my $href = bless:  \$%, 'FooLoader' 
push: $^INCLUDE_PATH, $href

$evalret = try { require Quux; 1 }
die: $^EVAL_ERROR if $^EVAL_ERROR
ok:  $evalret,                      'require Quux; magic via hash object' 
ok:  exists $^INCLUDED{'Quux.pm'},        '  $^INCLUDED sees Quux.pm' 
is:  ref $^INCLUDED{?'Quux.pm'}, 'FooLoader'
     '  val Quux.pm is an object in $^INCLUDED' 
cmp_ok:  $^INCLUDED{?'Quux.pm'}, '\==', $href,        '  val Quux.pm is correct in $^INCLUDED' 

pop $^INCLUDE_PATH

my $aref = bless:  \$@, 'FooLoader' 
push: $^INCLUDE_PATH, $aref

$evalret = try { require Quux1; 1 }
die: $^EVAL_ERROR if $^EVAL_ERROR
ok:  $evalret,                      'require Quux1; magic via array object' 
ok:  exists $^INCLUDED{'Quux1.pm'},       '  $^INCLUDED sees Quux1.pm' 
is:  ref $^INCLUDED{?'Quux1.pm'}, 'FooLoader'
     '  val Quux1.pm is an object in $^INCLUDED' 
cmp_ok:  $^INCLUDED{?'Quux1.pm'}, '\==', $aref,       '  val Quux1.pm  is correct in $^INCLUDED' 

pop $^INCLUDE_PATH

my $sref = bless:  \(my $x = 1), 'FooLoader' 
push: $^INCLUDE_PATH, $sref

$evalret = try { require Quux2; 1 }
die: $^EVAL_ERROR if $^EVAL_ERROR
ok:  $evalret,                      'require Quux2; magic via scalar object' 
ok:  exists $^INCLUDED{'Quux2.pm'},       '  $^INCLUDED sees Quux2.pm' 
is:  ref $^INCLUDED{?'Quux2.pm'}, 'FooLoader'
     '  val Quux2.pm is an object in $^INCLUDED' 
cmp_ok:  $^INCLUDED{?'Quux2.pm'}, '\==', $sref,       '  val Quux2.pm is correct in $^INCLUDED' 

pop $^INCLUDE_PATH

push: $^INCLUDE_PATH
      sub ($self, $filename)
          if ((substr: $filename,0,4) eq 'Toto')
              $^INCLUDED{+$filename} = 'xyz'
              return get_temp_fh: $filename
          else
              return undef

$evalret = try { require Toto; 1 }
die: $^EVAL_ERROR if $^EVAL_ERROR
ok:  $evalret,                      'require Toto; magic via anonymous code ref'  
ok:  exists $^INCLUDED{'Toto.pm'},        '  $^INCLUDED sees Toto.pm' 
ok:  ! ref $^INCLUDED{?'Toto.pm'},         q/  val Toto.pm isn't a ref in $^INCLUDED/ 
is:  $^INCLUDED{?'Toto.pm'}, 'xyz',	   '  val Toto.pm is correct in $^INCLUDED' 

pop $^INCLUDE_PATH

push: $^INCLUDE_PATH
      sub (@< @_)
          my (@: $self, $filename) =  @_
          if ($filename eq 'abc.pl')
              return get_temp_fh: $filename, qq(return "abc";\n)
          else
              return undef

my $ret = ""
$ret ||= evalfile 'abc.pl'
is:  $ret, 'abc', 'do "abc.pl" sees return value' 

do
    my $filename = $^OS_NAME eq 'MacOS' ?? ':Foo:Foo.pm' !! './Foo.pm'
    #local $^INCLUDE_PATH; # local fails on tied @INC
    my @old_INC = $^INCLUDE_PATH # because local doesn't work on tied arrays
    $^INCLUDE_PATH = @:  sub (@< @_) { $filename = 'seen'; return undef; } 
    try { require $filename; }
    is:  $filename, 'seen', 'the coderef sees fully-qualified pathnames' 
    $^INCLUDE_PATH = @old_INC


exit if $minitest

:SKIP do
    skip:  "No PerlIO available", 3  unless $has_perlio
    pop $^INCLUDE_PATH

    push: $^INCLUDE_PATH
          sub (@< @_)
              my (@: $cr, $filename) =  @_
              my $module = $filename; $module =~ s,/,::,g; $module =~ s/\.pm$//
              open: my $fh, '<'
                    \"package $module; sub complain \{ warn: q(barf) \}; \$main::file = __FILE__;"
                  or die: $^OS_ERROR
              $^INCLUDED{+$filename} = "/custom/path/to/$filename"
              return $fh

    require Publius::Vergilius::Maro
    is:  $^INCLUDED{?'Publius/Vergilius/Maro.pm'}
         '/custom/path/to/Publius/Vergilius/Maro.pm', '$^INCLUDED set correctly'
    is:  our $file, '/custom/path/to/Publius/Vergilius/Maro.pm'
         '__FILE__ set correctly' 
    do
        my $warning
        local $^WARN_HOOK = sub (@< @_) { $warning = shift }
        (Publius::Vergilius::Maro::complain: )
        like: ($warning->stacktrace: ), qr{^ at /custom/path/to/Publius/Vergilius/Maro.pm}, 'warn() reports correct file source' 
    

pop $^INCLUDE_PATH

if ($can_fork)
    require PerlIO::scalar
    # This little bundle of joy generates n more recursive use statements,
    # with each module chaining the next one down to 0. If it works, then we
    # can safely nest subprocesses
    push: $^INCLUDE_PATH
          sub (@< @_)
              return unless @_[1] =~ m/^BBBLPLAST(\d+)\.pm/
              my $pid = open: my $fh, "-|", "-"
              if ($pid)
                  # Parent
                  return $fh

              die: "Can't fork self: $^OS_ERROR" unless defined $pid

              # Child
              my $count = $1
              # Lets force some fun with odd sized reads.
              $^OUTPUT_AUTOFLUSH = 1
              print: $^STDOUT, 'push: @main::bbblplast, '
              print: $^STDOUT, "$count;\n"
              if ($count--)
                  print: $^STDOUT, "use BBBLPLAST$count;\n"

              print: $^STDOUT, "pass: 'In @_[1]';"
              print: $^STDOUT, '"Truth"'
              POSIX::_exit: 0
              die: "Can't get here: $^OS_ERROR"
    

    @::bbblplast = $@
    require BBBLPLAST5
    is: "$((join: ' ',@main::bbblplast))", "0 1 2 3 4 5", "All ran"

    foreach (keys $^INCLUDED)
        delete $^INCLUDED{$_} if m/^BBBLPLAST/
    

    @::bbblplast = $@

