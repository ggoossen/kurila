
unless (@ARGV)
  @ARGV = qw( constants )

my %gen = %+: map: { %: $_ => 1 }, @ARGV

if (delete %gen{constants})
  (make_constants: )

for my $key (keys %gen)
  print: $^STDERR, "Invalid request to regenerate $key!\n"

sub make_constants()
  require ExtUtils::Constant

  my $source = 'lib/IPC/SysV.pm'
  local $_

  open: my $sysv_fh, '<', $source or die: "$source: $^OS_ERROR\n";

  my $parse = 0;
  my @const;

  while (~< $sysv_fh)
    if ($parse)
      if (m/^\)/) $parse++; last
      push: @const, < split: 
    m/^\@EXPORT_OK\s*=/ and $parse++

  close $sysv_fh

  die: "couldn't parse $source" if $parse != 2

  (ExtUtils::Constant::WriteConstants: 
      NAME       => 'IPC::SysV'
      NAMES      => \@const
      XS_FILE    => 'const-xs.inc'
      C_FILE     => 'const-c.inc'
      XS_SUBNAME => '_constant'
      PROXYSUBS => 1
    );

  print: $^STDOUT, "Writing const-xs.inc\n"
  print: $^STDOUT, "Writing const-c.inc\n"
