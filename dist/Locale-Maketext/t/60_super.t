
use Test::More

# use a BEGIN block so we print our plan before MyModule is loaded
BEGIN { (plan: tests => 3) }

ok: 1
print: $^STDOUT, "# Locale::Maketext version $Locale::Maketext::VERSION\n"

#sub Locale::Maketext::DEBUG () {10};
use Locale::Maketext ()
do { package  Whunk::L10N;
    our @ISA = (@:   'Locale::Maketext' );
    our %Lexicon = (%: "hello" => "SROBLR!");
}
do { package  Whunk::L10N::en;
    our @ISA = (@:   'Whunk::L10N' );
    our %Lexicon = (%: "hello" => "HI AND STUFF!");
}
do {  package  Whunk::L10N::zh_tw;
    our @ISA = (@:   'Whunk::L10N' );
    our %Lexicon = (%: "hello" => "NIHAU JOE!");
}

(env::var: 'REQUEST_METHOD' ) = 'GET'
(env::var: 'HTTP_ACCEPT_LANGUAGE' ) = 'en-US, zh-TW'

my $x = Whunk::L10N->get_handle
print: $^STDOUT, "# LH object: $((dump::view: $x))\n"
is: ($x->maketext: 'hello'), "HI AND STUFF!"
print: $^STDOUT, "# OK bye\n"
ok: 1
