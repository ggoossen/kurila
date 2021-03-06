# take a semicolon separated path list and turn it into a quoted
# list of paths that Text::Parsewords will grok
sub mungepath {
    my $p = shift;
    # remove leading/trailing semis/spaces
    $p =~ s/^[ ;]+//;
    $p =~ s/[ ;]+$//;
    $p =~ s/'/"/g;
    my @p = map { $_ = "\"$_\"" if m/\s/ and !m/^".*"$/; $_ } split m/;/, $p;
    return join(' ', @p);
}

# generate an array of option strings from command-line args
# or an option file
#    -- added by BKS, 10-17-1999 to fix command-line overflow problems
sub loadopts {
    if (@ARGV[0] =~ m/--cfgsh-option-file/) {
	shift @ARGV;
	my $optfile = shift @ARGV;
	local (*F);
	open OPTF, "<", $optfile or die "Can't open $optfile: $^OS_ERROR\n";
	my @opts;
	chomp(my $line = ~< *OPTF);
	my @vars = split(m/\t+~\t+/, $line);
	for ( @vars) {
	    push(@opts, $_) unless (m/^\s*$/);
	}
	close OPTF;
	return \@opts;
    }
    else {
	return \@ARGV;
    }
}

my %opt;
my $optref = loadopts();
while ((nelems @{$optref}) && $optref->[0] =~ m/^([\w_]+)=(.*)$/) {
    %opt{+$1}=$2;
    shift(@{$optref});
}

my $pl_h = '../patchlevel.h';

if (-e $pl_h) {
    open PL, "<", "$pl_h" or die "Can't open $pl_h: $^OS_ERROR";
    while ( ~< *PL) {
	if (m/^#\s*define\s+(PERL_\w+)\s+([\d.]+)/) {
	    %opt{+$1} = $2;
	}
    }
    close PL;
}
else {
    die "Can't find $pl_h: $^OS_ERROR";
}
%opt{+VERSION} = "%opt{?PERL_REVISION}.%opt{?PERL_VERSION}.%opt{?PERL_SUBVERSION}";
%opt{+INST_VER} =~ s|~VERSION~|%opt{?VERSION}|g;

%opt{+'cf_by'} = env::var('USERNAME') unless %opt{?'cf_by'};
%opt{+'cf_email'} = %opt{?'cf_by'} . '@' . (gethostbyname('localhost'))[[0]]
	unless %opt{?'cf_email'};
%opt{+'usemymalloc'} = 'y' if %opt{?'d_mymalloc'} eq 'define';

%opt{+libpth} = mungepath(%opt{?libpth}) if exists %opt{libpth};
%opt{+incpath} = mungepath(%opt{?incpath}) if exists %opt{incpath};

while ( ~< *ARGV) {
    s/~([\w_]+)~/%opt{?$1}/g;
    if (m/^([\w_]+)=(.*)$/) {
	my@($k,$v) = @($1,$2);
	# this depends on cf_time being empty in the template (or we'll
	# get a loop)
	if ($k eq 'cf_time') {
	    $_ = "$k='" . localtime(time) . "'\n" if $v =~ m/^\s*'\s*'/;
	}
	elsif (exists %opt{$k}) {
	    $_ = "$k='%opt{?$k}'\n";
	}
    }
    print;
}

