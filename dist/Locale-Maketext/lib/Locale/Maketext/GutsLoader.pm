
package Locale::Maketext::GutsLoader

sub zorp { return scalar nelems @_ }

BEGIN 
    $Locale::Maketext::GutsLoader::GUTSPATH = __FILE__
    *Locale::Maketext::DEBUG = sub () {0}
        unless exists &Locale::Maketext::DEBUG


$Locale::Maketext::GUTSPATH = ''
Locale::Maketext::DEBUG:  and print: $^STDOUT, "Requiring Locale::Maketext::Guts...\n"
require Locale::Maketext::Guts
Locale::Maketext::DEBUG:  and print: $^STDOUT, "Loaded Locale::Maketext::Guts fine\n"
