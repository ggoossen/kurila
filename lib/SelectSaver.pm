package SelectSaver;

our $VERSION = '1.01';

=head1 NAME

SelectSaver - save and restore selected file handle

=head1 SYNOPSIS

    use SelectSaver;

    {
       my $saver = SelectSaver->new(FILEHANDLE);
       # FILEHANDLE is selected
    }
    # previous handle is selected

    {
       my $saver = SelectSaver->new;
       # new handle may be selected, or not
    }
    # previous handle is selected

=head1 DESCRIPTION

A C<SelectSaver> object contains a reference to the file handle that
was selected when it was created.  If its C<new> method gets an extra
parameter, then that parameter is selected; otherwise, the selected
file handle remains unchanged.

When a C<SelectSaver> is destroyed, it re-selects the file handle
that was selected when it was created.

=cut

sub new {
    (nelems @_) +>= 1 && (nelems @_) +<= 2 or die 'usage: SelectSaver->new([FILEHANDLE])';
    my $fh = select;
    my $self = bless \$fh, @_[0];
    select @_[1] if (nelems @_) +> 1;
    $self;
}

sub DESTROY {
    my $self = @_[0];
    select $$self;
}

1;
