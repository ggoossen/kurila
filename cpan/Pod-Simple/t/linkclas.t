
### Test the basic sanity of the link-section treelet class

use Test::More
plan: tests => 6

#use Pod::Simple::Debug (6);

ok: 1

use Pod::Simple::LinkSection
use Pod::Simple::BlackBox # for its pretty()

my $bare_treelet =
    \@: 'B', \%: 'pie' => 'no'
        'a'
        \ @: 'C', \%: 'bzrok' => 'plip'
             'b'
        'c'
    

my $treelet = Pod::Simple::LinkSection->new: $bare_treelet

# Make sure they're not the same

is: (ref: $bare_treelet), 'ARRAY'
is: (ref: $treelet), 'Pod::Simple::LinkSection'

print: $^STDOUT, "# Testing stringification...\n"

is: ($treelet->stringify: ), 'abc'  # explicit


print: $^STDOUT, "# Testing non-coreferentiality...\n"
do
    my @stack = @: $bare_treelet
    my $this
    while((nelems @stack))
        $this = shift @stack
        if((ref: $this || '') eq 'ARRAY')
            push: @stack, splice: $this->@
            push: $this->@, ("BAD!") x 3
        elsif((ref: $this || '') eq 'Pod::Simple::LinkSection')
            push: @stack, splice: $this->@
            push: $this->@, ("BAD!") x 3
        elsif((ref: $this || '') eq 'HASH')
            $this->% = $%
        
    
    # These will fail if $treelet and $bare_treelet are coreferential,
    # since we just conspicuously nuked $bare_treelet

    is: ($treelet->stringify: ), 'abc'  # explicit



print: $^STDOUT, "# Byebye...\n"
ok: 1
print: $^STDOUT, "# --- Done with ", __FILE__, " --- \n"

