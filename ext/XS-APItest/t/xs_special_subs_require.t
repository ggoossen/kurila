#!perl -w
use TestInit
use Config
BEGIN 
    # Hush the used only once warning.
    $XS::APItest::WARNINGS_ON_BOOTSTRAP = $MacPerl::Architecture
    $XS::APItest::WARNINGS_ON_BOOTSTRAP = 1


use warnings
our $uc
BEGIN { $uc = 1; }
use Test::More tests => $uc ?? 103 !! 83

# Doing this longhand cut&paste makes it clear
# BEGIN and INIT are FIFO, CHECK and END are LIFO
BEGIN 
    print: $^STDOUT, "# First BEGIN\n"
    is: $XS::APItest::BEGIN_called, undef, "BEGIN not yet called"
    is: $XS::APItest::BEGIN_called_PP, undef, "BEGIN not yet called"
    is: $XS::APItest::UNITCHECK_called, undef, "UNITCHECK not yet called"
        if $uc
    is: $XS::APItest::UNITCHECK_called_PP, undef, "UNITCHECK not called"
        if $uc
    is: $XS::APItest::CHECK_called, undef, "CHECK not called"
    is: $XS::APItest::CHECK_called_PP, undef, "CHECK not called"
    is: $XS::APItest::INIT_called, undef, "INIT not called"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


CHECK 
    print: $^STDOUT, "# First CHECK\n"
    is: $XS::APItest::BEGIN_called, undef, "BEGIN not yet called"
    is: $XS::APItest::BEGIN_called_PP, undef, "BEGIN not yet called"
    is: $XS::APItest::UNITCHECK_called, undef, "UNITCHECK not yet called"
        if $uc
    is: $XS::APItest::UNITCHECK_called_PP, undef, "UNITCHECK not called"
        if $uc
    is: $XS::APItest::CHECK_called, undef, "CHECK not called (too late)"
    is: $XS::APItest::CHECK_called_PP, undef, "CHECK not called (too late)"
    is: $XS::APItest::INIT_called, undef, "INIT not called"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


INIT 
    print: $^STDOUT, "# First INIT\n"
    is: $XS::APItest::BEGIN_called, undef, "BEGIN not yet called"
    is: $XS::APItest::BEGIN_called_PP, undef, "BEGIN not yet called"
    is: $XS::APItest::UNITCHECK_called, undef, "UNITCHECK not yet called"
        if $uc
    is: $XS::APItest::UNITCHECK_called_PP, undef, "UNITCHECK not called"
        if $uc
    is: $XS::APItest::CHECK_called, undef, "CHECK not called (too late)"
    is: $XS::APItest::CHECK_called_PP, undef, "CHECK not called (too late)"
    is: $XS::APItest::INIT_called, undef, "INIT not called"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


END 
    print: $^STDOUT, "# First END\n"
    is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
    is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
    is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::CHECK_called, undef, "CHECK not called (too late)"
    is: $XS::APItest::CHECK_called_PP, undef, "CHECK not called (too late)"
    is: $XS::APItest::INIT_called, undef, "INIT not called (too late)"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not called (too late)"
    is: $XS::APItest::END_called, 1, "END called"
    is: $XS::APItest::END_called_PP, 1, "END called"


print: $^STDOUT, "# First body\n"
is: $XS::APItest::BEGIN_called, undef, "BEGIN not yet called"
is: $XS::APItest::BEGIN_called_PP, undef, "BEGIN not yet called"
is: $XS::APItest::UNITCHECK_called, undef, "UNITCHECK not yet called" if $uc
is: $XS::APItest::UNITCHECK_called_PP, undef, "UNITCHECK not called" if $uc
is: $XS::APItest::CHECK_called, undef, "CHECK not called (too late)"
is: $XS::APItest::CHECK_called_PP, undef, "CHECK not called (too late)"
is: $XS::APItest::INIT_called, undef, "INIT not called (too late)"
is: $XS::APItest::INIT_called_PP, undef, "INIT not called (too late)"
is: $XS::APItest::END_called, undef, "END not yet called"
is: $XS::APItest::END_called_PP, undef, "END not yet called"

do
    my @trap
    local $^WARN_HOOK = sub (@< @_) { (push: @trap, @_[0]->{?description}) }
    require XS::APItest

    @trap = sort: @trap
    is: scalar nelems @trap, 2, "There were 2 warnings"
    is: @trap[0], "Too late to run CHECK block"
    is: @trap[1], "Too late to run INIT block"


print: $^STDOUT, "# Second body\n"
is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK called" if $uc
is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK called" if $uc
is: $XS::APItest::CHECK_called, undef, "CHECK not called (too late)"
is: $XS::APItest::CHECK_called_PP, undef, "CHECK not called (too late)"
is: $XS::APItest::INIT_called, undef, "INIT not called (too late)"
is: $XS::APItest::INIT_called_PP, undef, "INIT not called (too late)"
is: $XS::APItest::END_called, undef, "END not yet called"
is: $XS::APItest::END_called_PP, undef, "END not yet called"

BEGIN 
    print: $^STDOUT, "# Second BEGIN\n"
    is: $XS::APItest::BEGIN_called, undef, "BEGIN not yet called"
    is: $XS::APItest::BEGIN_called_PP, undef, "BEGIN not yet called"
    is: $XS::APItest::UNITCHECK_called, undef, "UNITCHECK not yet called"
        if $uc
    is: $XS::APItest::UNITCHECK_called_PP, undef, "UNITCHECK not called"
        if $uc
    is: $XS::APItest::CHECK_called, undef, "CHECK not called"
    is: $XS::APItest::CHECK_called_PP, undef, "CHECK not called"
    is: $XS::APItest::INIT_called, undef, "INIT not called"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


CHECK 
    print: $^STDOUT, "# Second CHECK\n"
    is: $XS::APItest::BEGIN_called, undef, "BEGIN not yet called"
    is: $XS::APItest::BEGIN_called_PP, undef, "BEGIN not yet called"
    is: $XS::APItest::UNITCHECK_called, undef, "UNITCHECK not yet called"
        if $uc
    is: $XS::APItest::UNITCHECK_called_PP, undef, "UNITCHECK not yet called"
        if $uc
    is: $XS::APItest::CHECK_called, undef, "CHECK not called"
    is: $XS::APItest::CHECK_called_PP, undef, "CHECK not called"
    is: $XS::APItest::INIT_called, undef, "INIT not called"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


INIT 
    print: $^STDOUT, "# Second INIT\n"
    is: $XS::APItest::BEGIN_called, undef, "BEGIN not yet called"
    is: $XS::APItest::BEGIN_called_PP, undef, "BEGIN not yet called"
    is: $XS::APItest::UNITCHECK_called, undef, "UNITCHECK not yet called"
        if $uc
    is: $XS::APItest::UNITCHECK_called_PP, undef, "UNITCHECK not yet called"
        if $uc
    is: $XS::APItest::CHECK_called, undef, "CHECK not called (too late)"
    is: $XS::APItest::CHECK_called_PP, undef, "CHECK not called (too late)"
    is: $XS::APItest::INIT_called, undef, "INIT not called (too late)"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not called (too late)"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


END 
    print: $^STDOUT, "# Second END\n"
    is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
    is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
    is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::CHECK_called, undef, "CHECK not called (too late)"
    is: $XS::APItest::CHECK_called_PP, undef, "CHECK not called (too late)"
    is: $XS::APItest::INIT_called, undef, "INIT not called (too late)"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not called (too late)"
    is: $XS::APItest::END_called, 1, "END called"
    is: $XS::APItest::END_called_PP, 1, "END called"

