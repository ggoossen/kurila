#!/usr/bin/perl


print $^STDOUT, "1..1\n";

if (!env::var('TEST_SIGNATURE')) {
    print $^STDOUT, "ok 1 # skip set the environment variable TEST_SIGNATURE to enable this test\n";
}
elsif (!-s 'SIGNATURE') {
    print $^STDOUT, "ok 1 # skip No signature file found\n";
}
elsif (!try { require Module::Signature; 1 }) {
    print $^STDOUT, "ok 1 # skip ",
	    "Next time around, consider install Module::Signature, ",
	    "so you can verify the integrity of this distribution.\n";
}
elsif (!try { require Socket; Socket::inet_aton('pgp.mit.edu') }) {
    print $^STDOUT, "ok 1 # skip ",
	    "Cannot connect to the keyserver\n";
}
else {
    (Module::Signature::verify() == Module::Signature::SIGNATURE_OK())
	or print $^STDOUT, "not ";
    print $^STDOUT, "ok 1 # Valid signature\n";
}

__END__
