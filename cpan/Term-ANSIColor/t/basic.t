#!/usr/bin/perl
# $Id: basic.t 55 2006-06-22 17:56:02Z eagle $
#
# t/basic.t -- Test suite for the Term::ANSIColor Perl module.

##############################################################################
# Ensure module can be loaded
##############################################################################

BEGIN { $^OUTPUT_AUTOFLUSH = 1; (print: $^STDOUT, "1..16\n") }
(env::var: 'ANSI_COLORS_DISABLED') = undef
use Term::ANSIColor < qw(:constants color colored uncolor)
print: $^STDOUT, "ok 1\n"

##############################################################################
# Test suite
##############################################################################

# Test simple color attributes.
if ((color: 'blue on_green', 'bold') eq "\e[34;42;1m")
    print: $^STDOUT, "ok 2\n"
else
    print: $^STDOUT, "not ok 2\n"


# Test colored.
if ((colored: "testing", 'blue', 'bold') eq "\e[34;1mtesting\e[0m")
    print: $^STDOUT, "ok 3\n"
else
    print: $^STDOUT, "not ok 3\n"


# Test the constants.
if (BLUE: BOLD: "testing" eq "\e[34m\e[1mtesting")
    print: $^STDOUT, "ok 4\n"
else
    print: $^STDOUT, "not ok 4\n"


# Test AUTORESET.
$Term::ANSIColor::AUTORESET = 1
if (BLUE: BOLD: "testing" eq "\e[34m\e[1mtesting\e[0m\e[0m")
    print: $^STDOUT, "ok 5\n"
else
    print: $^STDOUT, "not ok 5\n"


# Test EACHLINE.
$Term::ANSIColor::EACHLINE = "\n"
if (colored: "test\n\ntest", 'bold'
    eq "\e[1mtest\e[0m\n\n\e[1mtest\e[0m")
    print: $^STDOUT, "ok 6\n"
else
    print: $^STDOUT, (colored: "test\n\ntest", 'bold'), "\n"
    print: $^STDOUT, "not ok 6\n"


# Test EACHLINE with multiple trailing delimiters.
$Term::ANSIColor::EACHLINE = "\r\n"
if (colored: "test\ntest\r\r\n\r\n", 'bold'
    eq "\e[1mtest\ntest\r\e[0m\r\n\r\n")
    print: $^STDOUT, "ok 7\n"
else
    print: $^STDOUT, "not ok 7\n"


# Test the array ref form.
$Term::ANSIColor::EACHLINE = "\n"
if (colored: \(@: 'bold', 'on_green'), "test\n", "\n", "test"
    eq "\e[1;42mtest\e[0m\n\n\e[1;42mtest\e[0m")
    print: $^STDOUT, "ok 8\n"
else
    print: $^STDOUT, < colored: \(@: 'bold', 'on_green'), "test\n", "\n", "test"
    print: $^STDOUT, "not ok 8\n"


# Test uncolor.
my @names = uncolor: '1;42', "\e[m", '', "\e[0m"
if ((join: '|', @names) eq 'bold|on_green|clear')
    print: $^STDOUT, "ok 9\n"
else
    print: $^STDOUT, (join: '|', @names), "\n"
    print: $^STDOUT, "not ok 9\n"


# Test ANSI_COLORS_DISABLED.
(env::var: 'ANSI_COLORS_DISABLED' ) = 1
if ((color: 'blue') eq '')
    print: $^STDOUT, "ok 10\n"
else
    print: $^STDOUT, "not ok 10\n"

if ((colored: 'testing', 'blue', 'on_red') eq 'testing')
    print: $^STDOUT, "ok 11\n"
else
    print: $^STDOUT, "not ok 11\n"

if (GREEN: 'testing' eq 'testing')
    print: $^STDOUT, "ok 12\n"
else
    print: $^STDOUT, "not ok 12\n"

(env::var: 'ANSI_COLORS_DISABLED') = undef

# Make sure DARK is exported.  This was omitted in versions prior to 1.07.
if (DARK: "testing" eq "\e[2mtesting\e[0m")
    print: $^STDOUT, "ok 13\n"
else
    print: $^STDOUT, "not ok 13\n"


# Test colored with 0 and EACHLINE.
$Term::ANSIColor::EACHLINE = "\n"
if ((colored: '0', 'blue', 'bold') eq "\e[34;1m0\e[0m")
    print: $^STDOUT, "ok 14\n"
else
    print: $^STDOUT, "not ok 14\n"

if (colored: "0\n0\n\n", 'blue', 'bold'
    eq "\e[34;1m0\e[0m\n\e[34;1m0\e[0m\n\n")
    print: $^STDOUT, "ok 15\n"
else
    print: $^STDOUT, "not ok 15\n"


# Test colored with the empty string and EACHLINE.
if ((colored: '', 'blue', 'bold') eq '')
    print: $^STDOUT, "ok 16\n"
else
    print: $^STDOUT, "not ok 16\n"

