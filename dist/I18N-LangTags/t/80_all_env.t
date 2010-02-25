
use Test::More
# Time-stamp: "2004-07-01 14:33:50 ADT"
BEGIN { (plan: tests => 12); }
use I18N::LangTags::Detect v1.01
print: $^STDOUT, "# Hi there...\n"
ok: 1

print: $^STDOUT, "# Using I18N::LangTags::Detect v$I18N::LangTags::Detect::VERSION\n"

print: $^STDOUT, "# Make sure we can assign to ENV entries\n"
       "# (Otherwise we can't run the subsequent tests)...\n"
(env::var: 'MYORP'   ) = 'Zing';          is: (env::var: 'MYORP'), 'Zing'
(env::var: 'SWUZ'    ) = 'KLORTHO HOOBOY'; is: (env::var: 'SWUZ'), 'KLORTHO HOOBOY'

(env::var: 'MYORP') = undef
(env::var: 'SWUZ') = undef

sub j { "[" . (join: ' ', (map: { "\"$_\"" }, @_)) . "]" ;}

sub show
    print: $^STDOUT, "#  (Seeing \{", (join: ' ', (map:  {(dump::view: $_) }, @_)), "\} at line ", (@: caller)[2], ")\n"
    (printenv: )
    return @_[0] || ''

sub printenv
    print: $^STDOUT, "# ENV:\n"
    foreach my $k ((sort: { $a cmp $b }, (env::keys: )))
        my $p = (env::var: $k);  $p =~ s/\n/\n#/g
        print: $^STDOUT, "#   [$k] = [$p]\n" 
    print: $^STDOUT, "# [end of ENV]\n#\n"


(env::var: 'IGNORE_WIN32_LOCALE' ) = 1 # a hack, just for testing's sake.


print: $^STDOUT, "# Test LANGUAGE...\n"
(env::var: 'REQUEST_METHOD' ) = ''
(env::var: 'LANGUAGE'       ) = 'Eu-MT'
(env::var: 'LC_ALL'         ) = ''
(env::var: 'LC_MESSAGES'    ) = ''
(env::var: 'LANG'           ) = ''
is: (show:  (j: <      (I18N::LangTags::Detect::detect: ))), q{["eu-mt"]}


print: $^STDOUT, "# Test LC_ALL...\n"
(env::var: 'REQUEST_METHOD' ) = ''
(env::var: 'LANGUAGE'       ) = ''
(env::var: 'LC_ALL'         ) = 'Eu-MT'
(env::var: 'LC_MESSAGES'    ) = ''
(env::var: 'LANG'           ) = ''

is: (show:  (j: <      (I18N::LangTags::Detect::detect: ))), q{["eu-mt"]}

print: $^STDOUT, "# Test LC_MESSAGES...\n"
(env::var: 'REQUEST_METHOD' ) = ''
(env::var: 'LANGUAGE'       ) = ''
(env::var: 'LC_ALL'         ) = ''
(env::var: 'LC_MESSAGES'    ) = 'Eu-MT'
(env::var: 'LANG'           ) = ''

is: (show:  (j: <      (I18N::LangTags::Detect::detect: ))), q{["eu-mt"]}


print: $^STDOUT, "# Test LANG...\n"
(env::var: 'REQUEST_METHOD' ) = ''
(env::var: 'LANGUAGE'       ) = ''
(env::var: 'LC_ALL'         ) = ''
(env::var: 'LC_MESSAGES'    ) = ''
(env::var: 'LANG'           ) = 'Eu_MT'

is: (show:  (j: <      (I18N::LangTags::Detect::detect: ))), q{["eu-mt"]}



print: $^STDOUT, "# Test LANG...\n"
(env::var: 'LANGUAGE' ) = ''
(env::var: 'REQUEST_METHOD' ) = ''
(env::var: 'LC_ALL' ) = ''
(env::var: 'LC_MESSAGES' ) = ''
(env::var: 'LANG'     ) = 'Eu_MT'

is: (show:  (j: <      (I18N::LangTags::Detect::detect: ))), q{["eu-mt"]}




print: $^STDOUT, "# Test HTTP_ACCEPT_LANGUAGE...\n"
(env::var: 'REQUEST_METHOD'       ) = 'GET'
(env::var: 'HTTP_ACCEPT_LANGUAGE' ) = 'eu-MT'
is: (show:  (j: <      (I18N::LangTags::Detect::detect: ))), q{["eu-mt"]}


(env::var: 'HTTP_ACCEPT_LANGUAGE' ) = 'x-plorp, zaz, eu-MT, i-klung'
is: (show:  (j: <      (I18N::LangTags::Detect::detect: ))), qq{["x-plorp" "i-plorp" "zaz" "eu-mt" "i-klung" "x-klung"]}

(env::var: 'HTTP_ACCEPT_LANGUAGE' ) = 'x-plorp, zaz, eU-Mt, i-klung'
is: (show:  (j: <      (I18N::LangTags::Detect::detect: ))), qq{["x-plorp" "i-plorp" "zaz" "eu-mt" "i-klung" "x-klung"]}




print: $^STDOUT, "# Byebye!\n"
ok: 1

