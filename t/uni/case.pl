use File::Spec

require "./test.pl"

require bytes
use utf8


sub unidump
    join: " ", map: { (sprintf: "\%04X", $_) }, @:  unpack: "U*", @_[0]


sub casetest
    my (@: $base, $spec, @< @funcs) =  @_
    # For each provided function run it, and run a version with some extra
    # characters afterwards. Use a recycling symbol, as it doesn't change case.
    my $ballast = (chr: 0x2672) x 3
    @funcs = @+: map: {my $f = $_;
                          (@: $f
            sub (@< @_) {my $r =( $f->& <: @_[0] . $ballast); # Add it before
                                  $r =~ s/$ballast\z//so # Remove it afterwards
                                      or die: "'@_[0]' to '$r' mangled";
                                  $r; # Result with $ballast removed.
                              }
                              )}, @funcs

    my $file = 'File::Spec'->catfile: ('File::Spec'->catdir: 'File::Spec'->updir
                                                             "lib", "unicore", "To")
                                      "$base.pl"
    my $simple = evalfile $file or die: $^EVAL_ERROR
    my %simple
    for my $i ((split: m/\n/, $simple))
        my (@: $k, $v) =  split: ' ', $i
        %simple{+$k} = $v
    
    my %seen

    for my $i ((sort: keys %simple))
        %seen{+$i}++
    

    my $both

    for my $i ((sort: keys $spec->%))
        if (++%seen{+$i} == 2)
            warn: sprintf: "$base: $i seen twice\n"
            $both++
        
    
    exit: 1 if $both

    my %none
    for my $i ( map: { ord }, split: m//
                                     "\e !\"#\$\%&'()+,-./0123456789:;<=>?\@[\\]^_\{|\}~\b")
        next if (pack: "U0U", $i) =~ m/\w/
        %none{+$i}++ unless %seen{?$i}
    

    my $tests =
        ( ((nelems: %simple)/2) +
          ((nelems: $spec->%)/2) +
          ((nelems: %none)/2) ) * nelems @funcs
    print: $^STDOUT, "1..$tests\n"

    my $test = 1

    for my $i ((sort: keys %simple))
        my $w = %simple{?$i}
        my $c = pack: "U0U", hex $i
        foreach my $func ( @funcs)
            my $d = $func->& <: $c
            my $e = unidump: $d
            print: $^STDOUT, $d eq (pack: "U0U", hex %simple{?$i}) ??
                       "ok $test # $i -> $w\n" !! "not ok $test # $i -> $e ($w)" . (sprintf: '%x', (ord: $d)) . "\n"
            $test++
        
    

    for my $i ((sort: keys $spec->%))
        my $w = unidump: $spec->{?$i}
        #my $c = substr $i, 0, 1;
        my $h = unidump: $i
        foreach my $func ( @funcs)
            my $d = $func->& <: $i
            my $e = unidump: $d
            if ((bytes::ord:  "A") == 193) # EBCDIC
                # We need to a little bit of remapping.
                #
                # For example, in titlecase (ucfirst) mapping
                # of U+0149 the Unicode mapping is U+02BC U+004E.
                # The 4E is N, which in EBCDIC is 2B--
                # and the ucfirst() does that right.
                # The problem is that our reference
                # data is in Unicode code points.
                #
                # The Right Way here would be to use, say,
                # Encode, to remap the less-than 0x100 code points,
                # but let's try to be Encode-independent here.
                #
                # These are the titlecase exceptions:
                #
                #         Unicode   Unicode+EBCDIC
                #
                # 0149 -> 02BC 004E (02BC 002B)
                # 01F0 -> 004A 030C (00A2 030C)
                # 1E96 -> 0048 0331 (00E7 0331)
                # 1E97 -> 0054 0308 (00E8 0308)
                # 1E98 -> 0057 030A (00EF 030A)
                # 1E99 -> 0059 030A (00DF 030A)
                # 1E9A -> 0041 02BE (00A0 02BE)
                #
                # The uppercase exceptions are identical.
                #
                # The lowercase has one more:
                #
                #         Unicode   Unicode+EBCDIC
                #
                # 0130 -> 0069 0307 (00D1 0307)
                #
                if ($h =~ m/^(0130|0149|01F0|1E96|1E97|1E98|1E99|1E9A)$/)
                    $e =~ s/004E/002B/ # N
                    $e =~ s/004A/00A2/ # J
                    $e =~ s/0048/00E7/ # H
                    $e =~ s/0054/00E8/ # T
                    $e =~ s/0057/00EF/ # W
                    $e =~ s/0059/00DF/ # Y
                    $e =~ s/0041/00A0/ # A
                    $e =~ s/0069/00D1/ # i
                
            # We have to map the output, not the input, because
            # pack/unpack U has been EBCDICified, too, it would
            # just undo our remapping.
            
            print: $^STDOUT, $w eq $e ??
                       "ok $test # $i -> $w\n" !! "not ok $test # $h -> $e ($w)\n"
            $test++
        
    

    for my $i ((sort: { $a <+> $b }, keys %none))
        my $w = $i = sprintf: "\%04X", $i
        my $c = pack: "U0U", hex $i
        foreach my $func ( @funcs)
            my $d = $func->& <: $c
            my $e = unidump: $d
            print: $^STDOUT, $d eq $c ??
                       "ok $test # $i -> $w\n" !! "not ok $test # $i -> $e ($w)\n"
            $test++
        
    


1
