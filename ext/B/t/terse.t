#!./perl

use Test::More tests => 15

use B::Terse

# indent should return a string indented four spaces times the argument
is:  (B::Terse::indent: 2), ' ' x 8, 'indent with an argument' 
is:  (B::Terse::indent: ), '', 'indent with no argument' 

# this should fail without a reference
try { (B::Terse::terse: 'scalar') }
like:  $^EVAL_ERROR->{?description}, qr/not a reference/, 'terse() fed bad parameters' 

# now point it at a sub and see what happens
sub foo {}

my $sub
try{ $sub = (B::Terse::compile: '', 'foo') }
is:  $^EVAL_ERROR, '', 'compile()' 
ok:  exists $sub->&, 'valid subref back from compile()' 

# and point it at a real sub and hope the returned ops look alright
my $out = ""
open: my $ouf_fh, '>>', \$out or die: 
B::Concise::walk_output: $ouf_fh
$sub = B::Terse::compile: '', 'bar'
$sub->& <:

# now build some regexes that should match the dumped ops
my (@: $hex, $op) = @: '\(0x[a-f0-9]+\)', '\s+\w+'
my %ops = %+: map: { %: $_ => qr/$_ $hex$op/ },
                       qw ( OP     COP LOOP PMOP UNOP BINOP LOGOP LISTOP PVOP ) 

# split up the output lines into individual ops (terse is, well, terse!)
# use an array here so $_ is modifiable
my @lines = (split: m/\n+/, $out); $out = ""
foreach ( @lines)
    next unless m/\S/
    s/^\s+//
    if (m/^([A-Z]+)\s+/)
        my $op = $1
        next unless exists %ops{$op}
        like:  $_, %ops{?$op}, "$op " 
        s/%ops{?$op}//
        delete %ops{$op}
        redo if $_
    


warn: "# didn't find " . (join: ' ', keys %ops) if %ops

# XXX:
# this tries to get at all tersified optypes in B::Terse
# if you can think of a way to produce AV, NULL, PADOP, or SPECIAL,
# add it to the regex above too. (PADOPs are currently only produced
# under ithreads, though).
#
our ($a, $b)
sub bar
    # OP SVOP COP IV here or in sub definition
    my @bar = @: 1, 2, 3

    # got a GV here
    my $foo = $a + $b

    # NV here
    $a = 1.234

    # this is awful, but it gives a PMOP
    our @ary = split: '', $foo

    # PVOP, LOOP
    :LOOP for (1 .. 10)
        last LOOP if $_ % 2
    

    # make a PV
    $foo = "a string"

    # make an OP_SUBSTCONT
    $foo =~ s/(a)/$1/


# Schwern's example of finding an RV
my $path = join: " ", map: { qq["-I$_"] }, $^INCLUDE_PATH
$path = '-I::lib -MMac::err=unix' if $^OS_NAME eq 'MacOS'
my $redir = $^OS_NAME eq 'MacOS' ?? '' !! "2>&1"
my $items = qx{$^EXECUTABLE_NAME $path "-MO=Terse" -e "print: \$^STDOUT, \\42" $redir}
like:  $items, qr/IV $hex \\42/, 'RV (but now stored in an IV)' 

package TieOut

sub TIEHANDLE
    bless:  \(my $out), @_[0] 


sub PRINT
    my $self = shift
    $self->$ .= join: '', @_


sub PRINTF
    my $self = shift
    $self->$ .= sprintf: nelems @_


sub read
    my $self = shift
    return substr: $self->$, 0, (length: $self->$), ''

