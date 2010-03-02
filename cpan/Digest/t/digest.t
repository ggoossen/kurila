print: $^STDOUT, "1..2\n"

use Digest

do
    package Digest::Dummy
    our ($VERSION, @ISA)
    $VERSION = 1

    require Digest::base
    @ISA = qw(Digest::base)

    sub new($class, ?$d)
        $d ||= "ooo"
        bless: \(%: d => $d ), $class

    sub add(...) {}
    sub digest($self) $self->{?d}

my $d
$d = Digest->new: "Dummy"
print: $^STDOUT, "not " unless $d->digest eq "ooo"
print: $^STDOUT, "ok 1\n"

%Digest::MMAP{+"Dummy-24"} = \@: \(@: "NotThere"), "NotThereEither", \(@: "Digest::Dummy", 24)
$d = Digest->new: "Dummy-24"
print: $^STDOUT, "not " unless $d->digest eq "24"
print: $^STDOUT, "ok 2\n"


