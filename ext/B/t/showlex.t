#!./perl

BEGIN 
    require Config
    require 'test.pl'


$^OUTPUT_AUTOFLUSH = 1
use warnings

use Config
use B::Showlex ()

plan: tests => 14

my $verbose = (nelems @ARGV) # set if ANY ARGS

my $a
my $Is_VMS = $^OS_NAME eq 'VMS'
my $Is_MacOS = $^OS_NAME eq 'MacOS'

my $path = join: " ", map: { qq["-I$_"] }, $^INCLUDE_PATH
$path = '"-I../lib" "-Iperl_root:[lib]"' if $Is_VMS   # gets too long otherwise
my $redir = $Is_MacOS ?? "" !! "2>&1"

my $start_index = (B::PAD_NAME_START_INDEX: )

# v1.01 tests

my ($na,$nb,$nc)	# holds regex-strs
my ($out)	# output, option-flag

sub padrep
    my (@: $varname,$newlex) =  @_
    return ($newlex)
        ?? 'PVNV \(0x[0-9a-fA-F]+\) "\'.$varname.'" = '
        !! "PVNV \\\(0x[0-9a-fA-F]+\\\) \\$varname\n"


for my $newlex ((@: '', '-newlex'))

    $out = runperl:  switches => \(@: "-MO=Showlex,$newlex")
                     prog => 'my ($a,$b)', stderr => 1 
    $na = padrep: '$a',$newlex
    $nb = padrep: '$b',$newlex
    like: $out, qr/4: $na/ms, 'found $a in "my ($a,$b)"'
    like: $out, qr/5: $nb/ms, 'found $b in "my ($a,$b)"'

    print: $^STDOUT, $out if $verbose

    :SKIP do
        skip: "no perlio in this build", 5
            unless Config::config_value: "useperlio"

        our $buf = 'arb startval'
        my $ak = B::Showlex::walk_output : \$buf

        my $walker = B::Showlex::compile:  $newlex, sub (@< @_){my($foo,$bar); 1}
        $walker->& <:
        $na = padrep: '$foo',$newlex
        $nb = padrep: '$bar',$newlex
        like: $buf, qr/$($start_index+1): $na/ms
              'found $foo in "sub { my ($foo,$bar) }"'
        like: $buf, qr/$($start_index+2): $nb/ms, 'found $bar in "sub { my ($foo,$bar) }"'

        print: $^STDOUT, $buf if $verbose

        $ak = B::Showlex::walk_output : \$buf

        my $src = 'sub { my ($scalar,@arr,%hash); 1 }'
        my $sub = eval $src; die: if $^EVAL_ERROR
        $walker = B::Showlex::compile: $sub
        $walker->& <:
        $na = padrep: '$scalar',$newlex
        $nb = padrep: '@arr',$newlex
        $nc = padrep: '%hash',$newlex
        like: $buf, qr/$($start_index+1): $na/ms, 'found $scalar in "'. $src .'"'
        like: $buf, qr/$($start_index+2): $nb/ms, 'found @arr    in "'. $src .'"'
        like: $buf, qr/$($start_index+3): $nc/ms, 'found %hash   in "'. $src .'"'

        print: $^STDOUT, $buf if $verbose

        # fibonacci function under test
        my $asub = sub (@< @_)
            my (@: $self,%< %props)= @_
            my $total
            do # inner block vars
                my (@: @fib)=@: (@: 1,2)
                for my $i (2..9)
                    @fib[$i] = @fib[$i-2] + @fib[$i-1]
                
                for my $i(0..10)
                    $total += $i
        
        $walker = B::Showlex::compile: $asub, $newlex, "-nosp"
        $walker->& <:
        print: $^STDOUT, $buf if $verbose

        $walker = B::Concise::compile: $asub, '-exec'
        $walker->& <:
