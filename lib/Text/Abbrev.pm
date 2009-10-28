package Text::Abbrev
require Exporter

our $VERSION = '1.01'

=head1 NAME

abbrev - create an abbreviation table from a list

=head1 SYNOPSIS

    use Text::Abbrev;
    abbrev $hashref, LIST


=head1 DESCRIPTION

Stores all unambiguous truncations of each element of LIST
as keys in the associative array referenced by C<$hashref>.
The values are the original list elements.

=head1 EXAMPLE

    $hashref = abbrev qw(list edit send abort gripe);

    %hash = abbrev qw(list edit send abort gripe);

    abbrev $hashref, qw(list edit send abort gripe);

    abbrev(*hash, qw(list edit send abort gripe));

=cut


our @ISA = qw(Exporter)
our @EXPORT = qw(abbrev)

# Usage:
#	abbrev \%foo, LIST;
#	...
#	$long = $foo{$short};

sub abbrev
    my ($hashref, $glob, %table, $returnvoid)

    (nelems @_) or return   # So we don't autovivify onto @_ and trigger warning
    $hashref = shift
    $returnvoid = 1
    $hashref->% = $%

    :WORD foreach my $word ( @_)
        for my $len ( (reverse:  1 .. (length $word) - 1 ) )
            my $abbrev = substr: $word,0,$len
            my $seen = ++%table{+$abbrev}
            if ($seen == 1)         # We're the first word so far to have
                # this abbreviation.
                $hashref->{+$abbrev} = $word
            elsif ($seen == 2)  # We're the second word to have this
                # abbreviation, so we can't use it.
                delete $hashref->{$abbrev}
            else                    # We're the third word to have this
                # abbreviation, so skip to the next word.
                next WORD
            
        
    
    # Non-abbreviations always get entered, even if they aren't unique
    foreach my $word ( @_)
        $hashref->{+$word} = $word
    
    return if $returnvoid
    $hashref->%


1
