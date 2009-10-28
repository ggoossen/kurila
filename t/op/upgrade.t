#!./perl -w

# Check that we can "upgrade" from anything to anything else.
# Curiously, before this, lib/Math/Trig.t was the only code anywhere in the
# build or testsuite that upgraded an NV to an RV

BEGIN 
    require './test.pl'


my $null

$^OS_ERROR = 1
my %types = %:
    null => $null
    iv => 3
    nv => .5
    rv => \$@
    pv => "Perl rules"
    pviv => 3
    pvnv => 1==1

# This is somewhat cheating but I can't think of anything built in that I can
# copy that already has type PVIV
%types{+pviv} = "Perl rules!"

%types{+pvmg} = "Perl rules!!"
study: %types{pvmg}

# use Devel::Peek; Dump $pvmg;

my @keys = keys %types
plan: tests => (nelems @keys) * nelems @keys

foreach my $source_type ( @keys)
    foreach my $dest_type ( @keys)
        # Pads re-using variables might contaminate this
        my $vars = \$%
        $vars->{+dest} = %types{?$dest_type}
        $vars->{+source} = %types{?$source_type}
        # The assignment can potentially trigger assertion failures, so it's
        # useful to have the diagnostics about what was attempted printed first
        print: $^STDOUT, "# Assigning $source_type to $dest_type\n"
        $vars->{+dest} = $vars->{?source}
        cmp_ok: $vars->{?dest}, ((ref $vars->{?source}) ?? '\==' !! 'eq'), $vars->{?source}
    

