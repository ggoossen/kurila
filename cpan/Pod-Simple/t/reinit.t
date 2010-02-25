
use Test::More
plan: tests => 5

sub source_path
    my $file = shift
    my $dir = File::Spec->catdir : 't'
    return File::Spec->catfile : $dir, $file


use Pod::Simple::Text
$Pod::Simple::Text::FREAKYMODE = 1

my $parser  = Pod::Simple::Text->new: 

foreach my $file (@:
  "junk1.pod"
  "junk2.pod"
  "perlcyg.pod"
  "perlfaq.pod"
  "perlvar.pod"
    )

    unless(-e (source_path: $file))
        ok: 0
        print: $^STDOUT, "# But $file doesn't exist!!\n"
        next
    

    my $precooked = source_path: $file
    my $strings = @: undef, undef
    $precooked =~ s<\.pod><o.txt>s
    $parser->reinit: 
    $parser->output_string: \$strings[0]
    $parser->parse_file:  (source_path: $file)

    open: my $in, "<", $precooked or die: "Can't read-open $precooked: $^OS_ERROR"
    do
        local $^INPUT_RECORD_SEPARATOR = undef
        $strings[1] = ~< $in->*
    
    close: $in

    for ($strings) { s/\s+/ /g; s/^\s+//s; s/\s+$//s; }

    if($strings[0] eq $strings[1])
        ok: 1
        next
    elsif( do
            for ($strings) { s/[ ]//g; };
            $strings[0] eq $strings[1]
        )
        print: $^STDOUT, "# Differ only in whitespace.\n"
        ok: 1
        next
    else

        my $x = $strings[0] ^^^ $strings[1]
        $x =~ m/^(\x00*)/s or die: 
        my $at = length: $1
        print: $^STDOUT, "# Difference at byte $at...\n"
        if($at +> 10)
            $at -= 5
        
        do
            print: $^STDOUT, "# ", (substr: $strings[0],$at,20), "\n"
            print: $^STDOUT, "# ", (substr: $strings[1],$at,20), "\n"
            print: $^STDOUT, "#      ^..."
        

        ok: 0
        printf: $^STDOUT, "# Unequal lengths \%s and \%s\n", (length: $strings[0]), length: $strings[1]
        next
    

