use Perl6::Form

sub hashes($match,$opts)
    $opts->{+lfill}='>> '
    $opts->{+rfill}='<< '
    return '{I{'.(length: $match).'}I}'


print: $^STDOUT, < form: 
           \(%: field=>\(@: qr/(#+)/=>\&hashes))
           "[###|###############################]"
           \(@: 1,2,3), \qw[First Second Last]

