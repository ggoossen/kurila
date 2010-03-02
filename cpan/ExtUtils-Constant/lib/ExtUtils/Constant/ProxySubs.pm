package ExtUtils::Constant::ProxySubs

our ($VERSION, @ISA, %type_to_struct, %type_from_struct, %type_to_sv
    ,    %type_to_C_value, %type_is_a_problem, %type_num_args
    ,    %type_temporary)
require ExtUtils::Constant::XS
use ExtUtils::Constant::Utils < qw(C_stringify)
use ExtUtils::Constant::XS < qw(%XS_TypeSet)

$VERSION = '0.06'
@ISA = @:  'ExtUtils::Constant::XS' 

%type_to_struct =
    %:
    IV => '{const char *name; I32 namelen; IV value;}'
    NV => '{const char *name; I32 namelen; NV value;}'
    UV => '{const char *name; I32 namelen; UV value;}'
    PV => '{const char *name; I32 namelen; const char *value;}'
    PVN => '{const char *name; I32 namelen; const char *value; STRLEN len;}'
    YES => '{const char *name; I32 namelen;}'
    NO => '{const char *name; I32 namelen;}'
    UNDEF => '{const char *name; I32 namelen;}'
    '' => '{const char *name; I32 namelen;} '
    

%type_from_struct =
    %:
    IV => sub (@< @_) { (@:  @_[0] . '->value' ) }
    NV => sub (@< @_) { (@:  @_[0] . '->value' ) }
    UV => sub (@< @_) { (@:  @_[0] . '->value' ) }
    PV => sub (@< @_) { (@:  @_[0] . '->value' ) }
    PVN => sub (@< @_) { (@:  @_[0] . '->value', @_[0] . '->len' ) }
    YES => sub (_) {}
    NO => sub (_) {}
    UNDEF => sub (_) {}
    '' => sub (_) {}
    

%type_to_sv =
    %:
    IV => sub (@< @_) { "newSViv(@_[0])" }
    NV => sub (@< @_) { "newSVnv(@_[0])" }
    UV => sub (@< @_) { "newSVuv(@_[0])" }
    PV => sub (@< @_) { "newSVpv(@_[0], 0)" }
    PVN => sub (@< @_) { "newSVpvn(@_[0], @_[1])" }
    YES => sub (@< @_) { '&PL_sv_yes' }
    NO => sub (@< @_) { '&PL_sv_no' }
    UNDEF => sub (@< @_) { '&PL_sv_undef' }
    '' => sub (@< @_) { '&PL_sv_yes' }
    SV => sub (@< @_) {"SvREFCNT_inc(@_[0])"}
    

%type_to_C_value =
    %:
    YES => sub (_) {}
    NO => sub (_) {}
    UNDEF => sub (_){}
    '' => sub (_) {}
    

sub type_to_C_value
    my (@: $self, $type) =  @_
    return %type_to_C_value{?$type} || sub (@< @_) {return @+: (map: {ref $_ ?? $_->@ !! (@: $_) }, @_) }


# TODO - figure out if there is a clean way for the type_to_sv code to
# attempt s/sv_2mortal// and if it succeeds tell type_to_sv not to add
# SvREFCNT_inc
%type_is_a_problem =
    %:
    # The documentation says *mortal SV*, but we now need a non-mortal copy.
    SV => 1
    

%type_temporary =
    %:
    SV => \(@: 'SV *')
    PV => \(@: 'const char *')
    PVN => \(@: 'const char *', 'STRLEN')
    
foreach (qw(IV UV NV))
    %type_temporary{+$_} = \@: $_

while (my (@: ?$type, ?$value) =(@:  each %XS_TypeSet))
    %type_num_args{+$type}
        = defined $value ?? ref $value ?? scalar nelems $value->@ !! 1 !! 0

%type_num_args{+''} = 0

sub partition_names($self, $default_type, @< @items)
    my (%found, @notfound, @trouble)

    while (my $item = shift @items)
        my $default = delete $item->{default}
        if ($default)
            # If we find a default value, convert it into a regular item and
            # append it to the queue of items to process
            my $default_item = \%: < $item->%
            $default_item->{+invert_macro} = 1
            $default_item->{+pre} = delete $item->{def_pre}
            $default_item->{+post} = delete $item->{def_post}
            $default_item->{+type} = shift $default->@
            $default_item->{+value} = $default
            push: @items, $default_item
        else
            # It can be "not found" unless it's the default (invert the macro)
            # or the "macro" is an empty string (ie no macro)
            push: @notfound, $item unless $item->{?invert_macro}
                or !$self->macro_to_ifdef:  ($self->macro_from_item: $item)
        

        if ($item->{?pre} or $item->{?post} or $item->{?not_constant}
            or %type_is_a_problem{?$item->{?type}})
            push: @trouble, $item
        else
            push: %found{+$item->{?type}}, $item
        
    
    # use Data::Dumper; print Dumper \%found;
    return @: \%found, \@notfound, \@trouble


sub boottime_iterator($self, $type, $iterator, $hash, $subname)
    my $extractor = %type_from_struct{?$type}
    die: "Can't find extractor code for type $type"
        unless defined $extractor
    my $generator = %type_to_sv{?$type}
    die: "Can't find generator code for type $type"
        unless defined $generator

    my $athx = $self->C_constant_prefix_param

    return sprintf: <<"EOBOOT", $generator->& <:  <( $extractor->& <: $iterator)
        while ($iterator->name) \{
	    $subname($athx $hash, $iterator->name,
				$iterator->namelen, \%s);
	    ++$iterator;
	\}
EOBOOT


sub name_len_value_macro($self, $item)
    my $name = $item->{?name}
    my $value = $item->{?value}
    $value = $item->{?name} unless defined $value

    my $namelen = length $name
    $name = C_stringify: $name

    my $macro = $self->macro_from_item: $item
    return @: $name, $namelen, $value, $macro


sub WriteConstants
    my $self = shift
    my $ARGS = \%: < @_

    my @: $c_fh, $xs_fh, $c_subname, $xs_subname, $default_type, $package
        = $ARGS->{[qw(C_FH XS_FH C_SUBNAME XS_SUBNAME DEFAULT_TYPE NAME)]}

    my $options = $ARGS->{?PROXYSUBS}
    $options = \$% unless ref $options
    my $explosives = $options->{?croak_on_read}

    $xs_subname ||= 'constant'

    # If anyone is insane enough to suggest a package name containing %
    my $package_sprintf_safe = $package
    $package_sprintf_safe =~ s/%/\%\%/g

    # All the types we see
    my $what = \$%
    # A hash to lookup items with.
    my $items = \$%

    my @items = $self->normalise_items : \(%: disable_utf8_duplication => 1)
                                         $default_type, $what, $items
                                         < $ARGS->{NAMES}->@

    # Partition the values by type. Also include any defaults in here
    # Everything that doesn't have a default needs alternative code for
    # "I'm missing"
    # And everything that has pre or post code ends up in a private block
    my @: $found, $notfound, $trouble
        =  $self->partition_names: $default_type, < @items

    my $pthx = $self->C_constant_prefix_param_defintion
    my $athx = $self->C_constant_prefix_param
    my $symbol_table = C_stringify: $package

    print: $c_fh, $self->header, <<"EOADD"
static void
$($c_subname)_add_symbol($pthx HV *hash, const char *name, I32 namelen, SV *value) \{
        ENTER;
        SAVESPTR(PL_curstash);
        HVcpREPLACE(PL_curstash, hash);
	newCONSTSUB(name, value);
        LEAVE;
\}

EOADD

    print: $c_fh, $explosives ?? <<"EXPLODE" !! "\n"

static int
Im_sorry_Dave(pTHX_ SV *sv, MAGIC *mg)
\{
    PERL_UNUSED_ARG(mg);
    Perl_croak(aTHX_
	       "Your vendor has not defined $package_sprintf_safe macro \%"SVf
	       " used", sv);
    NORETURN_FUNCTION_END;
\}

static MGVTBL not_defined_vtbl = \{
 Im_sorry_Dave, /* get - I'm afraid I can't do that */
 Im_sorry_Dave, /* set */
 0, /* len */
 0, /* clear */
 0, /* free */
 0, /* copy */
 0, /* dup */
\};

EXPLODE

    do
        my $key = $symbol_table
        # Just seems tidier (and slightly more space efficient) not to have keys
        # such as Fcntl::
        $key =~ s/::$//
        my $key_len = length $key

        print: $c_fh, <<"MISSING"

#ifndef SYMBIAN

/* Store a hash of all symbols missing from the package. To avoid trampling on
   the package namespace (uninvited) put each package's hash in our namespace.
   To avoid creating lots of typeblogs and symbol tables for sub-packages, put
   each package's hash into one hash in our namespace.  */

static HV *
get_missing_hash(pTHX) \{
    HV *const parent
	= get_hv("ExtUtils::Constant::ProxySubs::Missing", GVf_MULTI);
    /* We could make a hash of hashes directly, but this would confuse anything
	at Perl space that looks at us, and as we're visible in Perl space,
	best to play nice. */
    SV *const *const ref
	= hv_fetch(parent, "$key", $key_len, TRUE);
    HV *new_hv;

    if (!ref)
	return NULL;

    if (SvROK(*ref))
	return (HV*) SvRV(*ref);

    new_hv = newHV();
    SvUPGRADE(*ref, SVt_IV);
    SvRV_set(*ref, (SV *)new_hv);
    SvROK_on(*ref);
    return new_hv;
\}

#endif

MISSING

    

    print: $xs_fh, <<"EOBOOT"
BOOT:
  \{
#ifdef dTHX
    dTHX;
#endif
    HV *symbol_table = gv_stashpvn("$symbol_table", $(length $symbol_table), GV_ADD);
#ifndef SYMBIAN
    HV *$($c_subname)_missing;
#endif
EOBOOT

    my %iterator

    $found->{+''}
        = map: {\(%: < $_->%, type=>'', invert_macro => 1)}, $notfound->@

    foreach my $type ((sort: keys $found->%))
        my $struct = %type_to_struct{?$type}
        my $type_to_value = $self->type_to_C_value: $type
        my $number_of_args = %type_num_args{?$type}
        die: "Can't find structure definition for type $type"
            unless defined $struct

        my $struct_type = $type ?? (lc: $type) . '_s' !! 'notfound_s'
        print: $c_fh, "struct $struct_type $struct;\n"

        my $array_name = 'values_for_' . ($type ?? lc $type !! 'notfound')
        print: $xs_fh, <<"EOBOOT"

    static const struct $struct_type $array_name\[] =
      \{
EOBOOT


        foreach my $item ( $found->{$type})
            my @: $name, $namelen, $value, $macro
                =  $self->name_len_value_macro: $item

            my $ifdef = $self->macro_to_ifdef: $macro
            if (!$ifdef && $item->{?invert_macro})
                carp: "Attempting to supply a default for '$name' which has no conditional macro"
                next
            
            print: $xs_fh, $ifdef
            if ($item->{?invert_macro})
                print: $xs_fh
                       "        /* This is the default value: */\n" if $type
                print: $xs_fh, "#else\n"
            
            print: $xs_fh, "        \{ ", (join: ', ', (@:  "\"$name\"", $namelen
                                                            <( $type_to_value->& <: $value))), " \},\n"
                   $self->macro_to_endif: $macro
        


        # Terminate the list with a NULL
        print: $xs_fh, "        \{ NULL, 0", (", 0" x $number_of_args), " \} \};\n"

        %iterator{+$type} = "value_for_" . ($type ?? lc $type !! 'notfound')

        print: $xs_fh, <<"EOBOOT"
	const struct $struct_type *%iterator{?$type} = $array_name;
EOBOOT
    

    delete $found->{''}

    print: $xs_fh, <<"EOBOOT"
#ifndef SYMBIAN
	$($c_subname)_missing = get_missing_hash(aTHX);
#endif
EOBOOT

    my $add_symbol_subname = $c_subname . '_add_symbol'
    foreach my $type ((sort: keys $found->%))
        print: $xs_fh, $self->boottime_iterator: $type, %iterator{?$type}
                                                 'symbol_table'
                                                 $add_symbol_subname
    

    print: $xs_fh, <<"EOBOOT"
	while (value_for_notfound->name) \{
EOBOOT

    print: $xs_fh, $explosives ?? <<"EXPLODE" !! << "DONT"
	    SV *tripwire = newSV(0);
	    
	    sv_magicext(tripwire, 0, PERL_MAGIC_ext, &not_defined_vtbl, 0, 0);
	    SvPV_set(tripwire, (char *)value_for_notfound->name);
	    if(value_for_notfound->namelen >= 0) \{
		SvCUR_set(tripwire, value_for_notfound->namelen);
	    \} else \{
		SvCUR_set(tripwire, -value_for_notfound->namelen);
	    \}
	    SvPOKp_on(tripwire);
	    SvREADONLY_on(tripwire);
	    assert(SvLEN(tripwire) == 0);

	    $add_symbol_subname($athx symbol_table, value_for_notfound->name,
				value_for_notfound->namelen, tripwire);
EXPLODE
            SV* namesv = sv_2mortal(newSVpvn("$($symbol_table)::", $((length: $symbol_table) + 2)));
            sv_catpvn(namesv, value_for_notfound->name, value_for_notfound->namelen);
	    GV *gv = gv_fetchsv(namesv, GV_ADD, SVt_PVCV);
	    if (!gv) \{
		Perl_croak(aTHX_
			   "Couldn't add key '$($package_sprintf_safe)::\%s'",
			   value_for_notfound->name);
	    \}
            CV* notfoundcv = gv_fetchmethod(symbol_table, "constant_not_found");
            if (!notfoundcv) \{
		Perl_croak(aTHX_ "'constant_not_found' could not be found");
            \}
            sv_setsv((SV*)gv, sv_2mortal(newRV_inc(cvTsv(notfoundcv))));
#ifndef SYMBIAN
	    hv_store($($c_subname)_missing, value_for_notfound->name,
			  value_for_notfound->namelen, &PL_sv_yes, 0);
#endif
DONT

    print: $xs_fh, <<"EOBOOT"

	    ++value_for_notfound;
	\}
EOBOOT

    foreach my $item ( $trouble->@)
        my @: $name, $namelen, $value, $macro
            =  $self->name_len_value_macro: $item
        my $ifdef = $self->macro_to_ifdef: $macro
        my $type = $item->{?type}
        my $type_to_value = $self->type_to_C_value: $type

        print: $xs_fh, $ifdef
        if ($item->{?invert_macro})
            print: $xs_fh
                   "        /* This is the default value: */\n" if $type
            print: $xs_fh, "#else\n"
        
        my $generator = %type_to_sv{?$type}
        die: "Can't find generator code for type $type"
            unless defined $generator

        print: $xs_fh, "        \{\n"
        # We need to use a temporary value because some really troublesome
        # items use C pre processor directives in their values, and in turn
        # these don't fit nicely in the macro-ised generator functions
        my $counter = 0
        foreach (%type_temporary{$type}->@)
            printf: $xs_fh, "            \%s temp\%d;\n", $_, $counter++

        print: $xs_fh, "            $item->{?pre}\n" if $item->{?pre}

        # And because the code in pre might be both declarations and
        # statements, we can't declare and assign to the temporaries in one.
        $counter = 0
        foreach (($type_to_value->& <: $value))
            printf: $xs_fh, "            temp\%d = \%s;\n", $counter++, $_

        my @tempvarnames = map: {(sprintf: 'temp%d', $_)}, 0 .. $counter - 1
        printf: $xs_fh, <<"EOBOOT", $name, $generator->& <: <@tempvarnames
	    $($c_subname)_add_symbol($athx symbol_table, "\%s",
				    $namelen, \%s);
EOBOOT
        print: $xs_fh, "        $item->{?post}\n" if $item->{?post}
        print: $xs_fh, "        \}\n"

        print: $xs_fh, $self->macro_to_endif: $macro
    

    print: $xs_fh, <<EOBOOT
    /* As we've been creating subroutines, we better invalidate any cached
       methods  */
    ++PL_sub_generation;
  \}

void
constant_not_found()
    PPCODE:
	Perl_croak(aTHX_ "Your vendor has not defined the requested $package_sprintf_safe macro");

EOBOOT

    print: $xs_fh, $explosives ?? <<"EXPLODE" !! <<"DONT"

void
$xs_subname(sv)
    INPUT:
	SV *		sv;
    PPCODE:
	sv = newSVpvf(aTHX_ "Your vendor has not defined $package_sprintf_safe macro \%" SVf
			  ", used", sv);
        PUSHs(sv_2mortal(sv));
EXPLODE

void
$xs_subname(sv)
    PREINIT:
	STRLEN		len;
    INPUT:
	SV *		sv;
        const char *	s = SvPV(sv, len);
    PPCODE:
#ifdef SYMBIAN
	sv = newSVpvf("\%"SVf" is not a valid $package_sprintf_safe macro", sv);
#else
	HV *$($c_subname)_missing = get_missing_hash(aTHX);
	if (hv_exists($($c_subname)_missing, s, (I32)len)) \{
	    sv = newSVpvf(aTHX_ "Your vendor has not defined $package_sprintf_safe macro \%" SVf
			  ", used", sv);
	\} else \{
	    sv = newSVpvf(aTHX_ "\%"SVf" is not a valid $package_sprintf_safe macro",
			  sv);
	\}
#endif
	PUSHs(sv_2mortal(sv));
DONT



1
