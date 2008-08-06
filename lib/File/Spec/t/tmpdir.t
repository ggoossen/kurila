use strict;
use Test;

# Grab all of the plain routines from File::Spec
use File::Spec;
use File::Spec::Win32;

plan tests => 4;

ok 1, 1, "Loaded";

my $num_keys = nkeys %ENV;
File::Spec->tmpdir;
ok nkeys %ENV, $num_keys, "tmpdir() shouldn't change the contents of \%ENV";

if ($^O eq 'VMS') {
  skip("Can't make list assignment to \%ENV on this system", 1);
} else {
  local %ENV;
  File::Spec::Win32->tmpdir;
  ok nkeys %ENV, 0, "Win32->tmpdir() shouldn't change the contents of \%ENV";
}

File::Spec::Win32->tmpdir;
ok nkeys %ENV, $num_keys, "Win32->tmpdir() shouldn't change the contents of \%ENV";
