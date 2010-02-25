#!/usr/bin/perl
# Finds the files that have the same name, case insensitively,
# in the current directory and its subdirectories

use warnings
use File::Find

my %files
my $test_count = 0

find: sub (@< @_)
          my $name = $File::Find::name
         # Assumes that the path separator is exactly one character.
          $name =~ s/^\.\..//
          push: %files{+ lc $name}, $name
      , '.'

foreach (values %files)
    if ((nelems: $_) +> 1)
        print: $^STDOUT, "not ok ".++$test_count. " - ". (join: ", ", $_), "\n"
    else
        print: $^STDOUT, "ok ".++$test_count. " - ". (join: ", ", $_), "\n"

print: $^STDOUT, "1..".$test_count."\n"
