
use Test::More
BEGIN { (plan: tests => 136) };

#use Pod::Simple::Debug (5);

#sub Pod::Simple::MANY_LINES () {1}
#sub Pod::Simple::PullParser::DEBUG () {1}


use Pod::Simple::PullParser

sub pump_it_up
    my $p = Pod::Simple::PullParser->new
    $p->set_source:  \( @_[0] ) 
    my(@t, $t)
    while($t = $p->get_token) { (push: @t, $t) }
    print: $^STDOUT, "# Count of tokens: ", (scalar: nelems @t), "\n"
    print: $^STDOUT, "#  I.e., \{", (join: "\n#       + ", (map: { (ref: $_) . ": " . $_->dump }, @t)), "\} \n"
    return @t


my @t

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

@t = pump_it_up: qq{\n\nProk\n\n=head1 Things\n\n=cut\n\nBzorch\n\n}

if((not: 
    is: (nelems:  (grep: { ref $_ and $_->can: 'type' }, @t)), 5
    ))
    is: 0,1, "Wrong token count. Failing subsequent tests.\n"
    for ( 1 .. 12 ) {(ok: 0)}
else
    is: @t[0]->type, 'start'
    is: @t[1]->type, 'start'
    is: @t[2]->type, 'text'
    is: @t[3]->type, 'end'
    is: @t[4]->type, 'end'

    is: @t[0]->tagname, 'Document'
    is: @t[1]->tagname, 'head1'
    is: @t[2]->text,    'Things'
    is: @t[3]->tagname, 'head1'
    is: @t[4]->tagname, 'Document'

    is: (@t[0]->attr: 'start_line'), '5'
    is: (@t[1]->attr: 'start_line'), '5'


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
@t = pump_it_up: 
    qq{Woowoo\n\n=over\n\n=item *\n\nStuff L<HTML::TokeParser>\n\n}
        . qq{=item *\n\nThings I<like that>\n\n=back\n\n=cut\n\n}

if(
    not:  (is: (nelems:  (grep: { ref $_ and $_->can: 'type' }, @t)) => 16) 
    )
    is: 0,1, "Wrong token count. Failing subsequent tests.\n"
    for ( 1 .. 32 ) {(ok: 0)}
else
    is: @t[ 0]->type, 'start'
    is: @t[ 1]->type, 'start'
    is: @t[ 2]->type, 'start'
    is: @t[ 3]->type, 'text'
    is: @t[ 4]->type, 'start'
    is: @t[ 5]->type, 'text'
    is: @t[ 6]->type, 'end'
    is: @t[ 7]->type, 'end'

    is: @t[ 8]->type, 'start'
    is: @t[ 9]->type, 'text'
    is: @t[10]->type, 'start'
    is: @t[11]->type, 'text'
    is: @t[12]->type, 'end'
    is: @t[13]->type, 'end'
    is: @t[14]->type, 'end'
    is: @t[15]->type, 'end'



    is: @t[ 0]->tagname, 'Document'
    is: @t[ 1]->tagname, 'over-bullet'
    is: @t[ 2]->tagname, 'item-bullet'
    is: @t[ 3]->text, 'Stuff '
    is: @t[ 4]->tagname, 'L'
    is: @t[ 5]->text, 'HTML::TokeParser'
    is: @t[ 6]->tagname, 'L'
    is: @t[ 7]->tagname, 'item-bullet'

    is: @t[ 8]->tagname, 'item-bullet'
    is: @t[ 9]->text, 'Things '
    is: @t[10]->tagname, 'I'
    is: @t[11]->text, 'like that'
    is: @t[12]->tagname, 'I'
    is: @t[13]->tagname, 'item-bullet'
    is: @t[14]->tagname, 'over-bullet'
    is: @t[15]->tagname, 'Document'

    is: (@t[4]->attr: "type"), "pod"



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
do
    print: $^STDOUT, "# Testing unget_token\n"

    my $p = Pod::Simple::PullParser->new
    $p->set_source:  \qq{\nBzorch\n\n=pod\n\nLala\n\n\=cut\n} 

    ok: 1
    my $t
    $t = $p->get_token
    ok: $t && $t->type, 'start'
    ok: $t && $t->tagname, 'Document'
    print: $^STDOUT, "# ungetting ($((dump::view: $t))).\n"
    $p->unget_token: $t
    ok: 1

    $t = $p->get_token
    ok: $t && $t->type, 'start'
    ok: $t && $t->tagname, 'Document'
    my @to_save = @: $t

    $t = $p->get_token
    ok: $t && $t->type, 'start'
    ok: $t && $t->tagname, 'Para'
    push: @to_save, $t

    print: $^STDOUT, "# ungetting ($((dump::view: \@to_save)).\n"
    $p->unget_token: < @to_save
    splice: @to_save


    $t = $p->get_token
    ok: $t && $t->type, 'start'
    ok: $t && $t->tagname, 'Document'

    $t = $p->get_token
    ok: $t && $t->type, 'start'
    ok: $t && $t->tagname, 'Para'

    ok: 1




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

do
    print: $^STDOUT, "# Testing pullparsing from an arrayref\n"
    my $p = Pod::Simple::PullParser->new
    ok: 1
    $p->set_source:  \(@: '','Bzorch', '','=pod', '', 'Lala', 'zaza', '', '=cut') 
    ok: 1
    my( @t, $t )
    while($t = $p->get_token)
        print: $^STDOUT, "# Got a token: ", $t->dump, "\n#\n"
        push: @t, $t
    
    ok: (scalar: nelems @t), 5 # count of tokens
    ok: @t[0]->type, 'start'
    ok: @t[1]->type, 'start'
    ok: @t[2]->type, 'text'
    ok: @t[3]->type, 'end'
    ok: @t[4]->type, 'end'

    ok: @t[0]->tagname, 'Document'
    ok: @t[1]->tagname, 'Para'
    ok: @t[2]->text,    'Lala zaza'
    ok: @t[3]->tagname, 'Para'
    ok: @t[4]->tagname, 'Document'


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

do
    print: $^STDOUT, "# Testing pullparsing from an arrayref with terminal newlines\n"
    my $p = Pod::Simple::PullParser->new
    ok: 1
    $p->set_source:  \ (map: { "$_\n" }, (@:
                                 '','Bzorch', '','=pod', '', 'Lala', 'zaza', '', '=cut')) 
    ok: 1
    my( @t, $t )
    while($t = $p->get_token)
        print: $^STDOUT, "# Got a token: ", $t->dump, "\n#\n"
        push: @t, $t
    
    ok: (scalar: nelems @t), 5 # count of tokens
    ok: @t[0]->type, 'start'
    ok: @t[1]->type, 'start'
    ok: @t[2]->type, 'text'
    ok: @t[3]->type, 'end'
    ok: @t[4]->type, 'end'

    ok: @t[0]->tagname, 'Document'
    ok: @t[1]->tagname, 'Para'
    ok: @t[2]->text,    'Lala zaza'
    ok: @t[3]->tagname, 'Para'
    ok: @t[4]->tagname, 'Document'


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

END { (unlink: "temp.pod") }
do
    print: $^STDOUT, "# Testing pullparsing from a file\n"
    my $p = Pod::Simple::PullParser->new
    ok: 1
    (open: my $out, ">", "temp.pod") || die: "Can't write-open temp.pod: $^OS_ERROR"
    print: $out
           < map: { "$_\n" }, @:
                      '','Bzorch', '','=pod', '', 'Lala', 'zaza', '', '=cut'
    
    close: $out
    ok: 1
    sleep 1

    $p->set_source: "temp.pod"

    my( @t, $t )
    while($t = $p->get_token)
        print: $^STDOUT, "# Got a token: ", $t->dump, "\n#\n"
        push: @t, $t
        print: $^STDOUT, "#  That's token number ", (scalar: nelems @t), "\n"
    
    ok: (scalar: nelems @t), 5 # count of tokens
    ok: @t[0]->type, 'start'
    ok: @t[1]->type, 'start'
    ok: @t[2]->type, 'text'
    ok: @t[3]->type, 'end'
    ok: @t[4]->type, 'end'

    ok: @t[0]->tagname, 'Document'
    ok: @t[1]->tagname, 'Para'
    ok: @t[2]->text,    'Lala zaza'
    ok: @t[3]->tagname, 'Para'
    ok: @t[4]->tagname, 'Document'


# ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

do
    print: $^STDOUT, "# Testing pullparsing from a glob\n"
    my $p = Pod::Simple::PullParser->new
    ok: 1
    (open: my $in, "<", "temp.pod") || die: "Can't read-open temp.pod: $^OS_ERROR"
    $p->set_source: \$in->*

    my( @t, $t )
    while($t = $p->get_token)
        print: $^STDOUT, "# Got a token: ", $t->dump, "\n#\n"
        push: @t, $t
        print: $^STDOUT, "#  That's token number ", (scalar: nelems @t), "\n"
    
    ok: (scalar: nelems @t), 5 # count of tokens
    ok: @t[0]->type, 'start'
    ok: @t[1]->type, 'start'
    ok: @t[2]->type, 'text'
    ok: @t[3]->type, 'end'
    ok: @t[4]->type, 'end'

    ok: @t[0]->tagname, 'Document'
    ok: @t[1]->tagname, 'Para'
    ok: @t[2]->text,    'Lala zaza'
    ok: @t[3]->tagname, 'Para'
    ok: @t[4]->tagname, 'Document'
    close: $in


# ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

do
    print: $^STDOUT, "# Testing pullparsing from a globref\n"
    my $p = Pod::Simple::PullParser->new
    ok: 1
    (open: my $in, "<", "temp.pod") || die: "Can't read-open temp.pod: $^OS_ERROR"
    $p->set_source: \$in->*

    my( @t, $t )
    while($t = $p->get_token)
        print: $^STDOUT, "# Got a token: ", $t->dump, "\n#\n"
        push: @t, $t
        print: $^STDOUT, "#  That's token number ", (scalar: nelems @t), "\n"
    
    ok: (scalar: nelems @t), 5 # count of tokens
    ok: @t[0]->type, 'start'
    ok: @t[1]->type, 'start'
    ok: @t[2]->type, 'text'
    ok: @t[3]->type, 'end'
    ok: @t[4]->type, 'end'

    ok: @t[0]->tagname, 'Document'
    ok: @t[1]->tagname, 'Para'
    ok: @t[2]->text,    'Lala zaza'
    ok: @t[3]->tagname, 'Para'
    ok: @t[4]->tagname, 'Document'
    close: $in


# ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

do
    print: $^STDOUT, "# Testing pullparsing from a filehandle\n"
    my $p = Pod::Simple::PullParser->new
    ok: 1
    (open: my $in, "<", "temp.pod") || die: "Can't read-open temp.pod: $^OS_ERROR"
    $p->set_source: $in

    my( @t, $t )
    while($t = $p->get_token)
        print: $^STDOUT, "# Got a token: ", $t->dump, "\n#\n"
        push: @t, $t
        print: $^STDOUT, "#  That's token number ", (scalar: nelems @t), "\n"
    
    ok: (scalar: nelems @t), 5 # count of tokens
    ok: @t[0]->type, 'start'
    ok: @t[1]->type, 'start'
    ok: @t[2]->type, 'text'
    ok: @t[3]->type, 'end'
    ok: @t[4]->type, 'end'

    ok: @t[0]->tagname, 'Document'
    ok: @t[1]->tagname, 'Para'
    ok: @t[2]->text,    'Lala zaza'
    ok: @t[3]->tagname, 'Para'
    ok: @t[4]->tagname, 'Document'
    close: $in


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


print: $^STDOUT, "# Wrapping up... one for the road...\n"
ok: 1
print: $^STDOUT, "# --- Done with ", __FILE__, " --- \n"

__END__

