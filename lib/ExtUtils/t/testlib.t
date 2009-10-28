#!/usr/bin/perl -w

use Test::More tests => 5

BEGIN 
    # non-core tests will have blib in their path.  We remove it
    # and just use the one in lib/.
    unless( (env::var: 'PERL_CORE') )
        $^INCLUDE_PATH = grep: { !m/blib/ }, $^INCLUDE_PATH
        unshift: $^INCLUDE_PATH, '../lib'
    


my @blib_paths = grep: { m/blib/ }, $^INCLUDE_PATH
is:  (nelems @blib_paths), 0, 'No blib dirs yet in $^INCLUDE_PATH' 

use_ok:  'ExtUtils::testlib' 

@blib_paths = grep: { m/blib/ }, $^INCLUDE_PATH
is:  (nelems @blib_paths), 2, 'ExtUtils::testlib added two $^INCLUDE_PATH dirs!' 
ok:  !((grep: { !(File::Spec->file_name_is_absolute: $_) }, @blib_paths))
     '  and theyre absolute'

try { eval "# $((join: ' ',$^INCLUDE_PATH))"; }
is:  $^EVAL_ERROR, '',     '$^INCLUDE_PATH is not tainted' 
