
package Locale::Maketext::GutsLoader;
use strict;
sub zorp { return scalar nelems @_ }

BEGIN {
  $Locale::Maketext::GutsLoader::GUTSPATH = __FILE__;
  *Locale::Maketext::DEBUG = sub () {0}
   unless defined &Locale::Maketext::DEBUG;
}

$Locale::Maketext::GUTSPATH = '';
Locale::Maketext::DEBUG and print "Requiring Locale::Maketext::Guts...\n";
require Locale::Maketext::Guts;
Locale::Maketext::DEBUG and print "Loaded Locale::Maketext::Guts fine\n";

1;

