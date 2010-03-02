#!/usr/bin/perl

use kurila
use warnings

=head1 NAME

make_patchnum.pl - make patchnum

=head1 SYNOPSIS

  miniperl make_patchnum.pl

  perl make_patchnum.pl

=head1 DESCRIPTION

This program creates the files holding the information
about locally applied patches to the source code. The created
files are  C<git_version.h> and C<lib/Config_git.pl>.

=item C<lib/Config_git.pl>

Contains status information from git in a form meant to be processed
by the tied hash logic of Config.pm. It is actually optional,
although -V:git.\* will be uninformative without it.

C<git_version.h> contains similar information in a C header file
format, designed to be used by patchlevel.h. This file is obtained
from stock_git_version.h if miniperl is not available, and then
later on replaced by the version created by this script.

=head1 AUTHOR

Yves Orton, Kenichi Ishigaki, Max Maischein

=head1 COPYRIGHT

Same terms as Perl itself.

=cut

# from a -Dmksymlink target dir, I need to cd to the git-src tree to
# use git (like script does).  Presuming that's not unique, one fix is
# to follow Configure's symlink-path to run git.  Maybe GIT_DIR or
# path-args can solve it, if so we should advise here, I tried only
# very briefly ('cd -' works too).

my ($subcd, $srcdir)
our $opt_v = nelems:  (grep: { $_ eq '-v' }, @ARGV) 

BEGIN
    my $root="."
    # test 1st to see if we're a -Dmksymlinks target dir
    $subcd = ''
    $srcdir = $root
    if (-l "./Configure")
        $srcdir = readlink: "./Configure"
        $srcdir =~ s/Configure//
        $subcd = "cd $srcdir &&" # activate backtick fragment

    while (!-e "$root/perl.c" and (length: $root) +< 100)
        if ($root eq '.')
            $root=".."
        else
            $root.="/.."

    die: "Can't find toplevel" if !-e "$root/perl.c"
    sub path_to($v) { "$root/$v" } # use $v if this'd be placed in toplevel.

sub read_file($filename)
    my $file = path_to: $filename
    return "" unless -e $file
    open: my $fh, '<', $file
        or die: "Failed to open for read '$file':$^OS_ERROR"
    return do { local $^INPUT_RECORD_SEPARATOR = undef; ~< $fh }


sub write_file($file, $content)
    $file= path_to: $file
    open: my $fh, '>', $file
        or die: "Failed to open for write '$file':$^OS_ERROR"
    print: $fh, $content
    close $fh


sub backtick($command)
    # only for git.  If we're in a -Dmksymlinks build-dir, we need to
    # cd to src so git will work .  Probably a better way.
    my $result= `$subcd $command`
    $result="" if ! defined $result
    warn: "$subcd $command: \$^CHILD_ERROR=$^CHILD_ERROR\n" if $^CHILD_ERROR
    print: $^STDOUT, "#> $subcd $command ->\n $result\n" if !$^CHILD_ERROR and $opt_v
    chomp $result
    return $result


sub write_files(@< @args)
    my %content= %+: map: { m/WARNING: '([^']+)'/ || (die: "Bad mojo!"); %: $1 => $_ }, @args
    my @files= sort: keys %content
    my $files= join: " and ", map: { "'$_'" }, @files
    foreach my $file (@files)
        if ((read_file: $file) ne %content{$file})
            print: $^STDOUT, "Updating $files\n"
            for (@files)
                write_file: $_,%content{$_}
            return 1

    print: $^STDOUT, "Reusing $files\n"
    return 0


my $unpushed_commits = '/*no-op*/'
my @: $read, $branch, $snapshot_created, $commit_id, $describe = (@: "") x 5
my @: $changed, $extra_info, $commit_title, $new_patchnum, $status = (@: "") x 5
if (my $patch_file= (read_file: ".patch"))
    @: $branch, $snapshot_created, $commit_id, $describe = split: m/\s+/, $patch_file
    $extra_info = "git_snapshot_date='$snapshot_created'"
    $commit_title = "Snapshot of:"
elsif (-d "$srcdir/.git")
    # git branch | awk 'BEGIN{ORS=""} /\*/ { print $^STDOUT, $2 }'
    @: ?$branch = grep: { defined }, map: { m/\* ([^(]\S*)/ ?? $1 !! undef },
                                              split: m/\n/, backtick: "git branch"
    my ($remote,$merge)
    if (length $branch)
        $merge= backtick: "git config branch.$branch.merge"
        $merge = "" unless $^CHILD_ERROR == 0
        $merge =~ s!^refs/heads/!!
        $remote= backtick: "git config branch.$branch.remote"
        $remote = "" unless $^CHILD_ERROR == 0

    $commit_id = backtick: "git rev-parse HEAD"
    $describe = backtick: "git describe"
    my $commit_created = backtick: q{git log -1 --pretty="format:%ci"}
    $new_patchnum = "describe: $describe"
    $extra_info = "git_commit_date='$commit_created'"
    if (length $branch && length $remote)
        # git cherry $remote/$branch | awk 'BEGIN{ORS=","} /\+/ {print $2}' | sed -e 's/,$//'
        my $unpushed_commit_list =
            join: ",", map: { ((split: m/\s/, $_))[1] },
                                grep: {m/\+/}, split: m/\n/, backtick: "git cherry $remote/$merge"
        # git cherry $remote/$branch | awk 'BEGIN{ORS="\t\\\\\n"} /\+/ {print ",\"" $2 "\""}'
        $unpushed_commits =
            join: "", map: { ',"'.((split: m/\s/, $_))[1]."\"\t\\\n" },
                               grep: {m/\+/}, split: m/\n/, backtick: "git cherry $remote/$merge"
        if (length $unpushed_commits)
            $commit_title = "Local Commit:"
            my $ancestor = backtick: "git rev-parse $remote/$merge"
            $extra_info = "$extra_info
git_ancestor='$ancestor'
git_remote_branch='$remote/$merge'
git_unpushed='$unpushed_commit_list'"

    if ($changed) # not touched since init'd. never true.
        $changed = 'true'
        $commit_title =  "Derived from:"
        $status='"uncommitted-changes"'
    else
        $status='/*clean-working-directory-maybe*/'

    $commit_title ||= "Commit id:"


# we extract the filename out of the warning header, so dont mess with that
write_files: <<"EOF_HEADER", <<"EOF_CONFIG"
/**************************************************************************
* WARNING: 'git_version.h' is automatically generated by make_patchnum.pl
*          DO NOT EDIT DIRECTLY - edit make_patchnum.pl instead
***************************************************************************/
#define PERL_GIT_UNCOMMITTED_CHANGES $status
#define PERL_PATCHNUM "$describe"
#define PERL_GIT_UNPUSHED_COMMITS\t\t\\
$unpushed_commits/*leave-this-comment*/
EOF_HEADER
######################################################################
# WARNING: 'lib/Config_git.pl' is generated by make_patchnum.pl
#          DO NOT EDIT DIRECTLY - edit make_patchnum.pl instead
######################################################################
\$Config::Git_Data=<<'ENDOFGIT'
git_commit_id='$commit_id'
git_describe='$describe'
git_branch='$branch'
git_uncommitted_changes='$changed'
git_commit_id_title='$commit_title'
$extra_info
ENDOFGIT
EOF_CONFIG
# ex: set ts=8 sts=4 sw=4 et ft=perl:
