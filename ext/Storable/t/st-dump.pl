#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

# NOTE THAT THIS FILE IS COPIED FROM ext/Storable/t/st-dump.pl
# TO t/lib/st-dump.pl.  One could also play games with
# File::Spec->updir and catdir to get the st-dump.pl in
# ext/Storable into $^INCLUDE_PATH.

sub num_equal($num, $left, $right, $name) {
        my $ok = ((defined $left) ?? $left == $right !! undef);
        unless (ok ($num, $ok, $name)) {
          print $^STDOUT, "# Expected $right\n";
          if (!defined $left) {
            print $^STDOUT, "# Got undef\n";
          } elsif ($left !~ m/[^0-9]/) {
            print $^STDOUT, "# Got $left\n";
          } else {
            $left =~ s/([^-a-zA-Z0-9_+])/$(sprintf "\\\%03o", ord $1)/g;
            print $^STDOUT, "# Got \"$left\"\n";
          }
        }
        $ok;
}

package dump;
use Carp;

my %dump = %(
	'SCALAR'	=> 'dump_scalar',
	'LVALUE'	=> 'dump_scalar',
	'ARRAY'		=> 'dump_array',
	'HASH'		=> 'dump_hash',
	'REF'		=> 'dump_ref',
);

our (%dumped, %object, $count, $dumped);

# Given an object, dump its transitive data closure
sub main::dump($object) {
	croak "Not a reference!" unless ref($object);
	local %dumped;
	local %object;
	local $count = 0;
	local $dumped = '';
	&recursive_dump($object, 1);
	return $dumped;
}

# This is the root recursive dumping routine that may indirectly be
# called by one of the routine it calls...
# The link parameter is set to false when the reference passed to
# the routine is an internal temporay variable, implying the object's
# address is not to be dumped in the %dumped table since it's not a
# user-visible object.
sub recursive_dump($object, $link) {

	# Get something like SCALAR(0x...) or TYPE=SCALAR(0x...).
	# Then extract the bless, ref and address parts of that string.

	my $what = dump::view($object);		# Stringify
	my @(?$bless, ?$ref, ?$addr) = @: $what =~ m/^(\w+)=(\w+)\((0x.*)\)$/;
	@($ref, $addr) = @: $what =~ m/^(\w+)\((0x.*)\)$/ unless $bless;

	# Special case for references to references. When stringified,
	# they appear as being scalars. However, ref() correctly pinpoints
	# them as being references indirections. And that's it.

	$ref = 'REF' if ref($object) eq 'REF';

	# Make sure the object has not been already dumped before.
	# We don't want to duplicate data. Retrieval will know how to
	# relink from the previously seen object.

	if ($link && %dumped{+$addr}++) {
		my $num = %object{?$addr};
		$dumped .= "OBJECT #$num seen\n";
		return;
	}

	my $objcount = $count++;
	%object{+$addr} = $objcount;

	# Call the appropriate dumping routine based on the reference type.
	# If the referenced was blessed, we bless it once the object is dumped.
	# The retrieval code will perform the same on the last object retrieved.

	croak "Unknown simple type '$ref'" unless defined %dump{?$ref};

	&{*{Symbol::fetch_glob(%dump{?$ref})}}($object);	# Dump object
	&bless($bless) if $bless;	# Mark it as blessed, if necessary

	$dumped .= "OBJECT $objcount\n";
}

# Indicate that current object is blessed
sub bless($class) {
	$dumped .= "BLESS $class\n";
}

# Dump single scalar
sub dump_scalar($sref) {
	my $scalar = $$sref;
	unless (defined $scalar) {
		$dumped .= "UNDEF\n";
		return;
	}
	my $len = length($scalar);
	$dumped .= "SCALAR len=$len $scalar\n";
}

# Dump array
sub dump_array($aref) {
	my $items = nelems @{$aref};
	$dumped .= "ARRAY items=$items\n";
	foreach my $item ( @{$aref}) {
		unless (defined $item) {
			$dumped .= 'ITEM_UNDEF' . "\n";
			next;
		}
		$dumped .= 'ITEM ';
		&recursive_dump(\$item, 1);
	}
}

# Dump hash table
sub dump_hash($href) {
	my $items = nelems(keys %{$href});
	$dumped .= "HASH items=$items\n";
	foreach my $key (sort keys %{$href}) {
		$dumped .= 'KEY ';
		&recursive_dump(\$key, undef);
		unless (defined $href->{?$key}) {
			$dumped .= 'VALUE_UNDEF' . "\n";
			next;
		}
		$dumped .= 'VALUE ';
		&recursive_dump(\$href->{+$key}, 1);
	}
}

# Dump reference to reference
sub dump_ref($rref) {
	my $deref = $$rref;				# Follow reference to reference
	$dumped .= 'REF ';
	&recursive_dump($deref, 1);		# $dref is a reference
}

1;
