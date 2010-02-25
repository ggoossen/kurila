#!./perl

BEGIN { require './test.pl'; }

plan: 78

#sub is { @_[0] eq @_[1] or die "different: '@_[0]' - '@_[1]'"; };

my (@ary, @foo, @bar, $tmp, $r, $foo, %foo, $F1, $F2, $Etc, %bar, $cnt)

#
# @foo, @bar, and @ary are also used from tie-stdarray after tie-ing them
#

# @ary = @(1,2,3,4,5);
# is(@ary[0], 1);
# is(@ary[4], 5);

# (@ary) = @(6,7,8);
# is(@ary[0], 6);

# (@ary) = @(6,7,8), @(9, 10);
# is(@ary[0], 9);

# __END__
@ary = @: 1,2,3,4,5
is: (join: '', @ary), '12345'

$tmp = @ary[(nelems @ary)-1]; pop @ary
is: $tmp, 5
is: (nelems @ary)-1, 3
is: (join: '', @ary), '1234'

@foo = $@
$r = join: ',', (@:  (nelems @foo)-1, < @foo)
is: $r, "-1"
@foo[+0] = '0'
$r = join: ',', (@:  (nelems @foo)-1, < @foo)
is: $r, "0,0"
@foo[+2] = '2'
$r = join: ',', (@:  (nelems @foo)-1, < @foo)
is: $r, "2,0,,2"
@bar = $@
@bar[+0] = '0'
@bar[+1] = '1'
$r = join: ',', (@:  (nelems @bar)-1, < @bar)
is: $r, "1,0,1"
@bar = $@
$r = join: ',', (@:  (nelems @bar)-1, < @bar)
is: $r, "-1"
@bar[+0] = '0'
$r = join: ',', (@:  (nelems @bar)-1, < @bar)
is: $r, "0,0"
@bar[+2] = '2'
$r = join: ',', (@:  (nelems @bar)-1, < @bar)
is: $r, "2,0,,2"
@bar = $@
@bar[+0] = '0'
$r = join: ',', (@:  (nelems @bar)-1, < @bar)
is: $r, "0,0"
@bar[+2] = '2'
$r = join: ',', (@:  (nelems @bar)-1, < @bar)
is: $r, "2,0,,2"

$foo = 'now is the time'
ok: (scalar: ((@: $F1,$F2,$Etc) = (@: $foo =~ m/^(\S+)\s+(\S+)\s*(.*)/)))
is: $F1, 'now'
is: $F2, 'is'
is: $Etc, 'the time'

$foo = 'lskjdf'
ok: !($cnt = ((@: ?$F1,?$F2,?$Etc) = (@: $foo =~ m/^(\S+)\s+(\S+)\s*(.*)/)))
    or diag: "$cnt $F1:$F2:$Etc"

%foo = %: 'blurfl','dyick','foo','bar','etc.','etc.'
%bar = %:  < %foo 
is: %bar{?'foo'}, 'bar'
%bar = $%
is: %bar{?'foo'}, undef
(@: %< %bar ) = @: < %foo,'how','now'
is: %bar{?'foo'}, 'bar'
is: %bar{?'how'}, 'now'
%bar{[keys %foo]} =  values %foo
is: %bar{?'foo'}, 'bar'
is: %bar{?'how'}, 'now'

@foo = grep:  {m/e/ },(split: ' ','now is the time for all good men to come to')
is: (join: ' ', @foo), 'the time men come'

@foo = grep:  {!m/e/ },(split: ' ','now is the time for all good men to come to')
is: (join: ' ', @foo), 'now is for all good to to'

$foo = join: '', (@: 'a','b','c','d','e','f')[[0..5]]
is: $foo, 'abcdef'

$foo = join: '', (@: 'a','b','c','d','e','f')[[0..1]]
is: $foo, 'ab'

$foo = join: '', (@: 'a','b','c','d','e','f')[[6..6]]
is: $foo, ''

@foo = (@: 'a','b','c','d','e','f')[[(@: 0,2,4)]]
@bar = (@: 'a','b','c','d','e','f')[[(@: 1,3,5)]]
$foo = join: '', (@: < @foo,< @bar)[[0..5]]
is: $foo, 'acebdf'

@foo = @:  'foo', 'bar', 'burbl', 'blah'

# various AASSIGN_COMMON checks (see newASSIGNOP() in op.c)

#curr_test(38);

@foo = @foo
is: ((join: ' ', @foo)), "foo bar burbl blah"				# 38

(@: _,@<@foo) =  @foo
is: ((join: ' ', @foo)), "bar burbl blah"					# 39

@foo = @: 'XXX',< @foo, 'YYY'
is: ((join: ' ', @foo)), "XXX bar burbl blah YYY"				# 40

@foo = ( @foo = qw(foo b\a\r bu\\rbl blah) )
is: ((join: ' ', @foo)), 'foo b\a\r bu\\rbl blah'				# 41

@bar = ( @foo = qw(foo bar) )					# 42
is: ((join: ' ', @foo)), "foo bar"
is: ((join: ' ', @bar)), "foo bar"						# 43

# try the same with local
# XXX tie-stdarray fails the tests involving local, so we use
# different variable names to escape the 'tie'

our @bee = @:  'foo', 'bar', 'burbl', 'blah'
our @bim
do

    local @bee = @bee
    is: ((join: ' ', @bee)), "foo bar burbl blah"				# 44
    do
        local @bee = @: 'XXX',< @bee,'YYY'
        is: ((join: ' ', @bee)), "XXX foo bar burbl blah YYY"		# 46
        do {
        #             local @bee = local(@bee) = @(qw(foo bar burbl blah));
        #             is((join ' ', < @bee), "foo bar burbl blah");		# 47
        #             {
        #                 local (@bim) = local(@bee) = qw(foo bar);
        #                 is((join ' ', < @bee), "foo bar");			# 48
        #                 is((join ' ', < @bim), "foo bar");			# 49
        #             }
        #             is((join ' ', < @bee), "foo bar burbl blah");		# 50
        }
        is: ((join: ' ', @bee)), "XXX foo bar burbl blah YYY"		# 51
    
    is: ((join: ' ', @bee)), "foo bar burbl blah"				# 53


# try the same with my
do
    my @bee = @bee
    is: ((join: ' ',@bee)), "foo bar burbl blah"				# 54
    do
        my (@: _,@<@bee) =  @bee
        is: ((join: ' ',@bee)), "bar burbl blah"				# 55
        do
            my @bee = @: 'XXX',< @bee,'YYY'
            is: ((join: ' ',@bee)), "XXX bar burbl blah YYY"		# 56
            do
                my @bee = @: (my @bee = qw(foo bar burbl blah))
                is: ((join: ' ',@bee)), "foo bar burbl blah"		# 57
                do
                    my @bim = my @bee = qw(foo bar)
                    is: ((join: ' ',@bee)), "foo bar"			# 58
                    is: ((join: ' ',@bim)), "foo bar"			# 59
                
                is: ((join: ' ',@bee)), "foo bar burbl blah"		# 60
            
            is: ((join: ' ',@bee)), "XXX bar burbl blah YYY"		# 61
        
        is: ((join: ' ',@bee)), "bar burbl blah"				# 62
    
    is: ((join: ' ',@bee)), "foo bar burbl blah"				# 63


# try the same with our (except that previous values aren't restored)
do
    our @bee = @bee
    is: ((join: ' ',@bee)), "foo bar burbl blah"
    do
        our (@: _,@<@bee) =  @bee
        is: ((join: ' ',@bee)), "bar burbl blah"
        do
            our @bee = @: 'XXX',< @bee,'YYY'
            is: ((join: ' ',@bee)), "XXX bar burbl blah YYY"
            do
                our @bee = our @bee = qw(foo bar burbl blah)
                is: ((join: ' ',@bee)), "foo bar burbl blah"
                do
                    our @bim = our @bee = qw(foo bar)
                    is: ((join: ' ',@bee)), "foo bar"
                    is: ((join: ' ',@bim)), "foo bar"
                
            
        
    


# make sure reification behaves
my $t = (curr_test: )
sub reify { @_[+1] = $t++; (print: $^STDOUT,  ((join: ' ',@_)), "\n"); }
reify: 'ok'
reify: 'ok'

curr_test: $t

# qw() is no longer a runtime split, it's compiletime.
is: qw(foo bar snorfle)[2], 'snorfle'

@ary = @: 12,23,34,45,56

is: (shift: @ary), 12
is: (pop: @ary), 56
is: (push: @ary,56), 4
is: (unshift: @ary,12), 5

sub foo { "a" }
my @foo= (@: (foo: ))[[(@: 0,0)]]
is: @foo[1], "a"

# bugid #15439 - clearing an array calls destructors which may try
# to modify the array - caused 'Attempt to free unreferenced scalar'

my $got = runperl: 
    prog => q{
                    our @a;
		    sub X::DESTROY { @a = () }
		    @a = @(bless \$%, "X");
		    @a = ();
		}
    stderr => 1
    

do
    local our $TODO = 1
    $got =~ s/\n/ /g
    is: $got, ''


# Test negative and funky indices.


do
    my @a = 0..4
    is: @a[-1], 4
    is: @a[-2], 3
    is: @a[-5], 0
    ok: !defined @a[?-6]

    is: @a[2.1]  , 2
    is: @a[2.9]  , 2
    is: @a[undef], 0
    is: @a["3rd"], 3



do
    my @a
    eval '@a[+-1] = 0'
    like: ($^EVAL_ERROR->message: )
          qr/Required array element -1 could not be created/, "\$a[+-1] = 0"


do
    # Bug #36211
    for ((@: 1,2))
        do
            local our @a
            is: nelems @a, 0
            @a=1..4
        
    


# more tests for AASSIGN_COMMON

do
    our(@: $x,$y,$z) =1..3
    our(@: $y,$z) = @: $x,$y
    is: "$x $y $z", "1 1 2"

do
    our(@: $x,$y,$z) =1..3
    (@: our $y, our $z) = @: $x,$y
    is: "$x $y $z", "1 1 2"


"We're included by lib/Tie/Array/std.t so we need to return something true"
