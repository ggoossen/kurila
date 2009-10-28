#!./perl

(env::var: 'PATH' ) = "/bin:/usr/bin:/usr/xpg4/bin:/usr/ucb" .
    defined (env::var: 'PATH') ?? ":$((env::var: 'PATH'))" !! "" 
(env::var: 'LC_ALL' ) = "C" # so that external utilities speak English
(env::var: 'LANGUAGE' ) = 'C' # GNU locale extension

BEGIN 
    require Config
    if ($^EVAL_ERROR)
        print: $^STDOUT, "1..0 # Skip: no Config\n"
    else
        Config->import: 
    


our ($groups, $pwgid, $pwgnam, %seen, @gr, $group, $gr1, $gr2, %basegroup)

sub quit
    print: $^STDOUT, "1..0 # Skip: no `id` or `groups`\n"
    exit 0


unless (try { (getgrgid: 0); 1 })
    print: $^STDOUT, "1..0 # Skip: getgrgid() not implemented\n"
    exit 0


quit:  if (($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare') or $^OS_NAME =~ m/lynxos/i)

# We have to find a command that prints all (effective
# and real) group names (not ids).  The known commands are:
# groups
# id -Gn
# id -a
# Beware 1: some systems do just 'id -G' even when 'id -Gn' is used.
# Beware 2: id -Gn or id -a format might be id(name) or name(id).
# Beware 3: the groups= might be anywhere in the id output.
# Beware 4: groups can have spaces ('id -a' being the only defense against this)
# Beware 5: id -a might not contain the groups= part.
#
# That is, we might meet the following:
#
# foo bar zot				# accept
# foo 22 42 bar zot			# accept
# 1 22 42 2 3				# reject
# groups=(42),foo(1),bar(2),zot me(3)	# parse
# groups=22,42,1(foo),2(bar),3(zot me)	# parse
#
# and the groups= might be after, before, or between uid=... and gid=...

:GROUPS do
    # prefer 'id' over 'groups' (is this ever wrong anywhere?)
    # and 'id -a' over 'id -Gn' (the former is good about spaces in group names)
    if (($groups = `id -a 2>/dev/null`) ne '')
        # $groups is of the form:
        # uid=39957(gsar) gid=22(users) groups=33536,39181,22(users),0(root),1067(dev)
        # FreeBSD since 6.2 has a fake id -a:
        # uid=1001(tobez) gid=20(staff) groups=20(staff), 0(wheel), 68(dialer)
        last GROUPS if $groups =~ m/groups=/
    
    if (($groups = `id -Gn 2>/dev/null`) ne '')
        # $groups could be of the form:
        # users 33536 39181 root dev
        last GROUPS if $groups !~ m/^(\d|\s)+$/
    
    if (($groups = `groups 2>/dev/null`) ne '')
        # may not reflect all groups in some places, so do a sanity check
        if (-d '/afs')
            print: $^STDOUT, <<EOM
# These test results *may* be bogus, as you appear to have AFS,
# and I can't find a working 'id' in your PATH (which I have set
# to '$((env::var: 'PATH'))').
#
# If these tests fail, report the particular incantation you use
# on this platform to find *all* the groups that an arbitrary
# user may belong to, using the 'perlbug' program.
EOM
        
        last GROUPS
    
    # Okay, not today.
    (quit: )


chomp: $groups

print: $^STDOUT, "# groups = $groups\n"

# Remember that group names can contain whitespace, '-', et cetera.
# That is: do not \w, do not \S.
if ($groups =~ m/groups=(.+)( [ug]id=|$)/)
    my $gr = $1
    my @g0 = split: m/, ?/, $gr
    my @g1
    # prefer names over numbers
    for ( @g0)
        # 42(zot me)
        if (m/^(\d+)(?:\(([^)]+)\))?/)
            push: @g1, ($2 || $1)
        elsif (m/^([^(]*)\((\d+)\)/)
            push: @g1, ($1 || $2)
        else
            print: $^STDOUT, "# ignoring group entry [$_]\n"
        
    
    print: $^STDOUT, "# groups=$gr\n"
    print: $^STDOUT, "# g0 = $((join: ' ',@g0))\n"
    print: $^STDOUT, "# g1 = $((join: ' ',@g1))\n"
    $groups = "$((join: ' ',@g1))"


print: $^STDOUT, "1..2\n"

$pwgid = $^GID + 0
($pwgnam) = getgrgid: $pwgid
%seen{+$pwgid}++

print: $^STDOUT, "# pwgid = $pwgid, pwgnam = $pwgnam\n"

for ((split: ' ', $^GID))
    ($group) = getgrgid: $_
    next if (! defined $group or ! (grep: { $_ eq $group }, @gr)) and %seen{+$_}++
    if (defined $group)
        push: @gr, $group
    else
        push: @gr, $_
    


print: $^STDOUT, "# gr = $((join: ' ',@gr))\n"

my %did
if ($^OS_NAME =~ m/^(?:uwin|cygwin|interix|solaris)$/)
    # Or anybody else who can have spaces in group names.
    $gr1 = join: ' ', (grep:  {!%did{+$_}++ }, (sort: (split: ' ', (join: ' ', @gr))))
else
    # Don't assume that there aren't duplicate groups
    $gr1 = join: ' ', (sort: (grep: { defined $_ && !%did{+$_}++ }, @gr))


if ((config_value: "myuname") =~ m/^cygwin_nt/i)  # basegroup on CYGWIN_NT has id = 0.
    %basegroup{[(@: $pwgid,$pwgnam)]} = @: 0,0
else
    %basegroup{[(@: $pwgid,$pwgnam)]} = @: 1,1

$gr2 = join: ' ', (grep:  {!%basegroup{+$_}++ }, (sort: (split: ' ',$groups)))

my $ok1 = 0
if ($gr1 eq $gr2 || ($gr1 eq '' && $gr2 eq $pwgid))
    print: $^STDOUT, "ok 1\n"
    $ok1++
elsif ((config_value: "myuname") =~ m/^cygwin_nt/i) # basegroup on CYGWIN_NT has id = 0.
    # Retry in default unix mode
    %basegroup = %:  $pwgid => 1, $pwgnam => 1 
    $gr2 = join: ' ', (grep:  {!%basegroup{+$_}++ }, (sort: (split: ' ',$groups)))
    if ($gr1 eq $gr2 || ($gr1 eq '' && $gr2 eq $pwgid))
        print: $^STDOUT, "ok 1 # This Cygwin behaves like Unix (Win2k?)\n"
        $ok1++
    

unless ($ok1)
    print: $^STDOUT, "#gr1 is <$gr1>\n"
    print: $^STDOUT, "#gr2 is <$gr2>\n"
    print: $^STDOUT, "not ok 1\n"


# multiple 0's indicate GROUPSTYPE is currently long but should be short

if ($pwgid == 0 || %seen{?0} +< 2)
    print: $^STDOUT, "ok 2\n"
else
    print: $^STDOUT, "not ok 2 (groupstype should be type short, not long)\n"

