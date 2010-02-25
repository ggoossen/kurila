#!perl

use warnings
use Test::More tests => 1

my @pats= @:
            "\\w"
            "\\W"
            "\\s"
            "\\S"
            "\\d"
            "\\D"
            "[:alnum:]"
            "[:^alnum:]"
            "[:alpha:]"
            "[:^alpha:]"
            "[:ascii:]"
            "[:^ascii:]"
            "[:cntrl:]"
            "[:^cntrl:]"
            "[:graph:]"
            "[:^graph:]"
            "[:lower:]"
            "[:^lower:]"
            "[:print:]"
            "[:^print:]"
            "[:punct:]"
            "[:^punct:]"
            "[:upper:]"
            "[:^upper:]"
            "[:xdigit:]"
            "[:^xdigit:]"
            "[:space:]"
            "[:^space:]"
            "[:blank:]"
            "[:^blank:]"

if ((env::var: 'PERL_TEST_LEGACY_POSIX_CC'))
    $::TODO = "Only works under PERL_LEGACY_UNICODE_CHARCLASS_MAPPINGS = 0"

sub rangify($ary, ?$fmt, ?$sep, ?$rng)
    $fmt ||= '%d'
    $sep ||= ' '
    $rng ||= '..'
    
    my $first= $ary->[0]
    my $last= $ary->[0]
    my $ret= sprintf: $fmt, $first
    for my $idx (1..(nelems: $ary->@)-1)
        if ( $ary->[$idx] != $last + 1)
            if ($last!=$first)
                $ret.=sprintf: "\%s$fmt",$rng, $last
            $first= $last= $ary->[$idx]
            $ret.=sprintf: "\%s$fmt",$sep,$first
         else
            $last= $ary->[$idx]

    if ( $last != $first)
        $ret.=sprintf: "\%s$fmt",$rng, $last

    return $ret

use utf8

my $description = ""
while (@pats)
    my @: $yes,$no = @: splice: @pats,0,2
    
    my %err_by_type
    my %singles
    foreach my $b (0..255)
        my %got
        for my $type (@: 'unicode', 'not-unicode')
            my $str=(chr: $b).chr: $b

            if ($str =~ m/[$yes][$no]/)
                push: %err_by_type{$type},$b
            %got{+"[$yes]"}{+$type} = $str =~ m/[$yes]/ ?? 1 !! 0
            %got{+"[$no]"}{+$type} = $str =~ m/[$no]/ ?? 1 !! 0
            %got{+"[^$yes]"}{+$type} = $str =~ m/[^$yes]/ ?? 1 !! 0
            %got{+"[^$no]"}{+$type} = $str =~ m/[^$no]/ ?? 1 !! 0

        foreach my $which (@: "[$yes]","[$no]","[^$yes]","[^$no]")
            if (%got{$which}{'unicode'} != %got{$which}{'not-unicode'})
                push: %singles{$which},$b
    
    
    if (%err_by_type || %singles)
        $description||=" Error:\n"
        $description .= "/[$yes][$no]/\n"
        if (%err_by_type)
            foreach my $type (keys %err_by_type)
                $description .= "\tmatches $type codepoints:\t"
                $description .= rangify: %err_by_type{$type}
                $description .= "\n"
            $description .= "\n"

        if (%singles)
            $description .= "Unicode/Nonunicode mismatches:\n"
            foreach my $type (keys %singles)
                $description .= "\t$type:\t"
                $description .= rangify: %singles{$type}
                $description .= "\n"
            $description .= "\n"
    
:TODO do
    is:  $description, "", "POSIX and perl charclasses should not depend on string type"

__DATA__
