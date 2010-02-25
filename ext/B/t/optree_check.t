#!perl

BEGIN 
    unshift: $^INCLUDE_PATH, 't'


use OptreeCheck

=head1 OptreeCheck selftest harness

This file is primarily to test services of OptreeCheck itself, ie
checkOptree().  %gOpts provides test-state info, it is 'exported' into
main::

doing use OptreeCheck runs import(), which processes @ARGV to process
cmdline args in 'standard' way across all clients of OptreeCheck.

=cut

our %gOpts

my $tests = 12 + 16 * %gOpts{?selftest}	# pass()s + $#tests
plan: tests => $tests

:SKIP do
    skip: "no perlio in this build", $tests
        unless Config::config_value: "useperlio"

    pass: "REGEX TEST HARNESS SELFTEST"

    checkOptree:  name  => "bare minimum opcode search"
                  bcopts        => '-exec'
                  code  => sub (@< @_) {my $a}
                  noanchors     => 1 # unanchored match
                  expect        => 'leavesub'
                  expect_nt     => 'leavesub'

    checkOptree:  name  => "found print opcode"
                  bcopts        => '-exec'
                  code  => sub (@< @_) {(print: $^STDOUT, 1)}
                  noanchors     => 1 # unanchored match
                  expect        => 'print'
                  expect_nt     => 'leavesub'

    checkOptree:  name  => 'test skip itself'
                  skip  => 'this is skip-reason'
                  bcopts        => '-exec'
                  code  => sub (@< @_) {(print: $^STDOUT, 1)}
                  expect        => 'dont-care, skipping'
                  expect_nt     => 'this insures failure'

    # This test 'unexpectedly succeeds', but that is "expected".  Theres
    # no good way to expect a successful todo, and inducing a failure
    # causes the harness to print verbose errors, which is NOT helpful.

    (checkOptree:  name  => 'test todo itself'
                   todo  => "your excuse here ;-)"
                   bcopts        => '-exec'
                   code  => sub (@< @_) {(print: $^STDOUT, 1)}
                   noanchors     => 1 # unanchored match
                   expect        => 'print'
                   expect_nt     => 'print') if 0

    checkOptree:  name  => 'impossible match, remove skip to see failure'
                  todo  => "see! it breaks!"
                  skip  => 'skip the failure'
                  code  => sub (@< @_) {(print: $^STDOUT, 1)}
                  expect        => 'look out ! Boy Wonder'
                  expect_nt     => 'holy near earth asteroid Batman !'

    pass: "TEST FATAL ERRS"

    if (1)
        # test for fatal errors. Im unsettled on fail vs die.
        # calling fail isnt good enough by itself.

        $^EVAL_ERROR=''
        try {
            (checkOptree:  name  => 'test against empty expectations'
                           bcopts        => '-exec'
                           code  => sub (@< @_) {(print: $^STDOUT, 1)}
                           expect        => ''
                           expect_nt     => '');
        }
        like: $^EVAL_ERROR->{?description}, qr/no '\w+' golden-sample found/, "empty expectations prevented"

        $^EVAL_ERROR=''
        try {
            (checkOptree:  name  => 'prevent whitespace only expectations'
                           bcopts        => '-exec'
                           code  => sub (@< @_) {my $a}
                          #skip => 1,
                           expect_nt     => "\n"
                           expect        => "\n");
        }
        like: $^EVAL_ERROR->{?description}, qr/no reftext found for expect_nt/
              "just whitespace expectations prevented"
    

    pass: "TEST -e \$srcCode"

    checkOptree:  name  => 'empty code or prog'
                  skip  => 'or fails'
                  todo  => "your excuse here ;-)"
                  code  => ''
                  prog  => ''
                  

    pass: "REFTEXT FIXUP TESTS"

    checkOptree:  name  => 'fixup nextstate (in reftext)'
                  bcopts        => '-exec'
                  code  => sub {my $a}
                  expect_nt => <<'EONT_EONT'
# 1  <;> nextstate(main 54 optree_concise.t:84) v
# 2  <0> padsv[$a:54,55] sM/LVINTRO
# 3  <1> leavesub K/1
EONT_EONT



__END__

