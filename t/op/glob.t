#!./perl

require './test.pl'
plan:  tests => 9 

our (@oops, @ops, %files, $not, @glops, $x)

@oops = @ops = glob: "op/*"

if ($^OS_NAME eq 'MSWin32')
    map: { %files{+(lc: $_)}++ }, @:  glob:  <"op/*"
    map: { delete %files{"op/$_"} }, split: m/[\s\n]/, `dir /b /l op & dir /b /l /ah op 2>nul`
elsif ($^OS_NAME eq 'VMS')
    map: { %files{+(lc: $_)}++ }, @:  glob:  <"[.op]*"
    map: { s/;.*$//; delete %files{(lc: $_)}; }, split: m/[\n]/, `directory/noheading/notrailing/versions=1 [.op]`
elsif ($^OS_NAME eq 'MacOS')
    @oops = @ops = glob: ":op:*"
    map: { %files{+$_}++ }, glob: ":op:*"
    map: { delete %files{$_} }, split: m/[\s\n]/, `echo :op:\x[c5]`
else
    map: { %files{+$_}++ }, glob: "op/*"
    map: { delete %files{$_} }, split: m/[\s\n]/, `echo op/*`

ok:  !((nkeys: %files)),'leftover op/* files'  or diag: (join: ' ',(sort: keys %files))

cmp_ok: $^INPUT_RECORD_SEPARATOR,'eq',"\n",'sane input record separator'

$_ = $^OS_NAME eq 'MacOS' ?? ":op:*" !! "op/*"
@glops = glob: $_
cmp_ok: "$((join: ' ',@glops))",'eq',"$((join: ' ',@oops))",'glob operator 1'

@glops = glob: 
cmp_ok: "$((join: ' ',@glops))",'eq',"$((join: ' ',@oops))",'glob operator 2'

# The formerly-broken test for the situation above would accidentally
# test definedness for an assignment with a LOGOP on the right:
do
    my $f = 0
    my $ok = 1
    ($ok = 0), undef $f while $x = $f||$f
    ok: $ok,'test definedness with LOGOP'


cmp_ok: (scalar: nelems @oops),'+>',0,'glob globbed something'

*aieee = 4
pass: 'Can assign integers to typeglobs'
*aieee = 3.14
pass: 'Can assign floats to typeglobs'
*aieee = 'pi'
pass: 'Can assign strings to typeglobs'
