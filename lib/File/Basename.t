#!./perl -Tw

use Test::More tests => 64;

BEGIN { use_ok 'File::Basename' }

# import correctly?
can_ok( __PACKAGE__, < qw( basename fileparse dirname fileparse_set_fstype ) );

### Testing Unix
do {
    ok length fileparse_set_fstype('unix'), 'set fstype to unix';
    is( fileparse_set_fstype(), 'Unix',     'get fstype' );

    my($base,$path,$type) = < fileparse('/virgil/aeneid/draft.book7',
                                      qr'\.book\d+');
    is($base, 'draft');
    is($path, '/virgil/aeneid/');
    is($type, '.book7');

    is(basename('/arma/virumque.cano'), 'virumque.cano');
    is(dirname ('/arma/virumque.cano'), '/arma');
    is(dirname('arma/'), '.');
};


### Testing VMS
do {
    is(fileparse_set_fstype('VMS'), 'Unix', 'set fstype to VMS');

    my($base,$path,$type) = <fileparse('virgil:[aeneid]draft.book7',
                                      qr{\.book\d+});
    is($base, 'draft');
    is($path, 'virgil:[aeneid]');
    is($type, '.book7');

    is(basename('arma:[virumque]cano.trojae'), 'cano.trojae');
    is(dirname('arma:[virumque]cano.trojae'),  'arma:[virumque]');
    is(dirname('arma:<virumque>cano.trojae'),  'arma:<virumque>');
    is(dirname('arma:virumque.cano'), 'arma:');

    do {
        local %ENV{+DEFAULT} = '' unless exists %ENV{DEFAULT};
        is(dirname('virumque.cano'), %ENV{?DEFAULT});
        is(dirname('arma/'), '.');
    };
};


### Testing DOS
do {
    is(fileparse_set_fstype('DOS'), 'VMS', 'set fstype to DOS');

    my($base,$path,$type) = <fileparse('C:\virgil\aeneid\draft.book7',
                                      '\.book\d+');
    is($base, 'draft');
    is($path, 'C:\virgil\aeneid\');
    is($type, '.book7');

    is(basename('A:virumque\cano.trojae'),  'cano.trojae');
    is(dirname('A:\virumque\cano.trojae'), 'A:\virumque');
    is(dirname('A:\'), 'A:\');
    is(dirname('arma\'), '.');

    # Yes "/" is a legal path separator under DOS
    is(basename("lib/File/Basename.pm"), "Basename.pm");

    # $^O for DOS is "dos" not "MSDOS" but "MSDOS" is left in for
    # backward bug compat.
    is(fileparse_set_fstype('MSDOS'), 'DOS');
    is( dirname("\\foo\\bar\\baz"), "\\foo\\bar" );
};


### Testing MacOS
do {
    is(fileparse_set_fstype('MacOS'), 'MSDOS', 'set fstype to MacOS');

    my($base,$path,$type) = < fileparse('virgil:aeneid:draft.book7',
                                      '\.book\d+');
    is($base, 'draft');
    is($path, 'virgil:aeneid:');
    is($type, '.book7');

    is(basename(':arma:virumque:cano.trojae'), 'cano.trojae');
    is(dirname(':arma:virumque:cano.trojae'),  ':arma:virumque:');
    is(dirname(':arma:virumque:'), ':arma:');
    is(dirname(':arma:virumque'), ':arma:');
    is(dirname(':arma:'), ':');
    is(dirname(':arma'),  ':');
    is(dirname('arma:'), 'arma:');
    is(dirname('arma'), ':');
    is(dirname(':'), ':');


    # Check quoting of metacharacters in suffix arg by basename()
    is(basename(':arma:virumque:cano.trojae','.trojae'), 'cano');
    is(basename(':arma:virumque:cano_trojae','.trojae'), 'cano_trojae');
};


### extra tests for a few specific bugs
do {
    fileparse_set_fstype 'DOS';
    # perl5.003_18 gives C:/perl/.\
    is((fileparse 'C:/perl/lib')[1], 'C:/perl/');
    # perl5.003_18 gives C:\perl\
    is(dirname('C:\perl\lib\'), 'C:\perl');

    fileparse_set_fstype 'UNIX';
    # perl5.003_18 gives '.'
    is(dirname('/perl/'), '/');
    # perl5.003_18 gives '/perl/lib'
    is(dirname('/perl/lib//'), '/perl');
};

### rt.perl.org 22236
do {
    is(basename('a/'), 'a');
    is(basename('/usr/lib//'), 'lib');

    fileparse_set_fstype 'MSWin32';
    is(basename('a\'), 'a');
    is(basename('\usr\lib\\'), 'lib');
};


### rt.cpan.org 36477
do {
    fileparse_set_fstype('Unix');
    is(dirname('/'), '/');
    is(basename('/'), '/');

    fileparse_set_fstype('DOS');
    is(dirname('\'), '\');
    is(basename('\'), '\');
};


### basename(1) sez: "The suffix is not stripped if it is identical to the
### remaining characters in string"
do {
    fileparse_set_fstype('Unix');
    is(basename('.foo'), '.foo');
    is(basename('.foo', '.foo'),     '.foo');
    is(basename('.foo.bar', '.foo'), '.foo.bar');
    is(basename('.foo.bar', '.bar'), '.foo');
};


### Test tainting
do {
    #   The empty tainted value, for tainting strings
    my $TAINT = substr($^X, 0, 0);

    # How to identify taint when you see it
    sub any_tainted (@) {
        return ! try { eval("#" . substr(join("", @( @_)), 0, 0)); 1 };
    }

    sub tainted ($) {
        any_tainted @_;
    }

    sub all_tainted (@) {
        for (@(@_)) { return 0 unless tainted $_ }
        1;
    }

    fileparse_set_fstype 'Unix';
    ok tainted(dirname($TAINT.'/perl/lib//'));
    ok all_tainted(< fileparse($TAINT.'/dir/draft.book7','\.book\d+'));
};
