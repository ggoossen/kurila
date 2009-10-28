BEGIN 
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @:  '../lib' 


# Time-stamp: "2004-12-29 19:59:33 AST"

BEGIN { $^OUTPUT_AUTOFLUSH = 1; (print: $^STDOUT, "1..2\n"); }
use Class::ISA
print: $^STDOUT, "ok 1\n"

@Food::Fishstick::ISA = qw(Food::Fish  Life::Fungus  Chemicals)
@Food::Fish::ISA = qw(Food)
@Food::ISA = qw(Matter)
@Life::Fungus::ISA = qw(Life)
@Chemicals::ISA = qw(Matter)
@Life::ISA = qw(Matter)
@Matter::ISA = qw()

use Class::ISA
my @path = Class::ISA::super_path: 'Food::Fishstick'
my $flat_path = join: ' ', @path
print: $^STDOUT, "#Food::Fishstick path is:\n# $flat_path\n"
print: $^STDOUT
       "Food::Fish Food Matter Life::Fungus Life Chemicals" eq $flat_path ??
           "ok 2\n" !! "fail 2!\n"
