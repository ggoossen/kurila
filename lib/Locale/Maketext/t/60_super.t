
use strict;
use Test;

# use a BEGIN block so we print our plan before MyModule is loaded
BEGIN { plan tests => 3 }

ok 1;
print "# Locale::Maketext version $Locale::Maketext::VERSION\n";

#sub Locale::Maketext::DEBUG () {10};
use Locale::Maketext ();
{ package  Whunk::L10N;
  our @ISA = @(  'Locale::Maketext' );
  our %Lexicon = %("hello" => "SROBLR!");
}
{ package  Whunk::L10N::en;
  our @ISA = @(  'Whunk::L10N' );
  our %Lexicon = %("hello" => "HI AND STUFF!");
}
{  package  Whunk::L10N::zh_tw;
   our @ISA = @(  'Whunk::L10N' );
   our %Lexicon = %("hello" => "NIHAU JOE!");
}

%ENV{'REQUEST_METHOD'} = 'GET';
%ENV{'HTTP_ACCEPT_LANGUAGE'} = 'en-US, zh-TW';

my $x = Whunk::L10N->get_handle;
print "# LH object: {dump::view($x)}\n";
ok $x->maketext('hello'), "HI AND STUFF!";
print "# OK bye\n";
ok 1;
