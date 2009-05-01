package NoExporter;

our $VERSION = 1.02;
sub import(@< @_) { 
    shift @_;
    die "NoExporter exports nothing.  You asked for: $(join ' ',@_)" if (nelems @_);
}

1;

