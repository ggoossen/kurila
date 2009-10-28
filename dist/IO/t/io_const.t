
use IO::Handle

print: $^STDOUT, "1..6\n"
my $i = 1
foreach (qw(SEEK_SET SEEK_CUR SEEK_END     _IOFBF    _IOLBF    _IONBF))
    my $d1 = (exists: (Symbol::fetch_glob: "IO::Handle::" . $_)->*->&) ?? 1 !! 0
    my $v1 = $d1 ??( (Symbol::fetch_glob: "IO::Handle::" . $_)->*->& <: ) !! undef
    my $v2 = IO::Handle::constant: $_
    my $d2 = defined: $v2

    print: $^STDOUT, "not "
        if($d1 != $d2 || ($d1 && ($v1 != $v2)))
    print: $^STDOUT, "ok ",$i++,"\n"

