use Perl6::Form

my @play = @:
 "Hamlet"
 "Othello"
 "Richard III"
    

my @name = @:
 "Claudius, King of Denmark\r\r"
 "Iago\r\r"
 "Henry, Earl of Richmond\r\r"
    


print: $^STDOUT, < form: 
           \(%: layout=>'down', bullet=>'.')
           "Index  Character     Appears in"
           \(%: under=>"_")
           "\{]]\}.  \{[[[[[[[[[[\}  \{[[[[[[[[[[\}"
           \1..nelems @name, \@name,       \@play

print: $^STDOUT, "\n\n=================\n\n"

print: $^STDOUT, < form: 
           \(%: layout=>'tabular', bullet=>'.')
           "Index  Character     Appears in"
           \(%: under=>"_")
           "\{]]\}.  \{[[[[[[[[[[\}  \{[[[[[[[[[[\}"
           \1..nelems @name, \@name,       \@play
