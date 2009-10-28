
# Time-stamp: "2004-04-27 19:53:22 ADT"

use Test::More

my @them
BEGIN { (plan: 'tests' => 41) };

use Pod::Escapes < qw(:ALL)
ok: 1

eval " binmode(STDOUT, ':utf8') "

print: $^STDOUT, "# Pod::Escapes version $Pod::Escapes::VERSION\n"
print: $^STDOUT, "# I'm ", ((chr: 65) eq 'A') ?? '' !! 'not ', "in ASCII world.\n"
print: $^STDOUT, "#\n#------------------------\n#\n"

print: $^STDOUT, "# 'A' tests...\n"
is: (e2charnum: '65'), '65'
is: (e2charnum: 'x41'), '65'
is: (e2charnum: 'x041'), '65'
is: (e2charnum: 'x0041'), '65'
is: (e2charnum: 'x00041'), '65'
is: (e2charnum: '0101'), '65'
is: (e2charnum: '00101'), '65'
is: (e2charnum: '000101'), '65'
is: (e2charnum: '0000101'), '65'

print: $^STDOUT, "# '<' tests...\n"
is: (e2charnum: 'lt'), '60'
is: (e2charnum: '60'), '60'
is: (e2charnum: '074'), '60'
is: (e2charnum: '0074'), '60'
is: (e2charnum: '00074'), '60'
is: (e2charnum: '000074'), '60'
is: (e2charnum: 'x3c'), '60'
is: (e2charnum: 'x3C'), '60'
is: (e2charnum: 'x03c'), '60'
is: (e2charnum: 'x003c'), '60'
is: (e2charnum: 'x0003c'), '60'
is: (e2charnum: 'x00003c'), '60'

ok: (e2charnum: '65') ne e2charnum: 'lt'

print: $^STDOUT, "# eacute tests...\n"
ok: defined e2charnum: 'eacute'

print: $^STDOUT, "#    eacute is <", (e2charnum: 'eacute'), "> which is code "
       (ord: (e2charnum: 'eacute')), "\n"

is: (e2charnum: 'eacute'), e2charnum: '233'
is: (e2charnum: 'eacute'), e2charnum: '0351'
is: (e2charnum: 'eacute'), e2charnum: 'xe9'
is: (e2charnum: 'eacute'), e2charnum: 'xE9'

print: $^STDOUT, "# pi tests...\n"
ok: defined e2charnum: 'pi'

print: $^STDOUT, "#    pi is <", (e2charnum: 'pi'), "> which is code "
       (e2charnum: 'pi'), "\n"

is: (e2charnum: 'pi'), e2charnum: '960'
is: (e2charnum: 'pi'), e2charnum: '01700'
is: (e2charnum: 'pi'), e2charnum: '001700'
is: (e2charnum: 'pi'), e2charnum: '0001700'
is: (e2charnum: 'pi'), e2charnum: 'x3c0'
is: (e2charnum: 'pi'), e2charnum: 'x3C0'
is: (e2charnum: 'pi'), e2charnum: 'x03C0'
is: (e2charnum: 'pi'), e2charnum: 'x003C0'
is: (e2charnum: 'pi'), e2charnum: 'x0003C0'


print: $^STDOUT, "# \%Name2character_number test...\n"

ok: nkeys %Name2character_number
ok: defined %Name2character_number{?'eacute'}
ok: %Name2character_number{?'lt'} eq '60'

# End
