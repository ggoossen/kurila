
# Time-stamp: "2004-03-30 17:49:58 AST"
#sub I18N::LangTags::Detect::DEBUG () {10}
use I18N::LangTags < qw(implicate_supers_strictly)

use Test::More
BEGIN { (plan: tests => 19) };

print: $^STDOUT, "#\n# Testing strict (non-tight) insertion of super-ordinate language tags...\n#\n"

my @in = grep: { m/\S/ }, split: m/[\n\r]/, q{
 NIX => NIX
  sv => sv
  en => en
 hai => hai

          pt-br => pt-br pt
       pt-br fr => pt-br fr pt
    pt-br fr pt => pt-br fr pt
 pt-br fr pt de => pt-br fr pt de
 de pt-br fr pt => de pt-br fr pt
    de pt-br fr => de pt-br fr pt
   hai pt-br fr => hai pt-br fr  pt

# Now test multi-part complicateds:
   pt-br-janeiro fr => pt-br-janeiro fr pt-br pt 
pt-br-janeiro de fr => pt-br-janeiro de fr pt-br pt
pt-br-janeiro de pt fr => pt-br-janeiro de pt fr pt-br

ja    pt-br-janeiro fr => ja pt-br-janeiro fr pt-br pt 
ja pt-br-janeiro de fr => ja pt-br-janeiro de fr pt-br pt
ja pt-br-janeiro de pt fr => ja pt-br-janeiro de pt fr pt-br

pt-br-janeiro de pt-br fr => pt-br-janeiro de pt-br fr pt
 # an odd case, since we don't filter for uniqueness in this sub
 
}


foreach my $in ( @in)
    $in =~ s/^\s+//s
    $in =~ s/\s+$//s
    $in =~ s/#.+//s
    next unless $in =~ m/\S/

    my(@in, @should)
    do
        die: "What kind of line is <$in>?!"
            unless $in =~ m/^(.+)=>(.+)$/s

        my(@: $i,$s) = @: $1, $2
        @in     = @: $i =~ m/(\S+)/g
        @should = @: $s =~ m/(\S+)/g
    #print "{@in}{@should}\n";
    
    my @out = I18N::LangTags::implicate_supers_strictly: 
        ("$((join: ' ',@in))" eq 'NIX') ?? () !! < @in
        
    #print "O: ", join(' ', map "<$_>", @out), "\n";
    @out = (@:  'NIX' ) unless (nelems @out)


    if( (nelems @out) == nelems @should
        and (lc:  (join: "\e", @out) ) eq lc:  (join: "\e", @should) 
        )
        print: $^STDOUT, "#     Happily got [$((join: ' ',@out))] from [$in]\n"
        ok: 1
    else
        ok: 0
        print: $^STDOUT, "#!!Got:         [$((join: ' ',@out))]\n"
               "#!! but wanted: [$((join: ' ',@should))]\n"
               "#!! from \"$in\"\n#\n"
    


print: $^STDOUT, "#\n#\n# Bye-bye!\n"
ok: 1

