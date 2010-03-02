#!./perl -w

$^OUTPUT_AUTOFLUSH=1

use Config

use Test::More

use Opcode < qw(
	opcodes opdesc opmask verify_opset
	opset opset_to_ops opset_to_hex invert_opset
	opmask_add full_opset empty_opset define_optag
)


plan: tests => 16

my($s1, $s2, $s3)
my(@o1, @o2, @o3)

# --- opset_to_ops and opset

my @empty_l = opset_to_ops: (empty_opset: )
is: (nelems @empty_l), 0

my @full_l1  = opset_to_ops: (full_opset: )
is: (nelems @full_l1), $: (opcodes: )
my @full_l2 = @full_l1  # = opcodes();  # XXX to be fixed
is: "$((join: ' ',@full_l1))", "$((join: ' ',@full_l2))"

@empty_l = opset_to_ops: (opset: ':none')
is: (nelems @empty_l), 0

my @full_l3 = opset_to_ops: (opset: ':all')
is: (nelems @full_l1), nelems @full_l3
is: "$((join: ' ',@full_l1))", "$((join: ' ',@full_l3))"

# --- define_optag

ok:  ! try { (opset: ':_tst_') } 
define_optag: ":_tst_", (opset:  <qw(padsv gv))
ok:  try { (opset: ':_tst_') } 

# --- opdesc and opcodes

is:  (opdesc: "gv"), "glob value" 
ok:  $: (opcodes: ) 

# --- invert_opset

$s1 = opset:  <qw(fileno padsv)
@o2 = opset_to_ops: (invert_opset: $s1)
is: (nelems @o2), (opcodes: )-2

# --- opmask

is: (opmask: ), (empty_opset: )# work
is: length (opmask: ), (int: ((opcodes: )+7)/8)

# --- verify_opset

ok:  (verify_opset: $s1) && !(verify_opset: 42) 

# --- opmask_add

opmask_add: (opset:  <qw(fileno)) # add to global op_mask
ok:  ! eval 'fileno STDOUT'  # fail
ok:  $^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/'fileno' trapped/ 

# --- finally, check some opname assertions

foreach( @full_l1) { die: "bad opname: $_" if m/\W/ or m/^\d/ }
