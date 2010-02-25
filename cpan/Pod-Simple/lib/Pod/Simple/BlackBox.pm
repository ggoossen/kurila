
package Pod::Simple::BlackBox
#
# "What's in the box?"  "Pain."
#
###########################################################################
#
# This is where all the scary things happen: parsing lines into
#  paragraphs; and then into directives, verbatims, and then also
#  turning formatting sequences into treelets.
#
# Are you really sure you want to read this code?
#
#-----------------------------------------------------------------------------
#
# The basic work of this module Pod::Simple::BlackBox is doing the dirty work
# of parsing Pod into treelets (generally one per non-verbatim paragraph), and
# to call the proper callbacks on the treelets.
#
# Every node in a treelet is a ['name', {attrhash}, ...children...]

use integer # vroom!

BEGIN 
    *DEBUG = sub (@< @_){0} unless exists &DEBUG


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

sub parse_line {( shift->parse_lines: < @_) } # alias

# - - -  Turn back now!  Run away!  - - -

sub parse_lines             # Usage: $parser->parse_lines(@lines)
    # an undef means end-of-stream
    my $self = shift

    my $code_handler = $self->{?'code_handler'}
    my $cut_handler  = $self->{?'cut_handler'}
    $self->{+'line_count'} ||= 0

    my $scratch

    (DEBUG: )+> 4 and
        print: $^STDOUT, "# Parsing starting at line ", $self->{?'line_count'}, ".\n"

    (DEBUG: )+> 5 and
        print: $^STDOUT, "#  About to parse lines: "
               (join: ' ', (map: { (defined: $_) ?? "[$_]" !! "EOF" }, @_)), "\n"

    my $paras = ($self->{+'paras'} ||= \$@)
    # paragraph buffer.  Because we need to defer processing of =over
    # directives and verbatim paragraphs.  We call _ponder_paragraph_buffer
    # to process this.

    $self->{+'pod_para_count'} ||= 0

    my $line
    foreach my $source_line ( @_)
        if( $self->{?'source_dead'} )
            (DEBUG: )+> 4 and print: $^STDOUT, "# Source is dead.\n"
            last
        

        unless( defined $source_line )
            (DEBUG: )+> 4 and print: $^STDOUT, "# Undef-line seen.\n"

            push: $paras->@, \@: '~end', \%: 'start_line' => $self->{?'line_count'}
            push: $paras->@, $paras->[-1], $paras->[-1]
            # So that it definitely fills the buffer.
            $self->{+'source_dead'} = 1
            $self->_ponder_paragraph_buffer: 
            next

        if( $self->{+'line_count'}++ )
            ($line = $source_line) =~ s/[\n\r]//g
        # If we don't have two vars, we'll end up with that there
        # tr/// modding the (potentially read-only) original source line!

        else
            (DEBUG: )+> 2 and print: $^STDOUT, "First line: [$source_line]\n"

            if( ($line = $source_line) =~ s/^\xEF\xBB\xBF//s )
                DEBUG: and print: $^STDOUT, "UTF-8 BOM seen.  Faking a '=encoding utf8'.\n"
                $self->_handle_encoding_line:  "=encoding utf8" 
                $line =~ s/[\n\r]//g

            elsif( $line =~ s/^\xFE\xFF//s )
                DEBUG: and print: $^STDOUT, "Big-endian UTF-16 BOM seen.  Aborting parsing.\n"
                $self->scream: 
                    $self->{?'line_count'}
                    "UTF16-BE Byte Encoding Mark found; but Pod::Simple v$Pod::Simple::VERSION doesn't implement UTF16 yet."
                    
                splice: @_
                push: @_, undef
                next

            # TODO: implement somehow?

            elsif( $line =~ s/^\xFF\xFE//s )
                DEBUG: and print: $^STDOUT, "Little-endian UTF-16 BOM seen.  Aborting parsing.\n"
                $self->scream: 
                    $self->{?'line_count'}
                    "UTF16-LE Byte Encoding Mark found; but Pod::Simple v$Pod::Simple::VERSION doesn't implement UTF16 yet."
                    
                splice: @_
                push: @_, undef
                next

            # TODO: implement somehow?

            else
                (DEBUG: )+> 2 and print: $^STDOUT, "First line is BOM-less.  Faking a '=encoding latin1'.\n"
                $self->_handle_encoding_line:  "=encoding latin1" 
                ($line = $source_line) =~ s/[\n\r]//g
            
        


        (DEBUG: )+> 5 and print: $^STDOUT, "# Parsing line: [$line]\n"

        if(!$self->{?'in_pod'})
            if($line =~ m/^=([a-zA-Z]+)/s)
                if($1 eq 'cut')
                    $self->scream: 
                        $self->{?'line_count'}
                        "=cut found outside a pod block.  Skipping to next block."
                        

                    ## Before there were errata sections in the world, it was
                    ## least-pessimal to abort processing the file.  But now we can
                    ## just barrel on thru (but still not start a pod block).
                    #splice @_;
                    #push @_, undef;

                    next
                else
                    $self->{+'in_pod'} = $self->{+'start_of_pod_block'}
                        = $self->{+'last_was_blank'}     = 1
                # And fall thru to the pod-mode block further down
                
            else
                (DEBUG: )+> 5 and print: $^STDOUT, "# It's a code-line.\n"
                $code_handler->& <: < (map: { $_ }, (@:  $line, $self->{?'line_count'}, $self))
                    if $code_handler
                # Note: this may cause code to be processed out of order relative
                #  to pods, but in order relative to cuts.

                # Note also that we haven't yet applied the transcoding to $line
                #  by time we call $code_handler!

                if( $line =~ m/^#\s*line\s+(\d+)\s*(?:\s"([^"]+)")?\s*$/ )
                    # That RE is from perlsyn, section "Plain Old Comments (Not!)",
                    #$fname = $2 if defined $2;
                    #DEBUG > 1 and defined $2 and print "# Setting fname to \"$fname\"\n";
                    (DEBUG: )+> 1 and print: $^STDOUT, "# Setting nextline to $1\n"
                    $self->{+'line_count'} = $1 - 1
                

                next
            
        

        # . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
        # Else we're in pod mode:

        # Apply any necessary transcoding:
        $self->{?'_transcoder'} && $self->{?'_transcoder'}->& <: $line

        # HERE WE CATCH =encoding EARLY!
        if( $line =~ m/^=encoding\s+\S+\s*$/s )
            $line = $self->_handle_encoding_line:  $line 
        

        if($line =~ m/^=cut/s)
            # here ends the pod block, and therefore the previous pod para
            (DEBUG: )+> 1 and print: $^STDOUT, "Noting =cut at line $self->{?'line_count'}\n"
            $self->{+'in_pod'} = 0
            # ++$self->{'pod_para_count'};
            $self->_ponder_paragraph_buffer: 
            # by now it's safe to consider the previous paragraph as done.
            $cut_handler->& <: < (map: { $_ }, (@:  $line, $self->{?'line_count'}, $self))
                if $cut_handler

        # TODO: add to docs: Note: this may cause cuts to be processed out
        #  of order relative to pods, but in order relative to code.

        elsif($line =~ m/^\s*$/s)  # it's a blank line
            if(!$self->{?'start_of_pod_block'} and nelems $paras->@ and $paras->[-1]->[0] eq '~Verbatim')
                (DEBUG: )+> 1 and print: $^STDOUT, "Saving blank line at line $self->{?'line_count'}\n"
                push: $paras->[-1]->@, $line
              # otherwise it's not interesting

            if(!$self->{?'start_of_pod_block'} and !$self->{?'last_was_blank'})
                (DEBUG: )+> 1 and print: $^STDOUT, "Noting para ends with blank line at $self->{?'line_count'}\n"
            

            $self->{+'last_was_blank'} = 1

        elsif($self->{?'last_was_blank'})  # A non-blank line starting a new para...

            if($line =~ m/^(=[a-zA-Z][a-zA-Z0-9]*)(?:\s+|$)(.*)/s)
                # THIS IS THE ONE PLACE WHERE WE CONSTRUCT NEW DIRECTIVE OBJECTS
                my $new = \(@: $1, \(%: 'start_line' => $self->{?'line_count'}), $2)
                # Note that in "=head1 foo", the WS is lost.
                # Example: ['=head1', {'start_line' => 123}, ' foo']

                ++$self->{+'pod_para_count'}

                $self->_ponder_paragraph_buffer: 
                # by now it's safe to consider the previous paragraph as done.

                push: $paras->@, $new # the new incipient paragraph
                (DEBUG: )+> 1 and print: $^STDOUT, "Starting new $paras->[-1]->[0] para at line $self->{?'line_count'}\n"

            elsif($line =~ m/^\s/s)

                if(!$self->{?'start_of_pod_block'} and nelems $paras->@ and $paras->[-1]->[0] eq '~Verbatim')
                    (DEBUG: )+> 1 and print: $^STDOUT, "Resuming verbatim para at line $self->{?'line_count'}\n"
                    push: $paras->[-1]->@, $line
                else
                    ++$self->{+'pod_para_count'}
                    $self->_ponder_paragraph_buffer: 
                    # by now it's safe to consider the previous paragraph as done.
                    (DEBUG: )+> 1 and print: $^STDOUT, "Starting verbatim para at line $self->{?'line_count'}\n"
                    push: $paras->@, \@: '~Verbatim', \(%: 'start_line' => $self->{?'line_count'}), $line
                
            else
                ++$self->{+'pod_para_count'}
                $self->_ponder_paragraph_buffer: 
                # by now it's safe to consider the previous paragraph as done.
                push: $paras->@, \@: '~Para',  \(%: 'start_line' => $self->{?'line_count'}), $line
                (DEBUG: )+> 1 and print: $^STDOUT, "Starting plain para at line $self->{?'line_count'}\n"
            
            $self->{+'last_was_blank'} = $self->{+'start_of_pod_block'} = 0

        else
            # It's a non-blank line /continuing/ the current para
            if((nelems $paras->@))
                (DEBUG: )+> 2 and print: $^STDOUT, "Line $self->{?'line_count'} continues current paragraph\n"
                push: $paras->[-1]->@, $line
            else
                # Unexpected case!
                die: "Continuing a paragraph but \@\$paras is empty?"
            
            $self->{+'last_was_blank'} = $self->{+'start_of_pod_block'} = 0
        

     # ends the big while loop

    (DEBUG: )+> 1 and print: $^STDOUT,  <(pretty: < $paras->@), "\n"
    return $self


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

sub _handle_encoding_line($self, $line)

    # The point of this routine is to set $self->{'_transcoder'} as indicated.

    return $line unless $line =~ m/^=encoding\s+(\S+)\s*$/s
    (DEBUG: )+> 1 and print: $^STDOUT, "Found an encoding line \"=encoding $1\"\n"

    my $e    = $1
    my $orig = $e
    push: $self->{+'encoding_command_reqs'}, "=encoding $orig"

    my $enc_error

    # Cf.   perldoc Encode   and   perldoc Encode::Supported

    require Pod::Simple::Transcode

    if (
        # OK, let's turn on the encoding
        do
            (DEBUG: )+> 1 and print: $^STDOUT, " Setting encoding to $e\n"
            $self->{+'encoding'} = $e
            1
        and $e eq 'HACKRAW'
        )
        DEBUG: and print: $^STDOUT, " Putting in HACKRAW (no-op) encoding mode.\n"
        $self->{+'_transcoder'} = undef

    elsif( (Pod::Simple::Transcode->encoding_is_available: $e) )

        require Pod::Simple::Transcode
        $self->{+'_transcoder'} = Pod::Simple::Transcode->make_transcoder: $e
        try {
            my @x = (@: '', "abc", "123");(
            $self->{?'_transcoder'}->& <: < @x);
        }
        $^EVAL_ERROR && die: ( $enc_error =
                                  "Really unexpected error setting up encoding $e: $(($^EVAL_ERROR->message: ))\nAborting")
            

    else
        my @supported = Pod::Simple::Transcode->all_encodings: 

        # Note unsupported, and complain
        DEBUG: and print: $^STDOUT, " Encoding [$e] is unsupported."
                          "\nSupporteds: $((join: ' ',@supported))\n"
        my $suggestion = ''

        # Look for a near match:
        my $norm = lc: $e
        $norm =~ s/[-_]//g
        my $n
        foreach my $enc ( @supported)
            $n = lc: $enc
            $n =~ s/[-_]//g
            next unless $n eq $norm
            $suggestion = "  (Maybe \"$e\" should be \"$enc\"?)"
            last
        
        my $encmodver = Pod::Simple::Transcode->encmodver: 
        $enc_error = join: '', @:
                               "This document probably does not appear as it should, because its "
                               "\"=encoding $e\" line calls for an unsupported encoding."
                               $suggestion, "  [$encmodver\'s supported encodings are: $((join: ' ',@supported))]"
        

        $self->scream:  $self->{?'line_count'}, $enc_error 
    
    push: $self->{+'encoding_command_statuses'}, $enc_error

    return '=encoding ALREADYDONE'


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub _handle_encoding_second_level($self, $para)
    my @x = $para->@
    my $content = join: ' ', @:  splice: @x, 2
    $content =~ s/^\s+//s
    $content =~ s/\s+$//s

    (DEBUG: )+> 2 and print: $^STDOUT, "Ogling encoding directive: =encoding $content\n"

    if($content eq 'ALREADYDONE')
        # It's already been handled.  Check for errors.
        if(! $self->{?'encoding_command_statuses'} )
            (DEBUG: )+> 2 and print: $^STDOUT, " CRAZY ERROR: It wasn't really handled?!\n"
        elsif( $self->{'encoding_command_statuses'}[-1] )
            $self->whine:  $para->[1]->{?'start_line'}
                           sprintf: "Couldn't do \%s: \%s"
                                    $self->{'encoding_command_reqs'  }[-1]
                                    $self->{'encoding_command_statuses'}[-1]
                
        else
            (DEBUG: )+> 2 and print: $^STDOUT, " (Yup, it was successfully handled already.)\n"
        

    else
        # Otherwise it's a syntax error
        $self->whine:  $para->[1]->{?'start_line'}
                       "Invalid =encoding syntax: $content"
            
    

    return


#~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`~`

do
    my $m = -321   # magic line number

    sub _gen_errata($self)
        # Return 0 or more fake-o paragraphs explaining the accumulated
        #  errors on this document.

        return $@ unless $self->{?'errata'}

        my @out

        foreach my $line (sort: {$a <+> $b}, keys $self->{?'errata'})
            push: @out
                  \(@: '=item', \(%: 'start_line' => $m), "Around line $line:")
                  < map:  { \(@: '~Para', \(%: 'start_line' => $m, '~cooked' => 1)
                              #['~Top', {'start_line' => $m},
                                 $_
                    #]
                                  ) }, $self->{'errata'}{$line}
                      

        # TODO: report of unknown entities? unrenderable characters?

        unshift: @out
                 \(@: '=head1', \(%: 'start_line' => $m, 'errata' => 1), 'POD ERRORS')
                 \(@: '~Para', \%: 'start_line' => $m, '~cooked' => 1, 'errata' => 1
                      "Hey! "
                      \@: 'B', \$%
                          'The above document had some coding errors, which are explained below:'
                     )
                 \ @: '=over',  \(%: 'start_line' => $m, 'errata' => 1), ''

        push: @out
              \(@: '=back',  \(%: 'start_line' => $m, 'errata' => 1), '')

        DEBUG: and print: $^STDOUT, "\n<<\n", < (pretty: \@out), "\n>>\n\n"

        return @out



#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

##############################################################################
##
##  stop reading now stop reading now stop reading now stop reading now stop
##
##                         HERE IT BECOMES REALLY SCARY
##
##  stop reading now stop reading now stop reading now stop reading now stop
##
##############################################################################

sub _ponder_paragraph_buffer($self)

    # Para-token types as found in the buffer.
    #   ~Verbatim, ~Para, ~end, =head1..4, =for, =begin, =end,
    #   =over, =back, =item
    #   and the null =pod (to be complained about if over one line)
    #
    # "~data" paragraphs are something we generate at this level, depending on
    # a currently open =over region

    # Events fired:  Begin and end for:
    #                   directivename (like head1 .. head4), item, extend,
    #                   for (from =begin...=end, =for),
    #                   over-bullet, over-number, over-text, over-block,
    #                   item-bullet, item-number, item-text,
    #                   Document,
    #                   Data, Para, Verbatim
    #                   B, C, longdirname (TODO -- wha?), etc. for all directives
    #

    my $paras
    return unless nelems: ($paras = $self->{?'paras'})->@
    my $curr_open = ($self->{+'curr_open'} ||= \$@)

    my $scratch

    (DEBUG: )+> 10 and print: $^STDOUT, "# Paragraph buffer: <<", < (pretty: $paras), ">>\n"

    # We have something in our buffer.  So apparently the document has started.
    unless($self->{?'doc_has_started'})
        $self->{+'doc_has_started'} = 1

        my $starting_contentless
        $starting_contentless =
            (
          !nelems $curr_open->@
          and nelems $paras->@ and ! grep: { $_->[0] ne '~end' }, $paras->@
            # i.e., if the paras is all ~ends
            )
        
        DEBUG: and print: $^STDOUT, "# Starting "
                          $starting_contentless ?? 'contentless' !! 'contentful'
                          " document\n"

        $self->_handle_element_start: 
            ($scratch = 'Document')
            \ %:
                'start_line' => $paras->[0]->[1]->{?'start_line'}
                $starting_contentless ?? ( 'contentless' => 1 ) !! ()

    my($para, $para_type)
    while($paras->@)
        last if (nelems $paras->@) == 1 and
          ( $paras->[0]->[0] eq '=over' or $paras->[0]->[0] eq '~Verbatim'
              or $paras->[0]->[0] eq '=item' )
        
        # Those're the three kinds of paragraphs that require lookahead.
        #   Actually, an "=item Foo" inside an <over type=text> region
        #   and any =item inside an <over type=block> region (rare)
        #   don't require any lookahead, but all others (bullets
        #   and numbers) do.

        # TODO: winge about many kinds of directives in non-resolving =for regions?
        # TODO: many?  like what?  =head1 etc?

        $para = shift $paras->@
        $para_type = $para->[0]

        (DEBUG: )+> 1 and print: $^STDOUT, "Pondering a $para_type paragraph, given the stack: (", <
                                     ($self->_dump_curr_open: ), ")\n"

        if($para_type eq '=for')
            next if $self->_ponder_for: $para,$curr_open,$paras

        elsif($para_type eq '=begin')
            next if $self->_ponder_begin: $para,$curr_open,$paras

        elsif($para_type eq '=end')
            next if $self->_ponder_end: $para,$curr_open,$paras

        elsif($para_type eq '~end') # The virtual end-document signal
            next if $self->_ponder_doc_end: $para,$curr_open,$paras
        


        # ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
        #~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
        if((grep: { $_->[1]->{?'~ignore'} }, $curr_open->@))
            (DEBUG: )+> 1 and
                print: $^STDOUT, "Skipping $para_type paragraph because in ignore mode.\n"
            next
        
        #~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
        # ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

        if($para_type eq '=pod')
            $self->_ponder_pod: $para,$curr_open,$paras

        elsif($para_type eq '=over')
            next if $self->_ponder_over: $para,$curr_open,$paras

        elsif($para_type eq '=back')
            next if $self->_ponder_back: $para,$curr_open,$paras

        else

            # All non-magical codes!!!

            # Here we start using $para_type for our own twisted purposes, to
            #  mean how it should get treated, not as what the element name
            #  should be.

            (DEBUG: )+> 1 and print: $^STDOUT, "Pondering non-magical $para_type\n"

            my $i

            # Enforce some =headN discipline
            if($para_type =~ m/^=head\d$/s
                 and ! $self->{?'accept_heads_anywhere'}
                 and nelems $curr_open->@
                 and $curr_open->[-1]->[0] eq '=over'
                )
                (DEBUG: )+> 2 and print: $^STDOUT, "'=$para_type' inside an '=over'!\n"
                $self->whine: 
                    $para->[1]->{?'start_line'}
                    "You forgot a '=back' before '$para_type'"
                    
                unshift: $paras->@, \(@: '=back', \$%, ''), $para   # close the =over
                next
            


            if($para_type eq '=item')

                my $over
                unless((nelems $curr_open->@) and ($over = $curr_open->[-1])->[0] eq '=over')
                    $self->whine: 
                        $para->[1]->{?'start_line'}
                        "'=item' outside of any '=over'"
                        
                    unshift: $paras->@
                             \(@: '=over', \(%: 'start_line' => $para->[1]->{?'start_line'}), '')
                             $para
                    
                    next
                


                my $over_type = $over->[1]->{?'~type'}

                if(!$over_type)
                    # Shouldn't happen1
                    die: "Typeless over in stack, starting at line "
                             . $over->[1]->{?'start_line'}

                elsif($over_type eq 'block')
                    unless($curr_open->[-1]->[1]->{?'~bitched_about'})
                        $curr_open->[-1]->[1]->{+'~bitched_about'} = 1
                        $self->whine: 
                            $curr_open->[-1]->[1]->{?'start_line'}
                            "You can't have =items (as at line "
                                . $para->[1]->{?'start_line'}
                                . ") unless the first thing after the =over is an =item"
                            
                    
                    # Just turn it into a paragraph and reconsider it
                    $para->[0] = '~Para'
                    unshift: $paras->@, $para
                    next

                elsif($over_type eq 'text')
                    my $item_type = $self->_get_item_type: $para
                    # That kills the content of the item if it's a number or bullet.
                    DEBUG: and print: $^STDOUT, " Item is of type ", $para->[0], " under $over_type\n"

                    if($item_type eq 'text') {
                    # Nothing special needs doing for 'text'
                    }elsif($item_type eq 'number' or $item_type eq 'bullet')
                        die: "Unknown item type $item_type"
                            unless $item_type eq 'number' or $item_type eq 'bullet'
                        # Undo our clobbering:
                        push: $para->@, $para->[1]->{?'~orig_content'}
                        delete $para->[1]->{'number'}
                    # Only a PROPER item-number element is allowed
                    #  to have a number attribute.
                    else
                        die: "Unhandled item type $item_type" # should never happen
                    

                # =item-text thingies don't need any assimilation, it seems.

                elsif($over_type eq 'number')
                    my $item_type = $self->_get_item_type: $para
                    # That kills the content of the item if it's a number or bullet.
                    DEBUG: and print: $^STDOUT, " Item is of type ", $para->[0], " under $over_type\n"

                    my $expected_value = ++ $curr_open->[-1]->[1]->{+'~counter'}

                    if($item_type eq 'bullet')
                        # Hm, it's not numeric.  Correct for this.
                        $para->[1]->{+'number'} = $expected_value
                        $self->whine: 
                            $para->[1]->{?'start_line'}
                            "Expected '=item $expected_value'"
                            
                        push: $para->@, $para->[1]->{?'~orig_content'}
                    # restore the bullet, blocking the assimilation of next para

                    elsif($item_type eq 'text')
                        # Hm, it's not numeric.  Correct for this.
                        $para->[1]->{+'number'} = $expected_value
                        $self->whine: 
                            $para->[1]->{?'start_line'}
                            "Expected '=item $expected_value'"
                            
                    # Text content will still be there and will block next ~Para

                    elsif($item_type ne 'number')
                        die: "Unknown item type $item_type" # should never happen

                    elsif($expected_value == $para->[1]->{?'number'})
                        (DEBUG: )+> 1 and print: $^STDOUT, " Numeric item has the expected value of $expected_value\n"

                    else
                        (DEBUG: )+> 1 and print: $^STDOUT, " Numeric item has ", $para->[1]->{?'number'}
                                                 " instead of the expected value of $expected_value\n"
                        $self->whine: 
                            $para->[1]->{?'start_line'}
                            "You have '=item " . $para->[1]->{?'number'} .
                                "' instead of the expected '=item $expected_value'"
                            
                        $para->[1]->{+'number'} = $expected_value  # correcting!!
                    

                    if((nelems $para->@) == 2)
                        # For the cases where we /didn't/ push to @$para
                        if($paras->[0]->[0] eq '~Para')
                            DEBUG: and print: $^STDOUT, "Assimilating following ~Para content into $over_type item\n"
                            push: $para->@, splice: (shift $paras->@)->@,2
                        else
                            DEBUG: and print: $^STDOUT, "Can't assimilate following ", $paras->[0]->[0], "\n"
                            push: $para->@, ''  # Just so it's not contentless
                        
                    


                elsif($over_type eq 'bullet')
                    my $item_type = $self->_get_item_type: $para
                    # That kills the content of the item if it's a number or bullet.
                    DEBUG: and print: $^STDOUT, " Item is of type ", $para->[0], " under $over_type\n"

                    if($item_type eq 'bullet')
                        # as expected!

                        if( $para->[1]->{?'~_freaky_para_hack'} )
                            DEBUG: and print: $^STDOUT, "Accomodating '=item * Foo' tolerance hack.\n"
                            push: $para->@, delete $para->[1]->{'~_freaky_para_hack'}
                        

                    elsif($item_type eq 'number')
                        $self->whine: 
                            $para->[1]->{?'start_line'}
                            "Expected '=item *'"
                            
                        push: $para->@, $para->[1]->{?'~orig_content'}
                        # and block assimilation of the next paragraph
                        delete $para->[1]->{'number'}
                    # Only a PROPER item-number element is allowed
                    #  to have a number attribute.
                    elsif($item_type eq 'text')
                        $self->whine: 
                            $para->[1]->{?'start_line'}
                            "Expected '=item *'"
                            
                    # But doesn't need processing.  But it'll block assimilation
                    #  of the next para.
                    else
                        die: "Unhandled item type $item_type" # should never happen
                    

                    if((nelems $para->@) == 2)
                        # For the cases where we /didn't/ push to @$para
                        if($paras->[0]->[0] eq '~Para')
                            DEBUG: and print: $^STDOUT, "Assimilating following ~Para content into $over_type item\n"
                            push: $para->@, splice: (shift $paras->@)->@,2
                        else
                            DEBUG: and print: $^STDOUT, "Can't assimilate following ", $paras->[0]->[0], "\n"
                            push: $para->@, ''  # Just so it's not contentless
                        
                    

                else
                    die: "Unhandled =over type \"$over_type\"?"
                # Shouldn't happen!
                

                $para_type = 'Plain'
                $para->[0] .= '-' . $over_type
            # Whew.  Now fall thru and process it.


            elsif($para_type eq '=extend')
                # Well, might as well implement it here.
                $self->_ponder_extend: $para
                next  # and skip
            elsif($para_type eq '=encoding')
                # Not actually acted on here, but we catch errors here.
                $self->_handle_encoding_second_level: $para

                next  # and skip
            elsif($para_type eq '~Verbatim')
                $para->[0] = 'Verbatim'
                $para_type = '?Verbatim'
            elsif($para_type eq '~Para')
                $para->[0] = 'Para'
                $para_type = '?Plain'
            elsif($para_type eq 'Data')
                $para->[0] = 'Data'
                $para_type = '?Data'
            elsif( $para_type =~ s/^=//s
                and defined: ( $para_type = $self->{'accept_directives'}->{?$para_type}) 
                )
                (DEBUG: )+> 1 and print: $^STDOUT, " Pondering known directive $para->[0] as $para_type\n"
            else
                # An unknown directive!
                (DEBUG: )+> 1 and printf: $^STDOUT, "Unhandled directive \%s (Handled: \%s)\n"
                                          $para->[0], join: ' ', (sort: keys $self->{?'accept_directives'}->%) 
                
                $self->whine: 
                    $para->[1]->{?'start_line'}
                    "Unknown directive: $para->[0]"
                    

                # And maybe treat it as text instead of just letting it go?
                next
            

            if($para_type =~ s/^\?//s)
                if(! nelems $curr_open->@)  # usual case
                    DEBUG: and print: $^STDOUT, "Treating $para_type paragraph as such because stack is empty.\n"
                else
                    my @fors = grep: { $_->[0] eq '=for' }, $curr_open->@
                    (DEBUG: )+> 1 and print: $^STDOUT, "Containing fors: "
                                             (join: ',', (map: { $_->[1]->{?'target'} }, @fors)), "\n"

                    if(! nelems @fors)
                        DEBUG: and print: $^STDOUT, "Treating $para_type paragraph as such because stack has no =for's\n"

                    #} elsif(grep $_->[1]{'~resolve'}, @fors) {
                    #} elsif(not grep !$_->[1]{'~resolve'}, @fors) {
                    elsif( @fors[-1]->[1]->{?'~resolve'} )
                        # Look to the immediately containing for

                        if($para_type eq 'Data')
                            DEBUG: and print: $^STDOUT, "Treating Data paragraph as Plain/Verbatim because the containing =for (@fors[-1]->[1]->{?'target'}) is a resolver\n"
                            $para->[0] = 'Para'
                            $para_type = 'Plain'
                        else
                            DEBUG: and print: $^STDOUT, "Treating $para_type paragraph as such because the containing =for (@fors[-1]->[1]->{?'target'}) is a resolver\n"
                        
                    else
                        DEBUG: and print: $^STDOUT, "Treating $para_type paragraph as Data because the containing =for (@fors[-1]->[1]->{?'target'}) is a non-resolver\n"
                        $para->[0] = $para_type = 'Data'
                    
                
            

            #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            if($para_type eq 'Plain')
                $self->_ponder_Plain: $para
            elsif($para_type eq 'Verbatim')
                $self->_ponder_Verbatim: $para
            elsif($para_type eq 'Data')
                $self->_ponder_Data: $para
            else
                die: "\$para type is $para_type -- how did that happen?"
            # Shouldn't happen.
            

            #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            $para->[0] =~ s/^[~=]//s

            DEBUG: and print: $^STDOUT, "\n", (pretty: $para), "\n"

            # traverse the treelet (which might well be just one string scalar)
            $self->{+'content_seen'} ||= 1
            $self->_traverse_treelet_bit: < $para->@

    return


###########################################################################
# The sub-ponderers...



sub _ponder_for($self,$para,$curr_open,$paras)

    # Fake it out as a begin/end
    my $target

    if((grep: { $_->[1]->{?'~ignore'} }, $curr_open->@))
        (DEBUG: )+> 1 and print: $^STDOUT, "Ignoring ignorable =for\n"
        return 1
    

    for my $i (2 .. (nelems: $para->@) -1)
        if($para->[$i] =~ s/^\s*(\S+)\s*//s)
            $target = $1
            last
        
    
    unless(defined $target)
        $self->whine: 
            $para->[1]->{?'start_line'}
            "=for without a target?"
            
        return 1
    
    (DEBUG: )+> 1 and
        print: $^STDOUT, "Faking out a =for $target as a =begin $target / =end $target\n"

    $para->[0] = 'Data'

    unshift: $paras->@
             \(@: '=begin'
                  \%: 'start_line' => $para->[1]->{?'start_line'}, '~really' => '=for'
                  $target
                 )
             $para
             \(@: '=end'
                  \%: 'start_line' => $para->[1]->{?'start_line'}, '~really' => '=for'
                  $target
                 )

    return 1


sub _ponder_begin($self,$para,$curr_open,$paras)
    my $content = join: ' ', @:  splice: $para->@, 2
    $content =~ s/^\s+//s
    $content =~ s/\s+$//s
    unless((length: $content))
        $self->whine: 
            $para->[1]->{?'start_line'}
            "=begin without a target?"
            
        DEBUG: and print: $^STDOUT, "Ignoring targetless =begin\n"
        return 1
    

    unless($content =~ m/^\S+$/s)  # i.e., unless it's one word
        $self->whine: 
            $para->[1]->{?'start_line'}
            "'=begin' only takes one parameter, not several as in '=begin $content'"
            
        DEBUG: and print: $^STDOUT, "Ignoring unintelligible =begin $content\n"
        return 1
    


    $para->[1]->{+'target'} = $content  # without any ':'

    $content =~ s/^:!/!:/s
    my $neg  # whether this is a negation-match
    $neg = 1        if $content =~ s/^!//s
    my $to_resolve  # whether to process formatting codes
    $to_resolve = 1 if $content =~ s/^://s

    my $dont_ignore # whether this target matches us

    foreach my $target_name (@:  <
                                     split: ',', $content, -1
                                 $neg ?? () !! '*'
        )
        (DEBUG: )+> 2 and
            print: $^STDOUT, " Considering whether =begin $content matches $target_name\n"
        next unless $self->{'accept_targets'}->{?$target_name}

        (DEBUG: )+> 2 and
            print: $^STDOUT, "  It DOES match the acceptable target $target_name!\n"
        $to_resolve = 1
            if $self->{'accept_targets'}->{?$target_name} eq 'force_resolve'
        $dont_ignore = 1
        $para->[1]->{+'target_matching'} = $target_name
        last # stop looking at other target names
    

    if($neg)
        if( $dont_ignore )
            $dont_ignore = ''
            delete $para->[1]->{'target_matching'}
            (DEBUG: )+> 2 and print: $^STDOUT, " But the leading ! means that this is a NON-match!\n"
        else
            $dont_ignore = 1
            $para->[1]->{+'target_matching'} = '!'
            (DEBUG: )+> 2 and print: $^STDOUT, " But the leading ! means that this IS a match!\n"
        
    

    $para->[0] = '=for'  # Just what we happen to call these, internally
    $para->[1]->{+'~really'} ||= '=begin'
    $para->[1]->{+'~ignore'}   = (! $dont_ignore) || 0
    $para->[1]->{+'~resolve'}  = $to_resolve || 0

    (DEBUG: )+> 1 and print: $^STDOUT, " Making note to ", $dont_ignore ?? 'not ' !! ''
                             "ignore contents of this region\n"
    (DEBUG: )+> 1 and $dont_ignore and print: $^STDOUT, " Making note to treat contents as "
                                              ($to_resolve ?? 'verbatim/plain' !! 'data'), " paragraphs\n"
    (DEBUG: )+> 1 and print: $^STDOUT, " (Stack now: ", < ($self->_dump_curr_open: ), ")\n"

    push: $curr_open->@, $para
    if(!$dont_ignore or scalar (grep: { $_->[1]->{?'~ignore'} }, $curr_open->@))
        (DEBUG: )+> 1 and print: $^STDOUT, "Ignoring ignorable =begin\n"
    else
        $self->{+'content_seen'} ||= 1
        $self->_handle_element_start: (my $scratch='for'), $para->[1]
    

    return 1


sub _ponder_end($self,$para,$curr_open,$paras)
    my $content = join: ' ', @:  splice: $para->@, 2
    $content =~ s/^\s+//s
    $content =~ s/\s+$//s
    DEBUG: and print: $^STDOUT, "Ogling '=end $content' directive\n"

    unless((length: $content))
        $self->whine: 
            $para->[1]->{?'start_line'}
            "'=end' without a target?" . (
                ( (nelems $curr_open->@) and $curr_open->[-1]->[0] eq '=for' )
                ?? ( " (Should be \"=end " . $curr_open->[-1]->[1]->{?'target'} . '")' )
                !! ''
                )
            
        DEBUG: and print: $^STDOUT, "Ignoring targetless =end\n"
        return 1
    

    unless($content =~ m/^\S+$/)  # i.e., unless it's one word
        $self->whine: 
            $para->[1]->{?'start_line'}
            "'=end $content' is invalid.  (Stack: "
                . ($self->_dump_curr_open: ) . ')'
            
        DEBUG: and print: $^STDOUT, "Ignoring mistargetted =end $content\n"
        return 1
    

    unless((nelems $curr_open->@) and $curr_open->[-1]->[0] eq '=for')
        $self->whine: 
            $para->[1]->{?'start_line'}
            "=end $content without matching =begin.  (Stack: "
                . ($self->_dump_curr_open: ) . ')'
            
        DEBUG: and print: $^STDOUT, "Ignoring mistargetted =end $content\n"
        return 1
    

    unless($content eq $curr_open->[-1]->[1]->{?'target'})
        $self->whine: 
            $para->[1]->{?'start_line'}
            "=end $content doesn't match =begin "
                . $curr_open->[-1]->[1]->{?'target'}
                . ".  (Stack: "
                . ($self->_dump_curr_open: ) . ')'
            
        DEBUG: and print: $^STDOUT, "Ignoring mistargetted =end $content at line $para->[1]->{?'start_line'}\n"
        return 1
    

    # Else it's okay to close...
    if((grep: { $_->[1]->{?'~ignore'} }, $curr_open->@))
        (DEBUG: )+> 1 and print: $^STDOUT, "Not firing any event for this =end $content because in an ignored region\n"
    # And that may be because of this to-be-closed =for region, or some
    #  other one, but it doesn't matter.
    else
        $curr_open->[-1]->[1]->{+'start_line'} = $para->[1]->{?'start_line'}
        # what's that for?

        $self->{+'content_seen'} ||= 1
        $self->_handle_element_end: ( my $scratch = 'for') 
    
    (DEBUG: )+> 1 and print: $^STDOUT, "Popping $curr_open->[-1]->[0] $curr_open->[-1]->[1]->{?'target'} because of =end $content\n"
    pop $curr_open->@

    return 1


sub _ponder_doc_end($self,$para,$curr_open,$paras)
    if((nelems $curr_open->@)) # Deal with things left open
        DEBUG: and print: $^STDOUT, "Stack is nonempty at end-document: (", <
                              ($self->_dump_curr_open: ), ")\n"

        (DEBUG: )+> 9 and print: $^STDOUT, "Stack: ", < (pretty: $curr_open), "\n"
        unshift: $paras->@, < $self->_closers_for_all_curr_open: 
        # Make sure there is exactly one ~end in the parastack, at the end:
        $paras->@ = grep: { $_->[0] ne '~end' }, $paras->@
        push: $paras->@, $para, $para
        # We need two -- once for the next cycle where we
        #  generate errata, and then another to be at the end
        #  when that loop back around to process the errata.
        return 1

    else
        DEBUG: and print: $^STDOUT, "Okay, stack is empty now.\n"
    

    # Try generating errata section, if applicable
    unless($self->{?'~tried_gen_errata'})
        $self->{+'~tried_gen_errata'} = 1
        my @extras = $self->_gen_errata: 
        if((nelems @extras))
            unshift: $paras->@, < @extras
            DEBUG: and print: $^STDOUT, "Generated errata... relooping...\n"
            return 1  # I.e., loop around again to process these fake-o paragraphs
        
    

    splice: $paras->@ # Well, that's that for this paragraph buffer.
    DEBUG: and print: $^STDOUT, "Throwing end-document event.\n"

    $self->_handle_element_end: ( my $scratch = 'Document') 
    return 1 # Hasta la byebye


sub _ponder_pod($self,$para,$curr_open,$paras)
    $self->whine: 
        $para->[1]->{?'start_line'}
        "=pod directives shouldn't be over one line long!  Ignoring all "
            . ((nelems $para->@) - 2) . " lines of content"
         if (nelems $para->@) +> 3
    # Content is always ignored.
    return


sub _ponder_over($self,$para,$curr_open,$paras)
    return 1 unless (nelems $paras->@)
    my $list_type

    if($paras->[0]->[0] eq '=item') # most common case
        $list_type = $self->_get_initial_item_type: $paras->[0]

    elsif($paras->[0]->[0] eq '=back')
        # Ignore empty lists.  TODO: make this an option?
        shift $paras->@
        return 1

    elsif($paras->[0]->[0] eq '~end')
        $self->whine: 
            $para->[1]->{?'start_line'}
            "=over is the last thing in the document?!"
            
        return 1 # But feh, ignore it.
    else
        $list_type = 'block'
    
    $para->[1]->{+'~type'} = $list_type
    push: $curr_open->@, $para
    # yes, we reuse the paragraph as a stack item

    my $content = join: ' ', @:  splice: $para->@, 2
    my $overness
    if($content =~ m/^\s*$/s)
        $para->[1]->{+'indent'} = 4
    elsif($content =~ m/^\s*((?:\d*\.)?\d+)\s*$/s)
        no integer
        $para->[1]->{+'indent'} = $1
        if($1 == 0)
            $self->whine: 
                $para->[1]->{?'start_line'}
                "Can't have a 0 in =over $content"
                
            $para->[1]->{+'indent'} = 4
        
    else
        $self->whine: 
            $para->[1]->{?'start_line'}
            "=over should be: '=over' or '=over positive_number'"
            
        $para->[1]->{+'indent'} = 4
    
    (DEBUG: )+> 1 and print: $^STDOUT, "=over found of type $list_type\n"

    $self->{+'content_seen'} ||= 1
    $self->_handle_element_start: (my $scratch = 'over-' . $list_type), $para->[1]

    return


sub _ponder_back($self,$para,$curr_open,$paras)
    # TODO: fire off </item-number> or </item-bullet> or </item-text> ??

    my $content = join: ' ', @:  splice: $para->@, 2
    if($content =~ m/\S/)
        $self->whine: 
            $para->[1]->{?'start_line'}
            "=back doesn't take any parameters, but you said =back $content"
            
    

    if((nelems $curr_open->@) and $curr_open->[-1]->[0] eq '=over')
        (DEBUG: )+> 1 and print: $^STDOUT, "=back happily closes matching =over\n"
        # Expected case: we're closing the most recently opened thing
        #my $over = pop @$curr_open;
        $self->{+'content_seen'} ||= 1
        $self->_handle_element_end: ( my $scratch =
                                         'over-' . ( (pop $curr_open->@)->[1]->{?'~type'} ))
            
    else
        (DEBUG: )+> 1 and print: $^STDOUT, "=back found without a matching =over.  Stack: ("
                                 (join: ', ', (map: { $_->[0] }, $curr_open->@)), ").\n"
        $self->whine: 
            $para->[1]->{?'start_line'}
            '=back without =over'
            
        return 1 # and ignore it
    


sub _ponder_item($self,$para,$curr_open,$paras)
    my $over
    unless((nelems $curr_open->@) and ($over = $curr_open->[-1])->[0] eq '=over')
        $self->whine: 
            $para->[1]->{?'start_line'}
            "'=item' outside of any '=over'"
            
        unshift: $paras->@
                 \(@: '=over', \(%: 'start_line' => $para->[1]->{?'start_line'}), '')
                 $para
        
        return 1
    


    my $over_type = $over->[1]->{?'~type'}

    if(!$over_type)
        # Shouldn't happen1
        die: "Typeless over in stack, starting at line "
                 . $over->[1]->{?'start_line'}

    elsif($over_type eq 'block')
        unless($curr_open->[-1]->[1]->{?'~bitched_about'})
            $curr_open->[-1]->[1]->{+'~bitched_about'} = 1
            $self->whine: 
                $curr_open->[-1]->[1]->{?'start_line'}
                "You can't have =items (as at line "
                    . $para->[1]->{?'start_line'}
                    . ") unless the first thing after the =over is an =item"
                
        
        # Just turn it into a paragraph and reconsider it
        $para->[0] = '~Para'
        unshift: $paras->@, $para
        return 1

    elsif($over_type eq 'text')
        my $item_type = $self->_get_item_type: $para
        # That kills the content of the item if it's a number or bullet.
        DEBUG: and print: $^STDOUT, " Item is of type ", $para->[0], " under $over_type\n"

        if($item_type eq 'text') {
        # Nothing special needs doing for 'text'
        }elsif($item_type eq 'number' or $item_type eq 'bullet')
            die: "Unknown item type $item_type"
                unless $item_type eq 'number' or $item_type eq 'bullet'
            # Undo our clobbering:
            push: $para->@, $para->[1]->{?'~orig_content'}
            delete $para->[1]->{'number'}
        # Only a PROPER item-number element is allowed
        #  to have a number attribute.
        else
            die: "Unhandled item type $item_type" # should never happen
        

    # =item-text thingies don't need any assimilation, it seems.

    elsif($over_type eq 'number')
        my $item_type = $self->_get_item_type: $para
        # That kills the content of the item if it's a number or bullet.
        DEBUG: and print: $^STDOUT, " Item is of type ", $para->[0], " under $over_type\n"

        my $expected_value = ++ $curr_open->[-1]->[1]->{+'~counter'}

        if($item_type eq 'bullet')
            # Hm, it's not numeric.  Correct for this.
            $para->[1]->{+'number'} = $expected_value
            $self->whine: 
                $para->[1]->{?'start_line'}
                "Expected '=item $expected_value'"
                
            push: $para->@, $para->[1]->{?'~orig_content'}
        # restore the bullet, blocking the assimilation of next para

        elsif($item_type eq 'text')
            # Hm, it's not numeric.  Correct for this.
            $para->[1]->{+'number'} = $expected_value
            $self->whine: 
                $para->[1]->{?'start_line'}
                "Expected '=item $expected_value'"
                
        # Text content will still be there and will block next ~Para

        elsif($item_type ne 'number')
            die: "Unknown item type $item_type" # should never happen

        elsif($expected_value == $para->[1]->{?'number'})
            (DEBUG: )+> 1 and print: $^STDOUT, " Numeric item has the expected value of $expected_value\n"

        else
            (DEBUG: )+> 1 and print: $^STDOUT, " Numeric item has ", $para->[1]->{?'number'}
                                     " instead of the expected value of $expected_value\n"
            $self->whine: 
                $para->[1]->{?'start_line'}
                "You have '=item " . $para->[1]->{?'number'} .
                    "' instead of the expected '=item $expected_value'"
                
            $para->[1]->{+'number'} = $expected_value  # correcting!!
        

        if((nelems $para->@) == 2)
            # For the cases where we /didn't/ push to @$para
            if($paras->[0]->[0] eq '~Para')
                DEBUG: and print: $^STDOUT, "Assimilating following ~Para content into $over_type item\n"
                push: $para->@, splice: (shift $paras->@)->@,2
            else
                DEBUG: and print: $^STDOUT, "Can't assimilate following ", $paras->[0]->[0], "\n"
                push: $para->@, ''  # Just so it's not contentless
            
        


    elsif($over_type eq 'bullet')
        my $item_type = $self->_get_item_type: $para
        # That kills the content of the item if it's a number or bullet.
        DEBUG: and print: $^STDOUT, " Item is of type ", $para->[0], " under $over_type\n"

        if($item_type eq 'bullet')
            # as expected!

            if( $para->[1]->{?'~_freaky_para_hack'} )
                DEBUG: and print: $^STDOUT, "Accomodating '=item * Foo' tolerance hack.\n"
                push: $para->@, delete $para->[1]->{'~_freaky_para_hack'}
            

        elsif($item_type eq 'number')
            $self->whine: 
                $para->[1]->{?'start_line'}
                "Expected '=item *'"
                
            push: $para->@, $para->[1]->{?'~orig_content'}
            # and block assimilation of the next paragraph
            delete $para->[1]->{'number'}
        # Only a PROPER item-number element is allowed
        #  to have a number attribute.
        elsif($item_type eq 'text')
            $self->whine: 
                $para->[1]->{?'start_line'}
                "Expected '=item *'"
                
        # But doesn't need processing.  But it'll block assimilation
        #  of the next para.
        else
            die: "Unhandled item type $item_type" # should never happen
        

        if((nelems $para->@) == 2)
            # For the cases where we /didn't/ push to @$para
            if($paras->[0]->[0] eq '~Para')
                DEBUG: and print: $^STDOUT, "Assimilating following ~Para content into $over_type item\n"
                push: $para->@, splice: (shift $paras->@)->@,2
            else
                DEBUG: and print: $^STDOUT, "Can't assimilate following ", $paras->[0]->[0], "\n"
                push: $para->@, ''  # Just so it's not contentless
            
        

    else
        die: "Unhandled =over type \"$over_type\"?"
    # Shouldn't happen!
    
    $para->[0] .= '-' . $over_type

    return


sub _ponder_Plain($self,$para)
    DEBUG: and print: $^STDOUT, " giving plain treatment...\n"
    unless( (nelems $para->@) == 2 or ( (nelems $para->@) == 3 and $para->[2] eq '' )
        or $para->[1]->{?'~cooked'}
        )
        push: $para->@
              < ($self->_make_treelet: 
                  (join: "\n", (@:  (splice: $para->@, 2)))
                  $para->[1]->{'start_line'}
                  )->@
    
    # Empty paragraphs don't need a treelet for any reason I can see.
    # And precooked paragraphs already have a treelet.
    return


sub _ponder_Verbatim($self,$para)
    DEBUG: and print: $^STDOUT, " giving verbatim treatment...\n"

    $para->[1]->{+'xml:space'} = 'preserve'
    for my $i (2 .. (nelems: $para->@) -1)
        while( $para->[$i] =~
                 # Sort of adapted from Text::Tabs -- yes, it's hardwired in that
                 # tabs are at every EIGHTH column.  For portability, it has to be
                 # one setting everywhere, and 8th wins.
                 s/^([^\t]*)(\t+)/$($1.(" " x (((length: $2)<<3)-((length: $1)^&^7))))/
            ) {}
    # TODO: whinge about (or otherwise treat) unindented or overlong lines
    

    # Now the VerbatimFormatted hoodoo...
    if( $self->{?'accept_codes'} and
        $self->{'accept_codes'}->{?'VerbatimFormatted'}
        )
        while((nelems $para->@) +> 3 and $para->[-1] !~ m/\S/) { pop $para->@ }
        # Kill any number of terminal newlines
        $self->_verbatim_format: $para
    elsif ($self->{?'codes_in_verbatim'})
        push: $para->@
              < ($self->_make_treelet: 
                  (join: "\n", (@:  (splice: $para->@, 2)))
                  $para->[1]->{?'start_line'}, $para->[1]->{'xml:space'}
                  )->@
        $para->[-1] =~ s/\n+$//s # Kill any number of terminal newlines
    else
        push: $para->@, (join: "\n", (@:  (splice: $para->@, 2))) if (nelems $para->@) +> 3
        $para->[-1] =~ s/\n+$//s # Kill any number of terminal newlines
    
    return


sub _ponder_Data($self,$para)
    DEBUG: and print: $^STDOUT, " giving data treatment...\n"
    $para->[1]->{+'xml:space'} = 'preserve'
    push: $para->@, (join: "\n", (@:  (splice: $para->@, 2))) if (nelems $para->@) +> 3
    return





###########################################################################

sub _traverse_treelet_bit($self, $name, @< @_)  # for use only by the routine above

    my $scratch
    $self->_handle_element_start: ($scratch=$name), shift @_

    foreach my $x ( @_)
        if((ref: $x))
            _traverse_treelet_bit: $self, < $x->@
        else
            $self->_handle_text: $x

    $self->_handle_element_end: ($scratch=$name)
    return


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

sub _closers_for_all_curr_open($self)
    my @closers
    foreach my $still_open ( (  $self->{?'curr_open'} || return  )->@)
        my @copy = $still_open->@
        @copy[1] = \%: <  @copy[1]->%
        #$copy[1]{'start_line'} = -1;
        if(@copy[0] eq '=for')
            @copy[0] = '=end'
        elsif(@copy[0] eq '=over')
            @copy[0] = '=back'
        else
            die: "I don't know how to auto-close an open @copy[0] region"
        

        unless( (nelems @copy) +> 2 )
            push: @copy, @copy[1]->{?'target'}
            @copy[-1] = '' unless defined @copy[-1]
        # since =over's don't have targets
        

        DEBUG: and print: $^STDOUT, "Queuing up fake-o event: ", < (pretty: \@copy), "\n"
        unshift: @closers, \@copy
    
    return @closers


#--------------------------------------------------------------------------

sub _verbatim_format($it, $p)

    my $formatting

    for my $i (2 .. (nelems: $p->@) -1) # work backwards over the lines
        DEBUG: and print: $^STDOUT, "_verbatim_format appends a newline to $i: $p->[$i]\n"
        $p->[$i] .= "\n"
    # Unlike with simple Verbatim blocks, we don't end up just doing
    # a join("\n", ...) on the contents, so we have to append a
    # newline to ever line, and then nix the last one later.
    

    if( (DEBUG: )+> 4 )
        print: $^STDOUT, "<<\n"
        for my $i ((reverse: 2..(nelems $p->@)-1)) # work backwards over the lines
            print: $^STDOUT, "_verbatim_format $i: $p->[$i]"
        
        print: $^STDOUT, ">>\n"
    

    my $i = (nelems: $p->@)-1
    while ($i +>= 2)
        # work backwards over the lines, except the first (#2)

        #next unless $p->[$i]   =~ m{^#:([ \^\/\%]*)\n?$}s
        #        and $p->[$i-1] !~ m{^#:[ \^\/\%]*\n?$}s;
        # look at a formatty line preceding a nonformatty one
        (DEBUG: )+> 5 and print: $^STDOUT, "Scrutinizing line $i: $p->@[$i]\n"
        if($p->[$i]   =~ m{^#:([ \^\/\%]*)\n?$}s)
            (DEBUG: )+> 5 and print: $^STDOUT, "  It's a formatty line.  "
                                     "Peeking at previous line ", $i-1, ": $p->@[$i-1]: \n"

            if( $p->[$i-1] =~ m{^#:[ \^\/\%]*\n?$}s )
                (DEBUG: )+> 5 and print: $^STDOUT, "  Previous line is formatty!  Skipping this one.\n"
                next
            else
                (DEBUG: )+> 5 and print: $^STDOUT, "  Previous line is non-formatty!  Yay!\n"
            
        else
            (DEBUG: )+> 5 and print: $^STDOUT, "  It's not a formatty line.  Ignoring\n"
            next
        

        # A formatty line has to have #: in the first two columns, and uses
        # "^" to mean bold, "/" to mean underline, and "%" to mean bold italic.
        # Example:
        #   What do you want?  i like pie. [or whatever]
        # #:^^^^^^^^^^^^^^^^^              /////////////


        (DEBUG: )+> 4 and print: $^STDOUT, "_verbatim_format considers:\n<$p->[$i-1]>\n<$p->[$i]>\n"

        $formatting = '  ' . $1
        $formatting =~ s/\s+$//s # nix trailing whitespace
        unless(length $formatting and $p->[$i-1] =~ m/\S/) # no-op
            splice: $p->@,$i,1 # remove this line
            $i-- # don't consider next line
            next
        

        if( (length: $formatting) +>= (length: $p->[$i-1]) )
            $formatting = (substr: $formatting, 0, (length: $p->[$i-1]) - 1) . ' '
        else
            $formatting .= ' ' x ((length: $p->[$i-1]) - (length: $formatting))
        
        # Make $formatting and the previous line be exactly the same length,
        # with $formatting having a " " as the last character.

        (DEBUG: )+> 4 and print: $^STDOUT, "Formatting <$formatting>    on <", $p->[$i-1], ">\n"


        my @new_line
        while( $formatting =~ m{\G(( +)|(\^+)|(\/+)|(\%+))}g )
            #print "Format matches $1\n";

            if($2)
                #print "SKIPPING <$2>\n";
                push: @new_line
                      substr: $p->[$i-1], (pos: $formatting)-(length: $1), (length: $1)
            else
                #print "SNARING $+\n";
                push: @new_line, \@:
                          (
                              $3 ?? 'VerbatimB'  !!
                              $4 ?? 'VerbatimI'  !!
                              $5 ?? 'VerbatimBI' !! die: "Should never get called"
                              ), \$%
                          substr: $p->[$i-1], (pos: $formatting)-(length: $1), (length: $1)

            #print "Formatting <$new_line[-1][-1]> as $new_line[-1][0]\n";

        my @nixed = @:
            splice: $p->@, $i-1, 2, < @new_line  # replace myself and the next line
        (DEBUG: )+> 10 and print: $^STDOUT, "Nixed count: ", (scalar: nelems @nixed), "\n"

        (DEBUG: )+> 6 and print: $^STDOUT, "New version of the above line is these tokens ("
                                 (scalar: nelems @new_line), "):"
                                 < (map:  { (ref: $_)??"<$((join: ' ',$_->@))> "!!"<$_>" }, @new_line ), "\n"
        $i-- # So the next line we scrutinize is the line before the one
    #  that we just went and formatted
    continue
        $i--
    

    $p->[0] = 'VerbatimFormatted'

    # Collapse adjacent text nodes, just for kicks.
    $i = 2
    while ($i +< (nelems: $p->@)-2) # work forwards over the tokens except for the last
        if( !(ref: $p->[$i]) and !(ref: $p->[$i + 1]) )
            (DEBUG: )+> 5 and print: $^STDOUT, "_verbatim_format merges \{$p->[$i]\} and \{$p->[$i+1]\}\n"
            $p->[$i] .= splice: $p->@, $i+1, 1 # merge
            --$i  # and back up
        
        $i++
    

    # Now look for the last text token, and remove the terminal newline
    for my $i ((reverse:  2 .. (nelems $p->@)-1 ))
        # work backwards over the tokens, even the first
        if( !(ref: $p->[$i]) )
            if($p->[$i] =~ s/\n$//s)
                (DEBUG: )+> 5 and print: $^STDOUT, "_verbatim_format killed the terminal newline on #$i: \{$p->[$i]\}, after \{$p->[$i-1]\}\n"
            else
                (DEBUG: )+> 5 and print: $^STDOUT
                                         "No terminal newline on #$i: \{$p->[$i]\}, after \{$p->[$i-1]\} !?\n"
            
            last # we only want the next one
        
    

    return



#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


sub _treelet_from_formatting_codes($self, $para, $start_line, ?$preserve_space)

    my $treelet = \@: '~Top', \(%: 'start_line' => $start_line)

    unless ($preserve_space || $self->{?'preserve_whitespace'})
        use utf8
        $para =~ s/\.  /\.\x{A0} /g if $self->{?'fullstop_space_harden'}

        $para =~ s/[ \t\n\r\f]+/ /g # collapse and trim all whitespace first.
        $para =~ s/ $//
        $para =~ s/^ //
    

    # Only apparent problem the above code is that N<<  >> turns into
    # N<< >>.  But then, word wrapping does that too!  So don't do that!

    my @stack
    my @lineage = @: $treelet

    (DEBUG: )+> 4 and print: $^STDOUT, "Paragraph:\n$para\n\n"

    # Here begins our frightening tokenizer RE.  The following regex matches
    # text in four main parts:
    #
    #  * Start-codes.  The first alternative matches C< or C<<, the latter
    #    followed by some whitespace.  $1 will hold the entire start code
    #    (including any space following a multiple-angle-bracket delimiter),
    #    and $2 will hold only the additional brackets past the first in a
    #    multiple-bracket delimiter.  length($2) + 1 will be the number of
    #    closing brackets we have to find.
    #
    #  * Closing brackets.  Match some amount of whitespace followed by
    #    multiple close brackets.  The logic to see if this closes anything
    #    is down below.  Note that in order to parse C<<  >> correctly, we
    #    have to use look-behind (?<=\s\s), since the match of the starting
    #    code will have consumed the whitespace.
    #
    #  * A single closing bracket, to close a simple code like C<>.
    #
    #  * Something that isn't a start or end code.  We have to be careful
    #    about accepting whitespace, since perlpodspec says that any whitespace
    #    before a multiple-bracket closing delimiter should be ignored.
    #
    while($para =~
            m/\G
      (?:
        # Match starting codes, including the whitespace following a
        # multiple-delimiter start code.  $1 gets the whole start code and
        # $2 gets all but one of the <s in the multiple-bracket case.
        ([A-Z]<(?:(<+)\s+)?)
        |
        # Match multiple-bracket end codes.  $3 gets the whitespace that
        # should be discarded before an end bracket but kept in other cases
        # and $4 gets the end brackets themselves.
        (\s+|(?<=\s\s))(>{2,})
        |
        (\s?>)          # $5: simple end-codes
        |
        (               # $6: stuff containing no start-codes or end-codes
          (?:
            [^A-Z\s>]
            |
            (?:
              [A-Z](?!<)
            )
            |
            # whitespace is ok, but we don't want to eat the whitespace before
            # a multiple-bracket end code.
            # NOTE: we may still have problems with e.g. S<<    >>
            (?:
              \s(?!\s*>{2,})
            )
          )+
        )
      )
    /xg
        )
        (DEBUG: )+> 4 and print: $^STDOUT, "\nParagraphic tokenstack = ($((join: ' ',@stack)))\n"
        if(defined $1)
            if(defined $2)
                (DEBUG: )+> 3 and print: $^STDOUT, "Found complex start-text code \"$1\"\n"
                push: @stack, (length: $2) + 1
            # length of the necessary complex end-code string
            else
                (DEBUG: )+> 3 and print: $^STDOUT, "Found simple start-text code \"$1\"\n"
                push: @stack, 0  # signal that we're looking for simple

            push: @lineage, \@:  (substr: $1,0,1), \$%   # new node object
            push: @lineage[-2]->@, @lineage[-1]

        elsif(defined $4)
            (DEBUG: )+> 3 and print: $^STDOUT, "Found apparent complex end-text code \"$3$4\"\n"
            # This is where it gets messy...
            if(! nelems @stack)
                # We saw " >>>>" but needed nothing.  This is ALL just stuff then.
                (DEBUG: )+> 4 and print: $^STDOUT, " But it's really just stuff.\n"
                push: @lineage[-1]->@, $3, $4
                next
            elsif(!@stack[-1])
                # We saw " >>>>" but needed only ">".  Back pos up.
                (DEBUG: )+> 4 and print: $^STDOUT, " And that's more than we needed to close simple.\n"
                push: @lineage[-1]->@, $3 # That was a for-real space, too.
                pos: $para, (pos: $para) - (length: $4) + 1
            elsif(@stack[-1] == (length: $4))
                # We found " >>>>", and it was exactly what we needed.  Commonest case.
                (DEBUG: )+> 4 and print: $^STDOUT, " And that's exactly what we needed to close complex.\n"
            elsif(@stack[-1] +< (length: $4))
                # We saw " >>>>" but needed only " >>".  Back pos up.
                (DEBUG: )+> 4 and print: $^STDOUT, " And that's more than we needed to close complex.\n"
                pos: $para, (pos: $para) - (length: $4) + @stack[-1]
            else
                # We saw " >>>>" but needed " >>>>>>".  So this is all just stuff!
                (DEBUG: )+> 4 and print: $^STDOUT, " But it's really just stuff, because we needed more.\n"
                push: @lineage[-1]->@, $3, $4
                next
            
            #print "\nHOOBOY ", scalar(@{$lineage[-1]}), "!!!\n";

            push: @lineage[-1]->@, '' if 2 == nelems  @lineage[-1]->@
            # Keep the element from being childless

            pop @stack
            pop @lineage

        elsif(defined $5)
            (DEBUG: )+> 3 and print: $^STDOUT, "Found apparent simple end-text code \"$4\"\n"

            if((nelems @stack) and ! @stack[-1])
                # We're indeed expecting a simple end-code
                (DEBUG: )+> 4 and print: $^STDOUT, " It's indeed an end-code.\n"

                if((length: $5) == 2) # There was a space there: " >"
                    push: @lineage[-1]->@, ' '
                elsif( 2 == nelems  @lineage[-1]->@ ) # Closing a childless element
                    push: @lineage[-1]->@, '' # keep it from being really childless
                

                pop @stack
                pop @lineage
            else
                (DEBUG: )+> 4 and print: $^STDOUT, " It's just stuff.\n"
                push: @lineage[-1]->@, $5
            

        elsif(defined $6)
            (DEBUG: )+> 3 and print: $^STDOUT, "Found stuff \"$6\"\n"
            push: @lineage[-1]->@, $6

        else
            # should never ever ever ever happen
            DEBUG: and print: $^STDOUT, "AYYAYAAAAA at line ", __LINE__, "\n"
            die: "SPORK 512512!"
        
    

    if((nelems @stack)) # Uhoh, some sequences weren't closed.
        my $x= "..."
        while((nelems @stack))
            push: @lineage[-1]->@, '' if 2 == nelems  @lineage[-1]->@
            # Hmmmmm!

            my $code         = (pop @lineage)->[0]
            my $ender_length =  pop @stack
            if($ender_length)
                --$ender_length
                $x = $code . ("<" x $ender_length) . " $x " . (">" x $ender_length)
            else
                $x = $code . "<$x>"
            
        
        (DEBUG: )+> 1 and print: $^STDOUT, "Unterminated $x sequence\n"
        $self->whine: $start_line
                      "Unterminated $x sequence"
            
    

    return $treelet


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

sub text_content_of_treelet(_, $lol)  # method: $parser->text_content_of_treelet($lol)
    return stringify_lol: $lol


sub stringify_lol($lol)  # function: stringify_lol($lol)
    my $string_form = ''
    _stringify_lol:  $lol => \$string_form 
    return $string_form


sub _stringify_lol($lol, $to) {;
    use UNIVERSAL ();
    for my $i (2 .. (nelems: $lol->@) -1)
        if( ref: $lol->[$i] || '' and UNIVERSAL::isa: $lol->[$i], 'ARRAY' )
            _stringify_lol:  $lol->[$i], $to  # recurse!
        else
            $to->$ .= $lol->[$i]
        
    
    return;
}

#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

sub _dump_curr_open($self) # return a string representation of the stack
    my $curr_open = $self->{?'curr_open'}

    return '[empty]' unless (nelems $curr_open->@)
    return join: '; ', map: {;
                                ($_->[0] eq '=for')
                                    ?? ( ($_->[1]->{?'~really'} || '=over')
                                    . ' ' . $_->[1]->{?'target'})
                                    !! $_->[0]
                                },
                                $curr_open->@


###########################################################################
my %pretty_form = %:
    "\a" => '\a' # ding!
    "\b" => '\b' # BS
    "\e" => '\e' # ESC
    "\f" => '\f' # FF
    "\t" => '\t' # tab
    "\cm" => '\cm'
    "\cj" => '\cj'
    "\n" => '\n' # probably overrides one of either \cm or \cj
    '"' => '\"'
    '\' => '\\'
    '$' => '\$'
    '@' => '\@'
    '%' => '\%'
    '#' => '\#'
    

sub pretty(@< @stuff) # adopted from Class::Classless
    # Not the most brilliant routine, but passable.
    # Don't give it a cyclic data structure!
    my $x
    my $out =
        # join ",\n" .
        join: ", ", map: {;
                             if(!(defined: $_))
                                 "undef"
                             elsif((ref: $_) eq 'ARRAY' or (ref: $_) eq 'Pod::Simple::LinkSection')
                                 $x = "[ " . (pretty: < $_->@) . " ]"
                                 $x
                             elsif((ref: $_) eq 'SCALAR')
                                 $x = "\\" . pretty: $_->$
                                 $x
                             elsif((ref: $_) eq 'HASH')
                                 my $hr = $_
                                 $x = "\{" . (join: ", ", (map:  {(pretty: $_) . '=>' . (pretty: $hr->{?$_}) },
                                                                     (sort: keys $hr->%) ) ) . "\}"
                                 $x
                             elsif(!(length: $_)) { q{''} # empty string
                             }elsif(
                                 $_ eq '0' # very common case
                                 or(
                               m/^-?(?:[123456789]\d*|0)(?:\.\d+)?$/s
                                 and $_ ne '-0' # the strange case that that RE lets thru
                                 )
                                 ) { $_;
                             }else
                                 s<([^\x[20]\x[21]\x[23]\x[27]-\x[3F]\x[41]-\x[5B]\x[5D]-\x[7E]])>
                                  #<$pretty_form{$1} || '\\x'.(unpack("H2",$1))>eg;
                                  <$(%pretty_form{?$1} || '\\x['.(sprintf: "\%.2x", (ord: $1)) . ']')>g
                                 qq{"$_"}
                             }, @stuff
    # $out =~ s/\n */ /g if length($out) < 75;
    return $out


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

# A rather unsubtle method of blowing away all the state information
# from a parser object so it can be reused. Provided as a utility for
# backward compatibilty in Pod::Man, etc. but not recommended for
# general use.

sub reinit
    my $self = shift
    foreach (qw(source_dead source_filename doc_has_started
start_of_pod_block content_seen last_was_blank paras curr_open
line_count pod_para_count in_pod ~tried_gen_errata errata errors_seen
Title))

        delete $self->{$_}
    


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
1

