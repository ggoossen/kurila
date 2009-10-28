#!./perl

# Test that various IO functions don't try to treat PVBMs as
# filehandles. Most of these will segfault perl if they fail.

BEGIN
    require "./test.pl"

plan: 21

sub PVBM () { 'foo' }

do
    my $dummy = (index: 'foo' (PVBM: ))

do
    my $pvbm = (PVBM: );

    my $pipe

    (ok: !try { (truncate: $pvbm, 0) }, 'truncate(PVBM) fails');
    (ok: !try { (truncate: \$pvbm, 0)}, 'truncate(PVBM ref) fails');

    (ok: !try { stat $pvbm }, 'stat(PVBM) fails');
    (ok: !try { stat \$pvbm }, 'stat(PVBM ref) fails');

    (ok: !try { lstat $pvbm }, 'lstat(PVBM) fails');
    (ok: !try { lstat \$pvbm }, 'lstat(PVBM ref) fails');

    (ok: !try { chdir $pvbm }, 'chdir(PVBM) fails');
    (ok: !try { chdir \$pvbm }, 'chdir(pvbm ref) fails');

    (ok: !try { close $pvbm }, 'close(PVBM) fails');
    (ok: !try { close $pvbm }, 'close(PVBM ref) fails');

    (ok: !try { (chmod: 0600, $pvbm) }, 'chmod(PVBM) fails');
    (ok: !try { (chmod: 0600, \$pvbm) }, 'chmod(PVBM ref) fails');

    :SKIP do
        skip: 'chown() not implemented on Win32', 2 if $^OS_NAME eq 'MSWin32';
        (ok: !try { (chown: 0, 0, $pvbm) }, 'chown(PVBM) fails');
        (ok: !try { (chown: 0, 0, \$pvbm) }, 'chown(PVBM ref) fails');

    (ok: !try { (utime: 0, 0, $pvbm) }, 'utime(PVBM) fails');
    (ok: !try { (utime: 0, 0, \$pvbm) }, 'utime(PVBM ref) fails');

    (ok: !try { ~< $pvbm }, '<PVBM> fails');
    (ok: !try { readline $pvbm }, 'readline(PVBM) fails');
    (ok: !try { readline \$pvbm }, 'readline(PVBM ref) fails');

    (ok: !try { (open: $pvbm, '<', 'none.such') }, 'open(PVBM) fails');
    (ok: !try { (open: \$pvbm, '<', 'none.such',) }, 'open(PVBM ref) fails');
