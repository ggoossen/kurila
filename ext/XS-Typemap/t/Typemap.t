use TestInit
use Config

use Test::More tests => 84

use warnings
use utf8
use XS::Typemap
require bytes

ok: 1

# Some inheritance trees to check ISA relationships
BEGIN 
    package intObjPtr::SubClass
    use base < qw/ intObjPtr /
    sub xxx { 1; }


BEGIN 
    package intRefIvPtr::SubClass
    use base < qw/ intRefIvPtr /
    sub xxx { 1 }


# T_SV - standard perl scalar value
diag: "# T_SV\n"

my $sv = "Testing T_SV"
is:  (T_SV: $sv), $sv

# T_SVREF - reference to Scalar
diag: "# T_SVREF\n"

$sv .= "REF"
my $svref = \$sv
is:  (T_SVREF: $svref), $svref 

# Now test that a non reference is rejected
# the typemaps croak
try { (T_SVREF:  "fail - not ref" ) }
ok:  $^EVAL_ERROR 

# T_AVREF - reference to a perl Array
diag: "# T_AVREF\n"

my @array
is:  (T_AVREF: \@array), \@array

# Now test that a non array ref is rejected
try { (T_AVREF:  \$sv ) }
ok:  $^EVAL_ERROR 

# T_HVREF - reference to a perl Hash
diag: "# T_HVREF\n"

my %hash
is:  (T_HVREF: \%hash), \%hash

# Now test that a non hash ref is rejected
try { (T_HVREF:  \@array ) }
ok:  $^EVAL_ERROR 


# T_CVREF - reference to perl subroutine
diag: "# T_CVREF\n"
my $sub = \ sub { 1 }
is:  (T_CVREF: $sub), $sub 

# Now test that a non code ref is rejected
try { (T_CVREF:  \@array ) }
ok:  $^EVAL_ERROR 

# T_SYSRET - system return values
diag: "# T_SYSRET\n"

# first check success
ok:  (T_SYSRET_pass: )

# ... now failure
is:  (T_SYSRET_fail: ), undef

# T_UV - unsigned integer
diag: "# T_UV\n"

is:  (T_UV: 5), 5     # pass
ok:  (T_UV: -4) != -4 # fail

# T_IV - signed integer
diag: "# T_IV\n"

is:  (T_IV: 5), 5
is:  (T_IV: -4), -4
is:  (T_IV: 4.1), (int: 4.1)
is:  (T_IV: "52"), "52"
isnt:  (T_IV: 4.5), 4.5 # failure


# Skip T_INT

# T_ENUM - enum list
diag: "# T_ENUM\n"

ok:  (T_ENUM: )  # just hope for a true value

# T_BOOL - boolean
diag: "# T_BOOL\n"

ok:  (T_BOOL: 52) 
ok:  ! (T_BOOL: 0) 
ok:  ! (T_BOOL: '') 
ok:  ! (T_BOOL: undef) 

# Skip T_U_INT

# Skip T_SHORT

# T_U_SHORT aka U16

diag: "# T_U_SHORT\n"

is:  (T_U_SHORT: 32000), 32000
if ((config_value: 'shortsize') == 2)
    (ok:  (T_U_SHORT: 65536) != 65536) # probably dont want to test edge cases
else 
    ok: 1 # e.g. Crays have shortsize 4 (T3X) or 8 (CXX and SVX)


# T_U_LONG aka U32

diag: "# T_U_LONG\n"

is:  (T_U_LONG: 65536), 65536
ok:  (T_U_LONG: -1) != -1

# T_CHAR

diag: "# T_CHAR\n"

is:  (T_CHAR: "a"), "a"
is:  (T_CHAR: "-"), "-"
is:  (T_CHAR: (bytes::chr: 128)),(bytes::chr: 128)
ok:  (T_CHAR: (chr: 256)) ne (chr: 256)

# T_U_CHAR

diag: "# T_U_CHAR\n"

is:  (T_U_CHAR: 127), 127
is:  (T_U_CHAR: 128), 128
ok:  (T_U_CHAR: -1) != -1
ok:  (T_U_CHAR: 300) != 300

# T_FLOAT
diag: "# T_FLOAT\n"

# limited precision
is:  (sprintf: "\%6.3f", (T_FLOAT: 52.345)), (sprintf: "\%6.3f",52.345)

# T_NV
diag: "# T_NV\n"

is:  (T_NV: 52.345), 52.345

# T_DOUBLE
diag: "# T_DOUBLE\n"

is:  (sprintf: "\%6.3f", (T_DOUBLE: 52.345)), (sprintf: "\%6.3f",52.345)

# T_PV
diag: "# T_PV\n"

is:  (T_PV: "a string"), "a string"
is:  (T_PV: 52), 52

# T_PTR
diag: "# T_PTR\n"

my $t = 5
my $ptr = T_PTR_OUT: $t
is:  (T_PTR_IN:  $ptr ), $t 

# T_PTRREF
diag: "# T_PTRREF\n"

$t = -52
$ptr = T_PTRREF_OUT:  $t 
is:  (ref: $ptr), "SCALAR"
is:  (T_PTRREF_IN:  $ptr ), $t 

# test that a non-scalar ref is rejected
try { (T_PTRREF_IN:  $t ); }
ok:  $^EVAL_ERROR 

# T_PTROBJ
diag: "# T_PTROBJ\n"

$t = 256
$ptr = T_PTROBJ_OUT:  $t 
is:  (ref: $ptr), "intObjPtr"
is:  $ptr->T_PTROBJ_IN, $t 

# check that normal scalar refs fail
try {(intObjPtr::T_PTROBJ_IN:  \$t );}
ok:  $^EVAL_ERROR 

# check that inheritance works
bless: $ptr, "intObjPtr::SubClass"
is:  (ref: $ptr), "intObjPtr::SubClass"
is:  $ptr->T_PTROBJ_IN, $t 

# Skip T_REF_IV_REF

# T_REF_IV_PTR
diag: "# T_REF_IV_PTR\n"

$t = -365
$ptr = T_REF_IV_PTR_OUT:  $t 
is:  (ref: $ptr), "intRefIvPtr"
is:  $ptr->T_REF_IV_PTR_IN, $t

# inheritance should not work
bless: $ptr, "intRefIvPtr::SubClass"
try { $ptr->T_REF_IV_PTR_IN }
ok:  $^EVAL_ERROR 

# Skip T_PTRDESC

# Skip T_REFREF

# Skip T_REFOBJ

# T_OPAQUEPTR
diag: "# T_OPAQUEPTR\n"

$t = 22
my $p = T_OPAQUEPTR_IN:  $t 
is:  (T_OPAQUEPTR_OUT: $p), $t

# T_OPAQUEPTR with a struct
diag: "# T_OPAQUEPTR with a struct\n"

my @test = (@: 5,6,7)
$p = T_OPAQUEPTR_IN_struct: < @test
my @result = T_OPAQUEPTR_OUT_struct: $p
is: (scalar: nelems @result),(scalar: nelems @test)
for (0..((nelems @test)-1))
    (is: @result[$_], @test[$_])


# T_OPAQUE
diag: "# T_OPAQUE\n"

$t = 48
$p = T_OPAQUE_IN:  $t 
is: (T_OPAQUEPTR_OUT_short:  $p ), $t # Test using T_OPAQUEPTR
is: (T_OPAQUE_OUT:  $p ), $t          # Test using T_OPQAQUE

# T_OPAQUE_array
diag: "# A packed  array\n"

my @opq = (@: 2,4,8)
my $packed = T_OPAQUE_array: < @opq
my @uopq = (@:  (unpack: "i*",$packed) )
is: (scalar: nelems @uopq), (scalar: nelems @opq)
for (0..((nelems @opq)-1))
    (is:  @uopq[$_], @opq[$_])


# Skip T_PACKED

# Skip T_PACKEDARRAY

# Skip T_DATAUNIT

# Skip T_CALLBACK

# T_ARRAY
diag: "# T_ARRAY\n"
my @inarr = (@: 1,2,3,4,5,6,7,8,9,10)
T_ARRAY:  5, < @inarr 
my @outarr = T_ARRAY:  5, < @inarr 
is: (scalar: nelems @outarr), (scalar: nelems @inarr)

for (0..((nelems @inarr)-1))
    (is: @outarr[$_], @inarr[$_])




# T_STDIO
diag: "# T_STDIO\n"

# open a file in XS for write
my $testfile= "stdio.tmp"
my $fh = T_STDIO_open:  $testfile 
ok:  $fh 

# write to it using perl
if (defined $fh)

    my @lines = (@: "NormalSTDIO\n", "PerlIO\n")

    # print to it using FILE* through XS
    (is:  (T_STDIO_print: $fh, @lines[0]), (length: @lines[0]))

    # print to it using normal perl
    (ok: (print: $fh, "@lines[1]"))

    # close it using XS if using perlio, using Perl otherwise
    (ok:  (config_value: 'useperlio') ?? (T_STDIO_close:  $fh ) !! (close:  $fh ) )

    # open from perl, and check contents
    (open: $fh, "<", "$testfile")
    (ok: $fh)
    my $line = ~< $fh
    (is: $line,@lines[0])
    $line = ~< $fh
    (is: $line,@lines[1])

    (ok: (close: $fh))
    (ok: (unlink: $testfile))

else 
    for (1..8)
        (skip: "Skip Test not relevant since file was not opened correctly",0)
    


