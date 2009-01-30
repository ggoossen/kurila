BEGIN {
    if(env::var('PERL_CORE')) {
        chdir 't' if -d 't';
        $^INCLUDE_PATH = @( '../lib' );
    }
}

# Time-stamp: "2004-04-27 19:53:22 ADT"

use Test;

my @them;
BEGIN { plan('tests' => 41) };

use Pod::Escapes < qw(:ALL);
ok 1;

eval " binmode(STDOUT, ':utf8') ";

print \*STDOUT, "# Pod::Escapes version $Pod::Escapes::VERSION\n";
print \*STDOUT, "# I'm ", (chr(65) eq 'A') ?? '' !! 'not ', "in ASCII world.\n";
print \*STDOUT, "#\n#------------------------\n#\n";

print \*STDOUT, "# 'A' tests...\n";
ok e2charnum('65'), '65';
ok e2charnum('x41'), '65';
ok e2charnum('x041'), '65';
ok e2charnum('x0041'), '65';
ok e2charnum('x00041'), '65';
ok e2charnum('0101'), '65';
ok e2charnum('00101'), '65';
ok e2charnum('000101'), '65';
ok e2charnum('0000101'), '65';

print \*STDOUT, "# '<' tests...\n";
ok e2charnum('lt'), '60';
ok e2charnum('60'), '60';
ok e2charnum('074'), '60';
ok e2charnum('0074'), '60';
ok e2charnum('00074'), '60';
ok e2charnum('000074'), '60';
ok e2charnum('x3c'), '60';
ok e2charnum('x3C'), '60';
ok e2charnum('x03c'), '60';
ok e2charnum('x003c'), '60';
ok e2charnum('x0003c'), '60';
ok e2charnum('x00003c'), '60';

ok e2charnum('65') ne e2charnum('lt');

print \*STDOUT, "# eacute tests...\n";
ok defined e2charnum('eacute');

print \*STDOUT, "#    eacute is <", e2charnum('eacute'), "> which is code ",
      ord(e2charnum('eacute')), "\n";

ok e2charnum('eacute'), e2charnum('233');
ok e2charnum('eacute'), e2charnum('0351');
ok e2charnum('eacute'), e2charnum('xe9');
ok e2charnum('eacute'), e2charnum('xE9');

print \*STDOUT, "# pi tests...\n";
ok defined e2charnum('pi');

print \*STDOUT, "#    pi is <", e2charnum('pi'), "> which is code ",
      e2charnum('pi'), "\n";

ok e2charnum('pi'), e2charnum('960');
ok e2charnum('pi'), e2charnum('01700');
ok e2charnum('pi'), e2charnum('001700');
ok e2charnum('pi'), e2charnum('0001700');
ok e2charnum('pi'), e2charnum('x3c0');
ok e2charnum('pi'), e2charnum('x3C0');
ok e2charnum('pi'), e2charnum('x03C0');
ok e2charnum('pi'), e2charnum('x003C0');
ok e2charnum('pi'), e2charnum('x0003C0');


print \*STDOUT, "# \%Name2character_number test...\n";

ok nkeys %Name2character_number;
ok defined %Name2character_number{?'eacute'};
ok %Name2character_number{?'lt'} eq '60';

# End
