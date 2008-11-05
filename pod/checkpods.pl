#! perl
# From roderick@gate.netThu Sep  5 17:19:30 1996
# Date: Thu, 05 Sep 1996 00:11:22 -0400
# From: Roderick Schertler <roderick@gate.net>
# To: perl5-porters@africa.nicoh.com
# Subject: POD lines with only spaces
#
# There are some places in the documentation where a POD directive is
# ignored because the line before it contains whitespace (and so the
# directive doesn't start a paragraph).  This patch adds a way to check
# for these to the pod Makefile (though it isn't made part of the build
# process, which would be a good idea), and fixes those places where the
# problem currently exists.
#
#  Version 1.00  Original.
#  Version 1.01  Andy Dougherty <doughera@lafayette.edu>
#    Trivial modifications to output format for easier auto-parsing
#    Broke it out as a separate function to avoid nasty
#	Make/Shell/Perl quoting problems, and also to make it easier
#	to grow.  Someone will probably want to rewrite in terms of
#	some sort of Pod::Checker module.  Or something.  Consider this
#	a placeholder for the future.
#  Version 1.02  Roderick Schertler <roderick@argon.org>
#	Check for pod directives following any kind of unempty line, not
#	just lines of whitespace.

my @directive = qw(head1 head2 item over back cut pod for begin end);
my %directive;
%directive{[@directive]} = (1) x @directive;

my $exit = my $last_unempty = 0;
while (~< *ARGV) {
    s/(\012|\015\012|\015)$//;
    if (m/^=(\S+)/ && %directive{$1} && $last_unempty) {
	printf '%s: line %5d, no blank line preceding directive =%s' . "\n",
		$ARGV, $., $1;
	$exit = 1;
    }
    $last_unempty = ($_ ne '');
    if (eof) {
	close(ARGV);
	$last_unempty = 0;
    }
}
exit $exit
