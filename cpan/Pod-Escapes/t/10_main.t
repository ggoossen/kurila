
# Time-stamp: "2004-05-07 15:43:11 ADT"

use Test::More
use utf8

my @them
BEGIN { (plan: 'tests' => 63) };

use Pod::Escapes < qw(:ALL)
ok: 1

eval " binmode(STDOUT, ':utf8') "

print: $^STDOUT, "# Pod::Escapes version $Pod::Escapes::VERSION\n"
print: $^STDOUT, "# I'm ", ((chr: 65) eq 'A') ?? '' !! 'not ', "in ASCII world.\n"
print: $^STDOUT, "#\n#------------------------\n#\n"

foreach my $quotie (qw( \n \r \cm \cj \t \f \b \a \e ))
    my $val = eval "\"$quotie\""
    if($^EVAL_ERROR)
        (ok: 0)
        print: $^STDOUT, "# Error in evalling quotie \"$quotie\"\n"
    elsif(!defined $val)
        (ok: 0)
        print: $^STDOUT, "# \"$quotie\" is undef!?\n"
    else 
        ok: 1
        print: $^STDOUT, "# \"$quotie\" is ", (ord: $val), "\n"
    


print: $^STDOUT, "#\n#------------------------\n#\n"

print: $^STDOUT, "# 'A' tests...\n"
is: (e2char: '65'), 'A'
is: (e2char: 'x41'), 'A'
is: (e2char: 'x041'), 'A'
is: (e2char: 'x0041'), 'A'
is: (e2char: 'x00041'), 'A'
is: (e2char: '0101'), 'A'
is: (e2char: '00101'), 'A'
is: (e2char: '000101'), 'A'
is: (e2char: '0000101'), 'A'

print: $^STDOUT, "# '<' tests...\n"
is: (e2char: 'lt'), '<'
is: (e2char: '60'), '<'
is: (e2char: '074'), '<'
is: (e2char: '0074'), '<'
is: (e2char: '00074'), '<'
is: (e2char: '000074'), '<'

is: (e2char: 'x3c'), '<'
is: (e2char: 'x3C'), '<'
is: (e2char: 'x03c'), '<'
is: (e2char: 'x003c'), '<'
is: (e2char: 'x0003c'), '<'
is: (e2char: 'x00003c'), '<'
is: (e2char: '0x3c'), '<'
is: (e2char: '0x3C'), '<'
is: (e2char: '0x03c'), '<'
is: (e2char: '0x003c'), '<'
is: (e2char: '0x0003c'), '<'
is: (e2char: '0x00003c'), '<'

ok: (e2char: '65') ne e2char: 'lt'

print: $^STDOUT, "# eacute tests...\n"
ok: defined e2char: 'eacute'

print: $^STDOUT, "#    eacute is <", (e2char: 'eacute'), "> which is code "
       (ord: (e2char: 'eacute')), "\n"

is: (e2char: 'eacute'), e2char: '233'
is: (e2char: 'eacute'), e2char: '0351'
is: (e2char: 'eacute'), e2char: 'xe9'
is: (e2char: 'eacute'), e2char: 'xE9'

print: $^STDOUT, "# pi tests...\n"
ok: defined e2char: 'pi'

print: $^STDOUT, "#    pi is <", (e2char: 'pi'), "> which is code "
       (ord: (e2char: 'pi')), "\n"

is: (e2char: 'pi'), e2char: '960'
is: (e2char: 'pi'), e2char: '01700'
is: (e2char: 'pi'), e2char: '001700'
is: (e2char: 'pi'), e2char: '0001700'
is: (e2char: 'pi'), e2char: 'x3c0'
is: (e2char: 'pi'), e2char: 'x3C0'
is: (e2char: 'pi'), e2char: 'x03C0'
is: (e2char: 'pi'), e2char: 'x003C0'
is: (e2char: 'pi'), e2char: 'x0003C0'


print: $^STDOUT, "# various hash tests...\n"

ok: nkeys %Name2character
ok: defined %Name2character{?'eacute'}
ok: %Name2character{?'lt'} eq '<'

ok: nkeys %Latin1Code_to_fallback
ok: defined %Latin1Code_to_fallback{?233}

ok: nkeys %Latin1Char_to_fallback
ok: defined %Latin1Char_to_fallback{?(chr: 233)}

ok: nkeys %Code2USASCII
ok: defined %Code2USASCII{?65}
ok: %Code2USASCII{?65} eq 'A'


