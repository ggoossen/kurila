 # Time-stamp: "2004-10-06 23:07:06 ADT"
use Test::More
BEGIN { (plan: tests => 22) };
BEGIN { (ok: 1) }
use I18N::LangTags (':ALL')

print: $^STDOUT, "#  Loaded from ", $^INCLUDED{?'I18N/LangTags.pm'} || "??", "\n"

is: lc (locale2language_tag: 'en'),    'en'
is: lc (locale2language_tag: 'en_US'),    'en-us'
is: lc (locale2language_tag: 'en_US.ISO8859-1'),    'en-us'
is: (lc: (locale2language_tag: 'C')||''),    ''
is: (lc: (locale2language_tag: 'POSIX')||''), ''


is: lc (locale2language_tag: 'eu_mt'),           'eu-mt'
is: lc (locale2language_tag: 'eu'),              'eu'
is: lc (locale2language_tag: 'it'),              'it'
is: lc (locale2language_tag: 'it_IT'),           'it-it'
is: lc (locale2language_tag: 'it_IT.utf8'),      'it-it'
is: lc (locale2language_tag: 'it_IT.utf8@euro'), 'it-it'
is: lc (locale2language_tag: 'it_IT@euro'),      'it-it'


is: lc (locale2language_tag: 'zh_CN.gb18030'), 'zh-cn'
is: lc (locale2language_tag: 'zh_CN.gbk'),     'zh-cn'
is: lc (locale2language_tag: 'zh_CN.utf8'),    'zh-cn'
is: lc (locale2language_tag: 'zh_HK'),         'zh-hk'
is: lc (locale2language_tag: 'zh_HK.utf8'),    'zh-hk'
is: lc (locale2language_tag: 'zh_TW'),         'zh-tw'
is: lc (locale2language_tag: 'zh_TW.euctw'),   'zh-tw'
is: lc (locale2language_tag: 'zh_TW.utf8'),    'zh-tw'

print: $^STDOUT, "# So there!\n"
ok: 1
