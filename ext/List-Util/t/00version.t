#!./perl

use Scalar::Util ()
use List::Util ()
use Test::More tests => 1

is:  $Scalar::Util::VERSION, $List::Util::VERSION, "VERSION mismatch"


