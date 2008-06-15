#!./perl

my $module = shift;

# 'require open' confuses Perl, so we use instead.
eval "use $module ();";
if( $@ ) {
    print "not ";
    warn "# require failed with {dump::view( <$@->message)}\n";
}
print "ok - $module\n";


