package ExtUtils::testlib

use warnings

our $VERSION = 6.44

use Cwd
use File::Spec

# So the tests can chdir around and not break $^INCLUDE_PATH.
# We use getcwd() because otherwise rel2abs will blow up under taint
# mode pre-5.8.  We detaint is so $^INCLUDE_PATH won't be tainted.  This is
# no worse, and probably better, than just shoving an untainted,
# relative "blib/lib" onto $^INCLUDE_PATH.
my $cwd
BEGIN 
    (@: $cwd) = @: (getcwd: ) =~ m/(.*)/

use lib < map: { (File::Spec->rel2abs: $_, $cwd) }, qw(blib/arch blib/lib)
1
__END__

=head1 NAME

ExtUtils::testlib - add blib/* directories to $^INCLUDE_PATH

=head1 SYNOPSIS

  use ExtUtils::testlib;

=head1 DESCRIPTION

After an extension has been built and before it is installed it may be
desirable to test it bypassing C<make test>. By adding

    use ExtUtils::testlib;

to a test program the intermediate directories used by C<make> are
added to $^INCLUDE_PATH.

