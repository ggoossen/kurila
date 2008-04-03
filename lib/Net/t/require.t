#!./perl -w

BEGIN {
    unless (-d 'blib') {
	chdir 't' if -d 't';
	@INC = '../lib';
    }
    if (!eval "require Socket") {
	print "1..0 # no Socket\n"; exit 0;
    }
    if (ord('A') == 193 && !eval "require Convert::EBCDIC") {
        print "1..0 # EBCDIC but no Convert::EBCDIC\n"; exit 0;
    }
}

print "1..1\n";
my $i = 1;
require Net::Config;
require Net::Domain;
require Net::Cmd;
require Net::Netrc;
require Net::FTP;
require Net::SMTP;
require Net::NNTP;
require Net::POP3;
require Net::Time;
print "ok 1\n";


