package FindExt

our $VERSION = '1.02'

use warnings

my $no = join('|',qw(GDBM_File ODBM_File NDBM_File DB_File
		     Syslog SysV Langinfo))
$no = qr/^(?:$no)$/i

my %ext
my %static

sub set_static_extensions
    # adjust results of scan_ext, and also save
    # statics in case scan_ext hasn't been called yet.
    # if '*' is passed then all XS extensions are static
    # (with possible exclusions)
    %static = $%
    my @list = @_
    if (@_[0] eq '*')
        my %excl = %+: map { %: $_=>1 }, map {m/^!(.*)$/}, @_[[1 .. ((nelems @_)-1)]] 
        @list = grep {!exists %excl{$_}}, keys %ext
    
    for ( @list)
        %static{+$_} = 1
        %ext{+$_} = 'static' if %ext{?$_} && %ext{?$_} eq 'dynamic'
    


sub scan_ext($dir)
    find_ext("$dir/", '')
    extensions()

sub dynamic_ext
    return sort grep { %ext{?$_} eq 'dynamic' },keys %ext


sub static_ext
    return sort grep { %ext{?$_} eq 'static' },keys %ext


sub nonxs_ext
    return sort grep { %ext{?$_} eq 'nonxs' },keys %ext


sub extensions
    return sort grep { %ext{?$_} ne 'known' },keys %ext


sub known_extensions
    # faithfully copy Configure in not including nonxs extensions for the nonce
    return sort grep { %ext{?$_} ne 'nonxs' },keys %ext


sub is_static
    return %ext{?@_[0]} eq 'static'


# Function to recursively find available extensions, ignoring DynaLoader
# NOTE: recursion limit of 10 to prevent runaway in case of symlink madness
sub find_ext($ext_dir, $prefix)
    opendir my $dh, "$ext_dir$prefix"
    while (defined (my $item = readdir $dh))
        next if $item =~ m/^\.\.?$/;
        next if $item eq "DynaLoader"
        my $this_ext = my $this_ext_dir = "$prefix$item"
        my $leaf = $item

        $this_ext =~ s!-!/!g
        $leaf =~ s/.*-//

        if (-f "$ext_dir$this_ext_dir/$leaf.xs" || -f "$ext_dir$this_ext_dir/$leaf.c" )
            %ext{+$this_ext} = %static{?$this_ext} ?? 'static' !! 'dynamic'
        elsif (-f "$ext_dir$this_ext_dir/Makefile.PL")
            %ext{+$this_ext} = 'nonxs'
        else
            # It's not actually an extension. So recurse into it.
            if (-d "$ext_dir$this_ext_dir" && nelems(@: $prefix =~ m#/#) +< 10)
                find_ext($ext_dir, "$this_ext_dir/")

        %ext{$this_ext} = 'known' if %ext{?$this_ext} && $item =~ $no

1
# Local variables:
# cperl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# ex: set ts=8 sts=4 sw=4 et:
