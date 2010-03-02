#!./perl

our (%Config, $where)

BEGIN 
    try {my @n = (@:  getpwuid 0 ); setpwent()}
    if ($^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/(The \w+ function is unimplemented)/)
        print: $^STDOUT, "1..0 # Skip: $1\n"
        exit 0
    
    try { require Config; Config->import; }
    my $reason
    if (%Config{?'i_pwd'} ne 'define')
        $reason = '%Config{i_pwd} undefined'
    elsif (not -f "/etc/passwd" ) # Play safe.
        $reason = 'no /etc/passwd file'
    

    if (not defined $where)     # Try NIS.
        foreach my $ypcat (qw(/usr/bin/ypcat /bin/ypcat /etc/ypcat))
            my $pw
            if (-x $ypcat &&
                (open: $pw, "$ypcat passwd 2>/dev/null |") &&
                (defined:  ~< $pw))
                $where = "NIS passwd"
                undef $reason
                last
            
        
    

    if (not defined $where)     # Try NetInfo.
        foreach my $nidump (qw(/usr/bin/nidump))
            my $pw
            if (-x $nidump &&
                (open: $pw, "$nidump passwd . 2>/dev/null |") &&
                (defined:  ~< $pw))
                $where = "NetInfo passwd"
                undef $reason
                last
            
        
    

    if (not defined $where)     # Try local.
        my $PW = "/etc/passwd"
        my $pw_fh
        if (-f $PW && (open: $pw_fh, "<", $PW) && (defined:  ~< $pw_fh))
            $where = $PW
            undef $reason
        
    

    if (not defined $where)      # Try NIS+
        foreach my $niscat (qw(/bin/niscat))
            my $pw
            if (-x $niscat &&
                (open: $pw, "$niscat passwd.org_dir 2>/dev/null |") &&
                (defined:  ~< $pw))
                $where = "NIS+ $niscat passwd.org_dir"
                undef $reason
                last
            
        
    

    if ($reason)        # Give up.
        print: $^STDOUT, "1..0 # Skip: $reason\n"
        exit 0

# By now the PW filehandle should be open and full of juicy password entries.

print: $^STDOUT, "1..2\n"

# Go through at most this many users.
# (note that the first entry has been read away by now)
my $max = 25

my $n = 0
my $tst = 1
my %perfect
my %seen

print: $^STDOUT, "# where $where\n"

setpwent()

while ( ~< *PW)
    chomp
    # LIMIT -1 so that users with empty shells don't fall off
    my @s = split: m/:/, $_, -1
    my ($name_s, $passwd_s, $uid_s, $gid_s, $gcos_s, $home_s, $shell_s)
    (my $v) = %Config{?osvers} =~ m/^(\d+)/
    if ($^OS_NAME eq 'darwin' && $v +< 9)
        (@: $name_s, $passwd_s, $uid_s, $gid_s, $gcos_s, $home_s, $shell_s) =  @s[[(@: 0,1,2,3,7,8,9)]]
    else
        (@: $name_s, $passwd_s, $uid_s, $gid_s, $gcos_s, $home_s, $shell_s) =  @s
    
    next if m/^\+/ # ignore NIS includes
    if ((nelems @s))
        push: %seen{+$name_s}->@, iohandle::input_line_number: \*PW
    else
        warn: "# Your $where line $((iohandle::input_line_number: \*PW)) is empty.\n"
        next
    
    if ($n == $max)
        local $^INPUT_RECORD_SEPARATOR = undef
        my $junk = ~< *PW
        last
    
    # In principle we could whine if @s != 7 but do we know enough
    # of passwd file formats everywhere?
    if ((nelems @s) == 7 || ($^OS_NAME eq 'darwin' && (nelems @s) == 10))
        my @n = @:  getpwuid: $uid_s 
        # 'nobody' et al.
        next unless (nelems @n)
        my (@: $name,$passwd,$uid,$gid,$quota,$comment,$gcos,$home,$shell) =  @n
        # Protect against one-to-many and many-to-one mappings.
        if ($name_s ne $name)
            @n = @:  getpwnam: $name_s 
            (@: $name,$passwd,$uid,$gid,$quota,$comment,$gcos,$home,$shell) =  @n
            next if $name_s ne $name
        
        %perfect{+$name_s}++
            if $name    eq $name_s    and
          $uid     eq $uid_s     and
          # Do not compare passwords: think shadow passwords.
          $gid     eq $gid_s     and
          $gcos    eq $gcos_s    and
          $home    eq $home_s    and
          $shell   eq $shell_s
    
    $n++


endpwent()

print: $^STDOUT, "# max = $max, n = $n, perfect = ", (nelems: keys %perfect), "\n"

my $not
if ( ! %perfect && $n)
    $max++
    print: $^STDOUT, <<EOEX
#
# The failure of op/pwent test is not necessarily serious.
# It may fail due to local password administration conventions.
# If you are for example using both NIS and local passwords,
# test failure is possible.  Any distributed password scheme
# can cause such failures.
#
# What the pwent test is doing is that it compares the $max first
# entries of $where
# with the results of getpwuid() and getpwnam() call.  If it finds no
# matches at all, it suspects something is wrong.
# 
EOEX
    print: $^STDOUT, "not "
    $not = 1
else
    $not = 0

print: $^STDOUT, "ok ", $tst++
print: $^STDOUT, "\t# (not necessarily serious: run t/op/pwent.t by itself)" if $not
print: $^STDOUT, "\n"

# Test both the scalar and list contexts.

my @pw1

setpwent()
for (1..$max)
    my $pw = scalar getpwent()
    last unless defined $pw
    push: @pw1, $pw

endpwent()

my @pw2

setpwent()
for (1..$max)
    my (@: $pw, ...) = @: getpwent()
    last unless defined $pw
    push: @pw2, $pw

endpwent()

print: $^STDOUT, "not " unless "$((join: ' ',@pw1))" eq "$((join: ' ',@pw2))"
print: $^STDOUT, "ok ", $tst++, "\n"
