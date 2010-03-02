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
use Test::More tests => $uc ?? 100 !! 80

# Doing this longhand cut&paste makes it clear
# BEGIN and INIT are FIFO, CHECK and END are LIFO
BEGIN 
    diag: "First BEGIN"
    is: $XS::APItest::BEGIN_called, undef, "BEGIN not yet called"
    is: $XS::APItest::BEGIN_called_PP, undef, "BEGIN not yet called"
    is: $XS::APItest::UNITCHECK_called, undef, "UNITCHECK not yet called"
        if $uc
    is: $XS::APItest::UNITCHECK_called_PP, undef, "UNITCHECK not yet called"
        if $uc
    is: $XS::APItest::CHECK_called, undef, "CHECK not yet called"
    is: $XS::APItest::CHECK_called_PP, undef, "CHECK not yet called"
    is: $XS::APItest::INIT_called, undef, "INIT not yet called"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not yet called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


CHECK
    diag: "First CHECK"
    is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
    is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
    is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::CHECK_called, 1, "CHECK called"
    is: $XS::APItest::CHECK_called_PP, 1, "CHECK called"
    is: $XS::APItest::INIT_called, undef, "INIT not yet called"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not yet called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


INIT 
    diag: "First INIT"
    is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
    is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
    is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::CHECK_called, 1, "CHECK called"
    is: $XS::APItest::CHECK_called_PP, 1, "CHECK called"
    is: $XS::APItest::INIT_called, undef, "INIT not yet called"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not yet called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


END 
    diag: "First END"
    is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
    is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
    is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::CHECK_called, 1, "CHECK called"
    is: $XS::APItest::CHECK_called_PP, 1, "CHECK called"
    is: $XS::APItest::INIT_called, 1, "INIT called"
    is: $XS::APItest::INIT_called_PP, 1, "INIT called"
    is: $XS::APItest::END_called, 1, "END called"
    is: $XS::APItest::END_called_PP, 1, "END called"


diag: "First body"
is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK called" if $uc
is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK called" if $uc
is: $XS::APItest::CHECK_called, 1, "CHECK called"
is: $XS::APItest::CHECK_called_PP, 1, "CHECK called"
is: $XS::APItest::INIT_called, 1, "INIT called"
is: $XS::APItest::INIT_called_PP, 1, "INIT called"
is: $XS::APItest::END_called, undef, "END not yet called"
is: $XS::APItest::END_called_PP, undef, "END not yet called"

use XS::APItest

diag: "Second body"
is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK called" if $uc
is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK called" if $uc
is: $XS::APItest::CHECK_called, 1, "CHECK called"
is: $XS::APItest::CHECK_called_PP, 1, "CHECK called"
is: $XS::APItest::INIT_called, 1, "INIT called"
is: $XS::APItest::INIT_called_PP, 1, "INIT called"
is: $XS::APItest::END_called, undef, "END not yet called"
is: $XS::APItest::END_called_PP, undef, "END not yet called"

BEGIN 
    diag: "Second BEGIN"
    is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
    is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
    is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::CHECK_called, undef, "CHECK not yet called"
    is: $XS::APItest::CHECK_called_PP, undef, "CHECK not yet called"
    is: $XS::APItest::INIT_called, undef, "INIT not yet called"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not yet called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


CHECK 
    diag: "Second CHECK"
    is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
    is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
    is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK yet called" if $uc
    is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK yet called" if $uc
    is: $XS::APItest::CHECK_called, undef, "CHECK not yet called"
    is: $XS::APItest::CHECK_called_PP, undef, "CHECK not yet called"
    is: $XS::APItest::INIT_called, undef, "INIT not yet called"
    is: $XS::APItest::INIT_called_PP, undef, "INIT not yet called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


INIT 
    diag: "Second INIT"
    is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
    is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
    is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::CHECK_called, 1, "CHECK called"
    is: $XS::APItest::CHECK_called_PP, 1, "CHECK called"
    is: $XS::APItest::INIT_called, 1, "INIT called"
    is: $XS::APItest::INIT_called_PP, 1, "INIT called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"


END 
    diag: "Second END"
    is: $XS::APItest::BEGIN_called, 1, "BEGIN called"
    is: $XS::APItest::BEGIN_called_PP, 1, "BEGIN called"
    is: $XS::APItest::UNITCHECK_called, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::UNITCHECK_called_PP, 1, "UNITCHECK called" if $uc
    is: $XS::APItest::CHECK_called, 1, "CHECK called"
    is: $XS::APItest::CHECK_called_PP, 1, "CHECK called"
    is: $XS::APItest::INIT_called, 1, "INIT called"
    is: $XS::APItest::INIT_called_PP, 1, "INIT called"
    is: $XS::APItest::END_called, undef, "END not yet called"
    is: $XS::APItest::END_called_PP, undef, "END not yet called"
