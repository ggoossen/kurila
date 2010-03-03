#!/usr/bin/perl

BEGIN {
    require './test.pl';
}

use warnings;

BEGIN
    if (!-c "/dev/null")
        print: $^STDOUT, "1..0 # Skip: no /dev/null\n"
        exit 0
    if (!-c "/dev/tty")
        print: $^STDOUT, "1..0 # Skip: no /dev/tty\n"
        exit 0
    if (env::var: 'PERL5DB')
        print: "1..0 # Skip: env::var('PERL5DB') is already set to '$(env::var('PERL5DB'))'\n"
        exit 0

BEGIN
  print: $^STDOUT, "1..0 # TODO: fix perl5db.pl\n"
  exit 0

plan(1)

sub rc
    open my $rc_fh, ">", ".perldb" or die $^OS_ERROR
    print $rc_fh < @_
    close($rc_fh)
    # overly permissive perms gives "Must not source insecure rcfile"
    # and hangs at the DB(1> prompt
    chmod 0644, ".perldb"

my $target = '../lib/perl5db/t/eval-line-bug'

rc(
    qq|
    &parse_options("NonStop=0 TTY=db.out LineInfo=db.out");
    \n|,

    qq|
    sub afterinit \{
        push(\@DB::typeahead,
            'b 23',
            'n',
            'n',
            'n',
            'c', # line 23
            'n',
            q!p \@\{*\{Symbol::fetch_glob('main::_<$target')\}\}!,
            'q',
        );
    \}\n|,
)

do
    local env::var('PERLDB_OPTS') = "ReadLine=0"
    runperl(switches => \(@: '-d' ), progfile => $target)

my $contents
do
    local $/
    open my $fh, "<", 'db.out' or die $!
    $contents = ~< $fh
    close($fh)

like($contents, qr/sub factorial/,
    'The ${main::_<filename} variable in the debugger was not destroyed'
    )

# clean up.

END
    unlink qw(.perldb db.out)
