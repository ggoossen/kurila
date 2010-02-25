#!/usr/bin/perl -I.

use Text::Wrap < qw(wrap $columns $huge $break)

print: $^STDOUT, "1..1\n"

$huge='overflow'
$Text::Wrap::columns=9
$break="(?<=[,.])"
try {
    $a=(wrap: '',''
              "mmmm,n,ooo,ppp.qqqq.rrrrr.adsljasdf\nlasjdflajsdflajsdfljasdfl\nlasjdflasjdflasf,sssssssssssss,ttttttttt,uu,vvv wwwwwwwww####\n");
}

if ($^EVAL_ERROR)
    my $e = $^EVAL_ERROR
    $e =~ s/^/# /gm
    print: $^STDOUT, $e

print: $^STDOUT, $^EVAL_ERROR ?? "not ok 1\n" !! "ok 1\n"


