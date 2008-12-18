
use Test;
# Time-stamp: "2004-07-01 14:33:50 ADT"
BEGIN { plan tests => 12; }
use I18N::LangTags::Detect v1.01;
print "# Hi there...\n";
ok 1;

print "# Using I18N::LangTags::Detect v$I18N::LangTags::Detect::VERSION\n";

print "# Make sure we can assign to ENV entries\n",
      "# (Otherwise we can't run the subsequent tests)...\n";
env::set_var('MYORP')   = 'Zing';          ok env::var('MYORP'), 'Zing';
env::set_var('SWUZ')   = 'KLORTHO HOOBOY'; ok env::var('SWUZ'), 'KLORTHO HOOBOY';

delete %ENV{'MYORP'};
delete %ENV{'SWUZ'};

sub j { "[" . join(' ', map "\"$_\"", @_) . "]" ;}

sub show {
  print "#  (Seeing \{", join(' ', map(dump::view($_), @_)), "\} at line ", @(caller)[2], ")\n";
  printenv();
  return @_[0] || '';
}
sub printenv {
  print "# ENV:\n";
  foreach my $k (sort keys %ENV) {
    my $p = env::var($k);  $p =~ s/\n/\n#/g;
    print "#   [$k] = [$p]\n"; }
  print "# [end of ENV]\n#\n";
}

env::set_var('IGNORE_WIN32_LOCALE') = 1; # a hack, just for testing's sake.


print "# Test LANGUAGE...\n";
env::set_var('REQUEST_METHOD') = '';
env::set_var('LANGUAGE')       = 'Eu-MT';
env::set_var('LC_ALL')         = '';
env::set_var('LC_MESSAGES')    = '';
env::set_var('LANG')           = '';
ok show( j <      I18N::LangTags::Detect::detect()), q{["eu-mt"]};


print "# Test LC_ALL...\n";
env::set_var('REQUEST_METHOD') = '';
env::set_var('LANGUAGE')       = '';
env::set_var('LC_ALL')         = 'Eu-MT';
env::set_var('LC_MESSAGES')    = '';
env::set_var('LANG')           = '';

ok show( j <      I18N::LangTags::Detect::detect()), q{["eu-mt"]};

print "# Test LC_MESSAGES...\n";
env::set_var('REQUEST_METHOD') = '';
env::set_var('LANGUAGE')       = '';
env::set_var('LC_ALL')         = '';
env::set_var('LC_MESSAGES')    = 'Eu-MT';
env::set_var('LANG')           = '';

ok show( j <      I18N::LangTags::Detect::detect()), q{["eu-mt"]};


print "# Test LANG...\n";
env::set_var('REQUEST_METHOD') = '';
env::set_var('LANGUAGE')       = '';
env::set_var('LC_ALL')         = '';
env::set_var('LC_MESSAGES')    = '';
env::set_var('LANG')           = 'Eu_MT';

ok show( j <      I18N::LangTags::Detect::detect()), q{["eu-mt"]};



print "# Test LANG...\n";
env::set_var('LANGUAGE') = '';
env::set_var('REQUEST_METHOD') = '';
env::set_var('LC_ALL') = '';
env::set_var('LC_MESSAGES') = '';
env::set_var('LANG')     = 'Eu_MT';

ok show( j <      I18N::LangTags::Detect::detect()), q{["eu-mt"]};




print "# Test HTTP_ACCEPT_LANGUAGE...\n";
env::set_var('REQUEST_METHOD')       = 'GET';
env::set_var('HTTP_ACCEPT_LANGUAGE') = 'eu-MT';
ok show( j <      I18N::LangTags::Detect::detect()), q{["eu-mt"]};


env::set_var('HTTP_ACCEPT_LANGUAGE') = 'x-plorp, zaz, eu-MT, i-klung';
ok show( j <      I18N::LangTags::Detect::detect()), qq{["x-plorp" "i-plorp" "zaz" "eu-mt" "i-klung" "x-klung"]};

env::set_var('HTTP_ACCEPT_LANGUAGE') = 'x-plorp, zaz, eU-Mt, i-klung';
ok show( j <      I18N::LangTags::Detect::detect()), qq{["x-plorp" "i-plorp" "zaz" "eu-mt" "i-klung" "x-klung"]};




print "# Byebye!\n";
ok 1;

