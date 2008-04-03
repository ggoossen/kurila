# The Mongoose v7.1 compiler freezes up somewhere in the optimization of
# MD5Transform() in MD5.c with optimization -O3.  This is a workaround:

if (%Config{cc} =~ m/64|n32/ && `$Config{cc} -version 2>&1` =~ m/\s7\.1/) {
    $self->{OPTIMIZE} = "-O1";
}
