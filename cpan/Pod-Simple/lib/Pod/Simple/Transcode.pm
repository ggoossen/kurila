
package Pod::Simple::Transcode


our @ISA

BEGIN 
    if(exists &DEBUG) {;} # Okay
        elsif( exists &Pod::Simple::DEBUG ) { *DEBUG = \&Pod::Simple::DEBUG; }
    else { *DEBUG = sub () {0}; }


foreach my $class (@:
  'Pod::Simple::TranscodeSmart'
  'Pod::Simple::TranscodeDumb'
  ''
    )
    $class or die: "Couldn't load any encoding classes"
    DEBUG: and print: $^STDOUT, "About to try loading $class...\n"
    eval "require $class;"
    if($^EVAL_ERROR)
        DEBUG: and print: $^STDOUT, "Couldn't load $class: $($^EVAL_ERROR->message)\n"
    else
        DEBUG: and print: $^STDOUT, "OK, loaded $class.\n"
        @ISA = @: $class
        last
    


sub _blorp { return; } # just to avoid any "empty class" warning

1
__END__


