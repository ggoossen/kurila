
# Time-stamp: "2004-03-30 16:33:31 AST"

package Locale::Maketext

our (@ISA, $VERSION, $MATCH_SUPERS, $USING_LANGUAGE_TAGS,
    $USE_LITERALS, $MATCH_SUPERS_TIGHTLY)
use Carp ()
use I18N::LangTags v0.30 ()

#--------------------------------------------------------------------------

BEGIN { unless(exists &DEBUG) { *DEBUG = sub () {0} } }
# define the constant 'DEBUG' at compile-time

$VERSION = "1.10_01"
@ISA = $@

$MATCH_SUPERS = 1
$MATCH_SUPERS_TIGHTLY = 1
$USING_LANGUAGE_TAGS  = 1
# Turning this off is somewhat of a security risk in that little or no
# checking will be done on the legality of tokens passed to the
# eval("use $module_name") in _try_use.  If you turn this off, you have
# to do your own taint checking.

$USE_LITERALS = 1 unless defined $USE_LITERALS
# a hint for compiling bracket-notation things.

my %isa_scan = $%

###########################################################################

sub quant($handle, $num, @< @forms)

    return $num if (nelems @forms) == 0 # what should this mean?
    return @forms[2] if (nelems @forms) +> 2 and $num == 0 # special zeroth case

    # Normal case:
    # Note that the formatting of $num is preserved.
    return ($handle->numf: $num) . ' ' . $handle->numerate: $num, < @forms
# Most human languages put the number phrase before the qualified phrase.



sub numerate($handle, $num, @< @forms)
    my $s = ($num == 1)

    return '' unless (nelems @forms)
    if((nelems @forms) == 1) # only the headword form specified
        return $s ?? @forms[0] !!  @: @forms[0] . 's' # very cheap hack.
    else # sing and plural were specified
        return $s ?? @forms[0] !! @forms[1]



#--------------------------------------------------------------------------

sub numf
    my(@: $handle, $num) =  @_[[(@: 0,1)]]
    if($num +< 10_000_000_000 and $num +> -10_000_000_000 and $num == (int: $num))
        $num += 0  # Just use normal integer stringification.
    # Specifically, don't let %G turn ten million into 1E+007
    else
        $num = CORE::sprintf: "\%G", $num
    # "CORE::" is there to avoid confusion with the above sub sprintf.

    while( $num =~ s/^([-+]?\d+)(\d{3})/$1,$2/s ) {1}  # right from perlfaq5
    # The initial \d+ gobbles as many digits as it can, and then we
    #  backtrack so it un-eats the rightmost three, and then we
    #  insert the comma there.

    $num =~ s<(.,)><$($1 eq ',' ?? '.' !! ',')>g if ref: $handle and $handle->{?'numf_comma'}
    # This is just a lame hack instead of using Number::Format
    return $num


sub sprintf($handle, $format, @< @params)
    no integer

    return CORE::sprintf: $format, < @params
# "CORE::" is there to avoid confusion with myself!


#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#

use integer # vroom vroom... applies to the whole rest of the module

sub language_tag
    my $it = (ref: @_[0]) || @_[0]
    return undef unless $it =~ m/([^':]+)(?:::)?$/s
    $it = lc: $1
    $it =~ s<_><->g
    return $it


sub encoding
    my $it = @_[0]
    return @:
        ((ref: $it) && $it->{?'encoding'})
            || "iso-8859-1"   # Latin-1


#--------------------------------------------------------------------------

sub fallback_languages { return (@: 'i-default', 'en', 'en-US') }

sub fallback_language_classes { return () }

#--------------------------------------------------------------------------

sub fail_with($handle, @< @params)
    return unless ref: $handle
    $handle->{+'fail'} = @params[0] if (nelems @params)
    return $handle->{?'fail'}


#--------------------------------------------------------------------------

sub failure_handler_auto
    # Meant to be used like:
    #  $handle->fail_with('failure_handler_auto')

    my(@: $handle, $phrase, @< @params) =  @_
    $handle->{+'failure_lex'} ||= \$%
    my $lex = $handle->{?'failure_lex'}

    my $value
    $lex->{+$phrase} ||= ($value = ($handle->_compile: $phrase))

    # Dumbly copied from sub maketext:
    do
        try { $value =( $value->& <: $handle, < @_) }

    # If we make it here, there was an exception thrown in the
    #  call to $value, and so scream:
    if($^EVAL_ERROR)
        my $err = $^EVAL_ERROR
        # pretty up the error message
        $err =~ s<\s+at\s+\(eval\s+\d+\)\s+line\s+(\d+)\.?\n?>
             <\n in bracket code [compiled line $1],>s
        #$err =~ s/\n?$/\n/s;
        Carp::croak:  "Error in maketexting \"$phrase\":\n$err as used"
    # Rather unexpected, but suppose that the sub tried calling
    # a method that didn't exist.
    else
        return $value



#==========================================================================

sub new
    # Nothing fancy!
    my $class = (ref: @_[0]) || @_[0]
    my $handle = bless: \$%, $class
    $handle->init: 
    return $handle


sub init { return } # no-op

###########################################################################

sub maketext
    # Remember, this can fail.  Failure is controllable many ways.
    Carp::croak:  "maketext requires at least one parameter" unless (nelems @_) +> 1

    my(@: $handle, $phrase) = @: splice: @_,0,2

                               # Don't interefere with $@ in case that's being interpolated into the msg.
    local $^EVAL_ERROR

    # Look up the value:

    my $value
    foreach my $h_r (
        (%isa_scan{?(ref: $handle) || $handle} || ($handle->_lex_refs: ))->@
        )
        print: $^STDOUT, "* Looking up \"$phrase\" in $h_r\n" if DEBUG: 
        if(exists $h_r->{$phrase})
            print: $^STDOUT, "  Found \"$phrase\" in $h_r\n" if DEBUG: 
            unless((ref: ($value = $h_r->{?$phrase})))
                # Nonref means it's not yet compiled.  Compile and replace.
                $value = $h_r->{+$phrase} = $handle->_compile: $value

            last
        elsif($phrase !~ m/^_/s and $h_r->{?'_AUTO'})
            # it's an auto lex, and this is an autoable key!
            print: $^STDOUT, "  Automaking \"$phrase\" into $h_r\n" if DEBUG: 

            $value = $h_r->{+$phrase} = $handle->_compile: $phrase
            last

        print: $^STDOUT, "  Not found in $h_r, nor automakable\n" if (DEBUG: )+> 1
    # else keep looking


    unless((defined: $value))
        print: $^STDOUT, "! Lookup of \"$phrase\" in/under ", (ref: $handle) || $handle
               " fails.\n" if DEBUG: 
        if(ref: $handle and $handle->{?'fail'})
            print: $^STDOUT, "WARNING0: maketext fails looking for <$phrase>\n" if DEBUG: 
            my $fail
            if((ref::svtype: ($fail = $handle->{?'fail'})) eq 'CODE') # it's a sub reference
                return $fail->& <: $handle, $phrase, < @_
            # If it ever returns, it should return a good value.
            else # It's a method name
                return $handle->?$fail: $phrase, < @_
            # If it ever returns, it should return a good value.

        else
            # All we know how to do is this;
            Carp::croak: "maketext doesn't know how to say:\n$phrase\nas needed"



    return $value->$ if (ref: $value) eq 'SCALAR'
    return $value unless (ref::svtype: $value) eq 'CODE'

    do
        try { $value =( $value->& <: $handle, < @_) }

    # If we make it here, there was an exception thrown in the
    #  call to $value, and so scream:
    if($^EVAL_ERROR)
        my $err = $^EVAL_ERROR->message: 
        # pretty up the error message
        $err =~ s<\s+at\s+\(eval\s+\d+\)\s+line\s+(\d+)\.?\n?>
             <\n in bracket code [compiled line $1],>s
        #$err =~ s/\n?$/\n/s;
        die: "Error in maketexting \"$phrase\":\n$err as used"
    # Rather unexpected, but suppose that the sub tried calling
    # a method that didn't exist.
    else
        return $value



###########################################################################

sub get_handle($base_class, @< @languages)
    $base_class = (ref: $base_class) || $base_class
    # Complain if they use __PACKAGE__ as a project base class?

    if( (nelems @languages) )
        DEBUG: and print: $^STDOUT, "Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"
        if($USING_LANGUAGE_TAGS)   # An explicit language-list was given!
            @languages = @+: map: { @: $_, < (I18N::LangTags::alternate_language_tags: $_) },
                                      map: { (I18N::LangTags::locale2language_tag: $_) }, @languages
            DEBUG: and print: $^STDOUT, "Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"

    else
        @languages = $base_class->_ambient_langprefs: 


    @languages = $base_class->_langtag_munging: < @languages

    my %seen
    foreach my $module_name ( (map: { $base_class . "::" . $_ }, @languages) )
        next unless length $module_name # sanity
        next if %seen{+$module_name}++        # Already been here, and it was no-go
          || ! _try_use: $module_name # Try to use() it, but can't it.
        return $module_name->new:  # Make it!


    return undef # Fail!


###########################################################################

sub _langtag_munging($base_class, @< @languages)

    # We have all these DEBUG statements because otherwise it's hard as hell
    # to diagnose ifwhen something goes wrong.

    DEBUG: and print: $^STDOUT, "Lgs1: ", < (map:  {"<$_>" }, @languages), "\n"

    if($USING_LANGUAGE_TAGS)
        DEBUG: and print: $^STDOUT, "Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"
        @languages     = $base_class->_add_supers:  < @languages 

        push: @languages, < I18N::LangTags::panic_languages: < @languages
        DEBUG: and print: $^STDOUT, "After adding panic languages:\n"
                          " Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"

        push: @languages, < $base_class->fallback_languages: 
        # You are free to override fallback_languages to return empty-list!
        DEBUG: and print: $^STDOUT, "Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"

        @languages = map: {
                              my $it = $_;  # copy
                              $it = (lc: $it);
                              $it =~ s<-><_>g; # lc, and turn - to _
                              $it =~ s<[^_a-z0-9]><>g;  # remove all but a-z0-9_
                              $it;
                              }, @languages

        DEBUG: and print: $^STDOUT, "Nearing end of munging:\n"
                          " Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"
    else
        DEBUG: and print: $^STDOUT, "Bypassing language-tags.\n"
                          " Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"


    DEBUG: and print: $^STDOUT, "Before adding fallback classes:\n"
                      " Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"

    push: @languages, < $base_class->fallback_language_classes: 
    # You are free to override that to return whatever.

    DEBUG: and print: $^STDOUT, "Finally:\n"
                      " Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"

    return @languages


###########################################################################

sub _ambient_langprefs
    require I18N::LangTags::Detect
    return  (I18N::LangTags::Detect::detect: )


###########################################################################

sub _add_supers($base_class, @< @languages)

    if(!$MATCH_SUPERS)
        # Nothing
        DEBUG: and print: $^STDOUT, "Bypassing any super-matching.\n"
                          " Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"

    elsif( $MATCH_SUPERS_TIGHTLY )
        DEBUG: and print: $^STDOUT, "Before adding new supers tightly:\n"
                          " Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"
        @languages = I18N::LangTags::implicate_supers:  < @languages 
        DEBUG: and print: $^STDOUT, "After adding new supers tightly:\n"
                          " Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"

    else
        DEBUG: and print: $^STDOUT, "Before adding supers to end:\n"
                          " Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"
        @languages = I18N::LangTags::implicate_supers_strictly:  < @languages 
        DEBUG: and print: $^STDOUT, "After adding supers to end:\n"
                          " Lgs\@", __LINE__, ": ", < (map:  {"<$_>" }, @languages), "\n"


    return @languages


###########################################################################
#
# This is where most people should stop reading.
#
###########################################################################

use Locale::Maketext::GutsLoader

###########################################################################

my %tried = $%
# memoization of whether we've used this module, or found it unusable.

sub _try_use   # Basically a wrapper around "require Modulename"
    # "Many men have tried..."  "They tried and failed?"  "They tried and died."
    return %tried{?@_[0]} if exists %tried{@_[0]}  # memoization

    my $module = @_[0]   # ASSUME sane module name!
    do
        return (%tried{+$module} = 1)
            if (Symbol::fetch_glob: $module . "::Lexicon")->*->% or (Symbol::fetch_glob: $module . "::ISA")->*->@
    # weird case: we never use'd it, but there it is!


    print: $^STDOUT, " About to use $module ...\n" if DEBUG: 
    do
        eval "require $module" # used to be "use $module", but no point in that.

    if($^EVAL_ERROR)
        print: $^STDOUT, "Error using $module \: $^EVAL_ERROR\n" if (DEBUG: )+> 1
        return (%tried{+$module} = 0)
    else
        print: $^STDOUT, " OK, $module is used\n" if DEBUG: 
        return (%tried{+$module} = 1)



#--------------------------------------------------------------------------

sub _lex_refs  # report the lexicon references for this handle's class
    # returns an arrayREF!
    my $class = (ref: @_[0]) || @_[0]
    print: $^STDOUT, "Lex refs lookup on $class\n" if (DEBUG: )+> 1
    return %isa_scan{?$class} if exists %isa_scan{$class}  # memoization!

    my @lex_refs
    my $seen_r = (ref: @_[?1]) ?? @_[1] !! \$%

    if( (defined:  (Symbol::fetch_glob: $class . '::Lexicon')->*{'HASH'} ))
        push: @lex_refs, (Symbol::fetch_glob: $class . '::Lexicon')->*{'HASH'}
        print: $^STDOUT, "\%" . $class . "::Lexicon contains "
               (scalar: keys (Symbol::fetch_glob: $class . '::Lexicon')->*->%), " entries\n" if DEBUG: 


    # Implements depth(height?)-first recursive searching of superclasses.
    # In hindsight, I suppose I could have just used Class::ISA!
    foreach my $superclass ( (Symbol::fetch_glob: $class . "::ISA")->*->@)
        print: $^STDOUT, " Super-class search into $superclass\n" if DEBUG: 
        next if $seen_r->{+$superclass}++
        push: @lex_refs, < (_lex_refs: $superclass, $seen_r)->@  # call myself


    %isa_scan{+$class} = \@lex_refs # save for next time
    return \@lex_refs


sub clear_isa_scan { %isa_scan = $%; return; } # end on a note of simplicity!

###########################################################################
1

__END__

HEY YOU!  You need some FOOD!


  ~~ Tangy Moroccan Carrot Salad ~~

* 6 to 8 medium carrots, peeled and then sliced in 1/4-inch rounds
* 1/4 teaspoon chile powder (cayenne, chipotle, ancho, or the like)
* 1 tablespoon ground cumin
* 1 tablespoon honey
* The juice of about a half a big lemon, or of a whole smaller one
* 1/3 cup olive oil
* 1 tablespoon of fresh dill, washed and chopped fine
* Pinch of salt, maybe a pinch of pepper

Cook the carrots in a pot of boiling water until just tender -- roughly
six minutes.  (Just don't let them get mushy!)  Drain the carrots.

In a largish bowl, combine the lemon juice, the cumin, the chile
powder, and the honey.  Mix well.
Add the olive oil and whisk it together well.  Add the dill and stir.

Add the warm carrots to the bowl and toss it all to coat the carrots
well.  Season with salt and pepper, to taste.

Serve warm or at room temperature.

The measurements here are very approximate, and you should feel free to
improvise and experiment.  It's a very forgiving recipe.  For example,
you could easily halve or double the amount of cumin, or use chopped mint
leaves instead of dill, or lime juice instead of lemon, et cetera.

[end]

