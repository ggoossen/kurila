package File::Compare

use warnings
our($VERSION, @ISA, @EXPORT, @EXPORT_OK, $Too_Big)

require Exporter

$VERSION = '1.1005'
@ISA = qw(Exporter)
@EXPORT = qw(compare)
@EXPORT_OK = qw(cmp compare_text)

$Too_Big = 1024 * 1024 * 2

sub compare
    die: "Usage: compare( file1, file2 [, buffersize]) "
        unless((nelems @_) == 2 || (nelems @_) == 3)

    my (@: $from,$to,?$size) =  @_
    my $text_mode = (defined: $size) && ((ref::svtype: $size) eq 'CODE' || $size +< 0)

    my ($fromsize,$closefrom,$closeto)

    my $from_fh
    my $to_fh

    my $fail_open1 = sub (@< @_) { return -1; }
    my $fail_open2 =
        sub (@< @_)
        if ($closefrom)
            my $status = $^OS_ERROR
            $^OS_ERROR = 0
            close $from_fh
            $^OS_ERROR = $status unless $^OS_ERROR
        
        return ($fail_open1->& <: )
    

    # All of these contortions try to preserve error messages...
    my $fail_inner =
        sub (@< @_)
        (close: $to_fh) || return ($fail_open2->& <: ) if $closeto
        (close: $from_fh) || return ($fail_open1->& <: ) if $closefrom
        return 1
    

    die: "from undefined" unless (defined $from)
    die: "to undefined" unless (defined $to)

    if ((ref: $from) &&
        ((UNIVERSAL::isa: $from,'GLOB') || (UNIVERSAL::isa: $from,'IO::Handle')))
        $from_fh = $from
    elsif ((ref: \$from) eq 'GLOB')
        $from_fh = \$from
    else
        open: $from_fh,"<",$from or return ($fail_open1->& <: )
        unless ($text_mode)
            binmode: $from_fh
            $fromsize = -s $from_fh
        
        $closefrom = 1
    

    if ((ref: $to) &&
        ((UNIVERSAL::isa: $to,'GLOB') || (UNIVERSAL::isa: $to,'IO::Handle')))
        $to_fh = $to
    elsif ((ref: \$to) eq 'GLOB')
        $to_fh = \$to
    else
        open: $to_fh,"<",$to or return ($fail_open2->& <: )
        binmode: $to_fh unless $text_mode
        $closeto = 1
    

    if (!$text_mode && $closefrom && $closeto)
        # If both are opened files we know they differ if their size differ
        return ($fail_inner->& <: ) if $fromsize != -s $to_fh
    

    if ($text_mode)
        local $^INPUT_RECORD_SEPARATOR = "\n"
        my ($fline,$tline)
        while ((defined: ($fline = ~< $from_fh)))
            return ($fail_inner->& <: ) unless defined: ($tline = ~< $to_fh)
            if (ref $size)
                # $size contains ref to comparison function
                return ($fail_inner->& <: ) if $size->& <: $fline, $tline
            else
                return ($fail_inner->& <: ) if $fline ne $tline
            
        
        return ($fail_inner->& <: ) if defined: ($tline = ~< $to_fh)
    else
        unless ((defined: $size) && $size +> 0)
            $size = $fromsize || -s $to_fh || 0
            $size = 1024 if $size +< 512
            $size = $Too_Big if $size +> $Too_Big
        

        my ($fr,$tr,$fbuf,$tbuf)
        $fbuf = $tbuf = ''
        while((defined: ($fr = (read: $from_fh,$fbuf,$size))) && $fr +> 0)
            unless ((defined: ($tr = (read: $to_fh,$tbuf,$fr))) && $tbuf eq $fbuf)
                return ($fail_inner->& <: )
            
        
        return ($fail_inner->& <: ) if (defined: ($tr = (read: $to_fh,$tbuf,$size))) && $tr +> 0
    

    (close: $to_fh) || return ($fail_open2->& <: ) if $closeto
    (close: $from_fh) || return ($fail_open1->& <: ) if $closefrom

    return 0


*cmp = \&compare

sub compare_text
    my (@: $from,$to,?$cmp) =  @_
    die: "Usage: compare_text( file1, file2 [, cmp-function])"
        unless (nelems @_) == 2 || (nelems @_) == 3
    die: "Third arg to compare_text() function must be a code reference"
        if (nelems @_) == 3 && (ref::svtype: $cmp) ne 'CODE'

    # Using a negative buffer size puts compare into text_mode too
    $cmp = -1 unless defined $cmp
    compare: $from, $to, $cmp


1

__END__

=head1 NAME

File::Compare - Compare files or filehandles

=head1 SYNOPSIS

  	use File::Compare;

	if (compare("file1","file2") == 0) {
	    print "They're equal\n";
	}

=head1 DESCRIPTION

The File::Compare::compare function compares the contents of two
sources, each of which can be a file or a file handle.  It is exported
from File::Compare by default.

File::Compare::cmp is a synonym for File::Compare::compare.  It is
exported from File::Compare only by request.

File::Compare::compare_text does a line by line comparison of the two
files. It stops as soon as a difference is detected. compare_text()
accepts an optional third argument: This must be a CODE reference to
a line comparison function, which returns 0 when both lines are considered
equal. For example:

    compare_text($file1, $file2)

is basically equivalent to

    compare_text($file1, $file2, sub {$_[0] ne $_[1]} )

=head1 RETURN

File::Compare::compare and its sibling functions return 0 if the files
are equal, 1 if the files are unequal, or -1 if an error was encountered.

=head1 AUTHOR

File::Compare was written by Nick Ing-Simmons.
Its original documentation was written by Chip Salzenberg.

=cut

