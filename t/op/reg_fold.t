#!perl

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
}

use strict;
use warnings;
use Test::More;
use utf8;
my $count=1;
my @tests;

my $file="../lib/unicore/CaseFolding.txt";
open my $fh,"<",$file or die "Failed to read '$file': $!";
while (~< $fh) {
    chomp;
    my ($line,$comment)= split m/\s+#\s+/, $_;
    my ($cp,$type,@fc)=split m/[\s;]+/,$line||'';
    next unless $type and ($type eq 'F' or $type eq 'C');
    $_="\\x\{$_\}" for @fc;
    my $chr="chr(0x$cp)";
    my @str;
    push @str,$chr;

    foreach my $str ( @str ) {
        my $fc = join '', @fc;
        my $expr="$str =~ m/$fc/ix";
        push @tests,
            qq[ok($expr,'$chr =~ m/$fc/ix - $comment')];
        @tests[-1]="TODO: \{ local \$TODO='[13:41] <BinGOs> cue *It is all Greek to me* joke.';\n@tests[-1] \}"
            if $cp eq '0390' or $cp eq '03B0';
        @tests[-1]="TODO: \{ local \$TODO='Multi codepoints matches';\n@tests[-1] \}" if @fc +> 1;
        $count++;
    }
}
eval join ";\n","plan tests=>".($count-1),@tests,"1"
    or die $@;
__DATA__
