use strict;
use Test;

# Grab all of the plain routines from File::Spec
use File::Spec;
use File::Spec::Win32;

plan tests => 3;

ok 1, 1, "Loaded";

my $num_keys = keys %ENV;
File::Spec->tmpdir;
ok scalar keys %ENV, $num_keys, "tmpdir() shouldn't change the contents of %ENV";

File::Spec::Win32->tmpdir;
ok scalar keys %ENV, $num_keys, "Win32->tmpdir() shouldn't change the contents of %ENV";
