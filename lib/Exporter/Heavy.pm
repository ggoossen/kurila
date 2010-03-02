package Exporter::Heavy

# On one line so MakeMaker will see it.
our $VERSION = $Exporter::VERSION

package Exporter;

# Carp 1.05+ does this now for us, but we may be running with an old Carp
%Carp::Internal{+'Exporter::Heavy'}++

=head1 NAME

Exporter::Heavy - Exporter guts

=head1 SYNOPSIS

(internal use only)

=head1 DESCRIPTION

No user-serviceable parts inside.

=cut

#
# We go to a lot of trouble not to 'require Carp' at file scope,
#  because Carp requires Exporter, and something has to give.
#

sub _rebuild_cache($pkg, $exports, $cache)
    for ($exports->@)
        s/^&//
    $cache->{[ $exports->@]} = (@: 1) x nelems $exports->@
    my $ok = \(Symbol::fetch_glob: "$($pkg)::EXPORT_OK")->*->@
    if (nelems $ok->@)
        for ($ok->@)
            s/^&//
        $cache->{[$ok->@]} = (@: 1) x nelems $ok->@


sub export($pkg, $callpkg, @< @imports)
    my ($type, $cache_is_current, $oops)
    my (@: $exports, $export_cache) = @: \(Symbol::fetch_glob: "$($pkg)::EXPORT")->*->@
                                         (%Exporter::Cache{+$pkg} ||= \$%)

    if ((nelems @imports))
        if (!$export_cache->%)
            _rebuild_cache: $pkg, $exports, $export_cache
            $cache_is_current = 1


        if ((grep: { m{^[/!:]} }, @imports))
            my $tagsref = \(Symbol::fetch_glob: "$($pkg)::EXPORT_TAGS")->*->%
            my $tagdata
            my %imports
            my($remove, @names, @allexports)
            # negated first item implies starting with default set:
            unshift: @imports, ':DEFAULT' if @imports[0] =~ m/^!/
            foreach my $spec ( @imports)
                $remove = $spec =~ s/^!//

                if ($spec =~ s/^://)
                    if ($spec eq 'DEFAULT')
                        @names = $exports->@
                    elsif ((defined: ($tagdata = $tagsref->{?$spec})))
                        @names = $tagdata
                    else
                        warn: qq["$spec" is not defined in \%$($pkg)::EXPORT_TAGS]
                        ++$oops
                        next

                elsif ($spec =~ m:^/(.*)/$:)
                    my $patn = $1
                    @allexports = keys $export_cache->% unless (nelems @allexports) # only do keys once
                    @names = grep:  {m/$patn/ }, @allexports # not anchored by default
                else
                    @names = @: $spec # is a normal symbol name

                warn: "Import ".($remove ?? "del"!!"add").": $((join: ' ',@names)) "
                    if $Exporter::Verbose

                if ($remove)
                    foreach my $sym ( @names) { delete %imports{$sym} }
                else
                    %imports{[@names]} = (@: 1) x nelems @names

            @imports = keys %imports


        my @carp
        foreach my $sym ( @imports)
            if (!$export_cache->{?$sym})
                if ($sym =~ m/^\d/)
                    $pkg->VERSION: $sym # inherit from UNIVERSAL
                    # If the version number was the only thing specified
                    # then we should act as if nothing was specified:
                    if ((nelems @imports) == 1)
                        @imports = $exports->@
                        last

                    # We need a way to emulate 'use Foo ()' but still
                    # allow an easy version check: "use Foo 1.23, ''";
                    if ((nelems @imports) == 2 and !@imports[1])
                        @imports = $@
                        last

                elsif ($sym !~ s/^&// || !$export_cache->{?$sym})
                    # Last chance - see if they've updated EXPORT_OK since we
                    # cached it.

                    unless ($cache_is_current)
                        $export_cache->% = $%
                        _rebuild_cache: $pkg, $exports, $export_cache
                        $cache_is_current = 1

                    if (!$export_cache->{?$sym})
                        # accumulate the non-exports
                        push: @carp
                              qq["$sym" is not exported by the $pkg module\n]
                        $oops++

        if ($oops)
            die: "$((join: ' ', @carp))Can't continue after import errors"
    else
        @imports = $exports->@

    my (@: $fail, $fail_cache) = @: \(Symbol::fetch_glob: "$($pkg)::EXPORT_FAIL")->*->@
                                    (%Exporter::FailCache{+$pkg} ||= \$%)

    if ((nelems $fail->@))
        if (!$fail_cache->%)
            # Build cache of symbols. Optimise the lookup by adding
            # barewords twice... both with and without a leading &.
            # (Technique could be applied to $export_cache at cost of memory)
            my @expanded = @+: map: { m/^\w/ ?? (@: $_, '&'.$_) !! (@: $_) }, $fail->@
            warn: "$($pkg)::EXPORT_FAIL cached: $((join: ' ',@expanded))" if $Exporter::Verbose
            $fail_cache->{[ @expanded]} = (1) x nelems @expanded

        my @failed
        foreach my $sym ( @imports) { push: @failed, $sym if $fail_cache->{?$sym} }
        if ((nelems @failed))
            @failed = $pkg->export_fail: < @failed
            foreach my $sym ( @failed)
                warn: qq["$sym" is not implemented by the $pkg module ]
                          . "on this architecture"
            if ((nelems @failed))
                die: "Can't continue after import errors"

    warn: "Importing into $callpkg from $pkg: "
          (join: ", ",(sort: @imports)) if $Exporter::Verbose

    foreach my $sym ( @imports)
        # shortcut for the common case of no type character
        ((Symbol::fetch_glob: "$($callpkg)::$sym")->* = \(Symbol::fetch_glob: "$($pkg)::$sym")->*->& and next)
            unless $sym =~ s/^(\W)//
        $type = $1
        no warnings 'once';
        (Symbol::fetch_glob: "$($callpkg)::$sym")->* =
            $type eq '&' ?? \(Symbol::fetch_glob: "$($pkg)::$sym")->*->& !!
            $type eq '$' ?? \(Symbol::fetch_glob: "$($pkg)::$sym")->*->$ !!
            $type eq '@' ?? \(Symbol::fetch_glob: "$($pkg)::$sym")->*->@ !!
            $type eq '%' ?? \(Symbol::fetch_glob: "$($pkg)::$sym")->*->% !!
            warn: "Can't export symbol: $type$sym"


# Utility functions

sub _push_tags($pkg, $var, $syms)
    my @nontag = $@
    my $export_tags = \(Symbol::fetch_glob: "$($pkg)::EXPORT_TAGS")->*->%
    push: (Symbol::fetch_glob: "$($pkg)::$var")->*->@
          < @+: (map: { exists $export_tags->{$_} ?? $export_tags->{?$_}
                          !! do { push: @nontag,$_; (@: $_) } },
                          (nelems $syms->@) ?? $syms->@ !! keys $export_tags->%)
    if ((nelems @nontag) and $^WARNING)
        # This may change to a die one day
        warn: (join: ", ", @nontag)." are not tags of $pkg"



sub require_version($self, $wanted)
    my $pkg = ref $self || $self
    return $pkg->VERSION: $wanted


sub export_tags
    _push_tags: (@: caller)[0], "EXPORT",    \@_


sub export_ok_tags
    _push_tags: (@: caller)[0], "EXPORT_OK", \@_


1
