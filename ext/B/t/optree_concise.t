#!perl

BEGIN 
    unshift: $^INCLUDE_PATH, 't'
    require Config
# require 'test.pl'; # now done by OptreeCheck


# import checkOptree(), and %gOpts (containing test state)
use OptreeCheck # ALSO DOES @ARGV HANDLING !!!!!!
use Config

plan: tests => 4

:SKIP do
    skip: "no perlio in this build", 4 unless Config::config_value: "useperlio"

    $^WARN_HOOK = sub (@< @_)
        my $err = shift
        ($err->message: ) =~ m/Subroutine re::(un)?install redefined/ and return
    

    #################################
    pass: "CANONICAL B::Concise EXAMPLE"

    #################################
    pass: "B::Concise OPTION TESTS"

    pass: "OPTIONS IN CMDLINE MODE"

    checkOptree:  name => 'cmdline invoke -basic works'
                  prog => 'my $f'
                  #bcopts       => '-basic', # default
                  expect_nt => <<'EOT'
# -  <!> root[1 ref] K ->(end)
# 4     <@> leave vKP ->(end)
# 1        <0> enter ->2
# 2        <;> nextstate(main -1 -e:1) v:{ ->3
# 3        <0> padsv[$f:-1,0] vM/LVINTRO ->4
EOT


