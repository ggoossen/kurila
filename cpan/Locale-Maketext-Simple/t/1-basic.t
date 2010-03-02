
use Test::More

BEGIN 
    plan: tests => 9
    $^INCLUDED{+'Locale/Maketext/Lexicon.pm'} = __FILE__
    $Locale::Maketext::Lexicon::VERSION = 0


use Locale::Maketext::Simple
ok: Locale::Maketext::Simple->VERSION
is: (loc: "Just [_1] Perl [_2]", < qw(another hacker)), "Just another Perl hacker"

do
    local $^WARNING = undef # shuts up 'redefined' warnings
    Locale::Maketext::Simple->reload_loc
    Locale::Maketext::Simple->import: Style => 'gettext'


is: (loc: "Just \%1 Perl \%2", < qw(another hacker)), "Just another Perl hacker"
ok: (loc_lang: 'fr')
is: (loc: "Just \%quant(\%1,Perl hacker)", 1), "Just 1 Perl hacker"
is: (loc: "Just \%quant(\%1,Perl hacker)", 2), "Just 2 Perl hackers"
is: (loc: "Just \%quant(\%1,Mad skill,Mad skillz)", 3), "Just 3 Mad skillz"
is: (loc: "Error \%tense(\%1,present)", 'uninstall'), "Error uninstalling"
is: (loc: "Error \%tense(uninstall,present)"), "Error uninstalling"
