package ExtUtils::MakeMaker::Config

our $VERSION = '6.44'

use Config < qw(config_value config_keys)

# Give us an overridable config.
our %Config = %+: map: { %: $_ => (config_value: $_) }, (config_keys: )

sub import
    my $caller = caller

    (Symbol::fetch_glob: $caller.'::Config')->* = \%Config


1


=head1 NAME

ExtUtils::MakeMaker::Config - Wrapper around Config.pm


=head1 SYNOPSIS

  use ExtUtils::MakeMaker::Config;
  print $Config{installbin};  # or whatever


=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY>

A very thin wrapper around Config.pm so MakeMaker is easier to test.

=cut
