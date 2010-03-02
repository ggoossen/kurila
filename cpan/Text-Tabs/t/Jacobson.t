#!/usr/bin/perl -I.

# From: Dan Jacobson <jidanni at jidanni dot org>

use Text::Wrap < qw(wrap $columns $huge $break)

print: $^STDOUT, "1..1\n"

$huge='overflow'
$Text::Wrap::columns=9
$break="(?<=[,.])"
try {
    $a=(wrap: '',''
              "mmmm,n,ooo,ppp.qqqq.rrrrr,sssssssssssss,ttttttttt,uu,vvv wwwwwwwww####\n");
}

if ($^EVAL_ERROR)
    my $e = $^EVAL_ERROR
    $e =~ s/^/# /gm
    print: $^STDOUT, $e

print: $^STDOUT, $^EVAL_ERROR ?? "not ok 1\n" !! "ok 1\n"


