#!./perl

BEGIN 
    require './test.pl'


plan: tests => 27

like:  'a',  qr/^a(?{1})(?:b(?{2}))?/, 'a =~ ab?' 

unlike:  'abc', qr/^a(?{3})(?:b(?{4}))$/, 'abc !~ a(?:b)$' 

like:  'ab', qr/^a(?{5})b(?{6})/, 'ab =~ ab' 

like:  'ab', qr/^a(?{7})(?:b(?{8}))?/, 'ab =~ ab?' 


like:  'ab', qr/^a(?{9})b?(?{10})/, 'ab =~ ab? (2)' 

like:  'ab', qr/^(a(?{11})(?:b(?{12})))?/, 'ab =~ (ab)? (3)' 

unlike:  'ac', qr/^a(?{13})b(?{14})/, 'ac !~ ab' 

like:  'ac', qr/^a(?{15})(?:b(?{16}))?/, 'ac =~ ab?' 

my @ar
like:  'ab', qr/^a(?{push: @ar,101})(?:b(?{push: @ar,102}))?/, 'ab =~ ab? with code push' 
cmp_ok:  (scalar: nelems @ar), '==', 2, '..@ar pushed' 
cmp_ok:  @ar[0], '==', 101, '..first element pushed' 
cmp_ok:  @ar[1], '==', 102, '..second element pushed' 

unlike:  'a', qr/^a(?{103})b(?{104})/, 'a !~ ab with code push' 

@ar = $@
unlike:  'a', qr/^a(?{push: @ar,105})b(?{push: @ar,106})/, 'a !~ ab (push)' 
cmp_ok:  (scalar: nelems @ar), '==', 0, '..nothing pushed' 

@ar = $@
unlike:  'abc', qr/^a(?{push: @ar,107})b(?{push: @ar,108})$/, 'abc !~ ab$ (push)' 
cmp_ok:  (scalar: nelems @ar), '==', 0, '..still nothing pushed' 

our (@var)

like:  'ab', qr/^a(?{push: @var,109})(?:b(?{push: @var,110}))?/, 'ab =~ ab? push to package var' 
cmp_ok:  (scalar: nelems @var), '==', 2, '..@var pushed' 
cmp_ok:  @var[0], '==', 109, '..first element pushed (package)' 
cmp_ok:  @var[1], '==', 110, '..second element pushed (package)' 

@var = $@
unlike:  'a', qr/^a(?{push: @var,111})b(?{push: @var,112})/, 'a !~ ab (push package var)' 
cmp_ok:  (scalar: nelems @var), '==', 0, '..nothing pushed (package)' 

@var = $@
unlike:  'abc', qr/^a(?{push: @var,113})b(?{push: @var,114})$/, 'abc !~ ab$ (push package var)' 
cmp_ok:  (scalar: nelems @var), '==', 0, '..still nothing pushed (package)' 

ok:  'ac' =~ m/^a(?{30})(?:b(?{31})|c(?{32}))?/, 'ac =~ a(?:b|c)?' 
ok:  'abbb' =~ m/^a(?{36})(?:b(?{37})|c(?{38}))+/, 'abbbb =~ a(?:b|c)+' 
