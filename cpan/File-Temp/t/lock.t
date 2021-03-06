#!perl -w
# Test O_EXLOCK

use Test::More;
use Fcntl;

BEGIN {
# see if we have O_EXLOCK
  try { Fcntl::O_EXLOCK; };
  if ($^EVAL_ERROR && $^EVAL_ERROR->description =~ m/Your vendor has not defined/) {
      plan skip_all => 'Do not seem to have O_EXLOCK';
  } else {
    plan tests => 4;
    use_ok( "File::Temp" );
  }
}

# Need Symbol package for lexical filehandle on older perls
require Symbol if $] < 5.006;

# Get a tempfile with O_EXLOCK
my $fh = new File::Temp();
ok( -e "$fh", "temp file is present" );

# try to open it with a lock
my $flags = O_CREAT | O_RDWR | O_EXLOCK;

my $timeout = 5;
my $status;
try {
   local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
   alarm $timeout;
   my $newfh;
   $newfh = &Symbol::gensym if $] < 5.006;
   $status = sysopen($newfh, "$fh", $flags, 0600);
   alarm 0;
};
if ($@) {
   die unless $@ eq "alarm\n";   # propagate unexpected errors
   # timed out
}
ok( !$status, "File $fh is locked" );

# Now get a tempfile with locking disabled
$fh = new File::Temp( EXLOCK => 0 );

try {
   local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
   alarm $timeout;
   my $newfh;
   $newfh = &Symbol::gensym if $] < 5.006;
   $status = sysopen($newfh, "$fh", $flags, 0600);
   alarm 0;
};
if ($@) {
   die unless $@ eq "alarm\n";   # propagate unexpected errors
   # timed out
}
ok( $status, "File $fh is not locked");
