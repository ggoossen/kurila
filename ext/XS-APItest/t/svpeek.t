
use warnings

use Test::More tests => 28

BEGIN
    use_ok: 'XS::APItest'

(is: (DPeek: undef), 'SV_UNDEF',		'undef')
(is: (DPeek: 1),     'IV(1)',			'constant 1')
(is: (DPeek: ""),    'PV(""\0) [UTF8 ""]',		'constant ""')
(is: (DPeek: 1.),    'NV(1)',			'constant 1.')
(is: (DPeek: \1),    '\IV(1)',			'constant \1')
(is: (DPeek: \\1),   '\\IV(1)',		'constant \\\1')

(is: (DPeek: \@ARGV),	'\AV()',		'\@ARGV')
(is: (DPeek: sub {}),	'CV()',	'sub {}')

do
  our ($VAR, @VAR, %VAR);
  open: *VAR, ">", "VAR.txt";
  sub VAR {}
  END { (unlink: "VAR.txt") };

  (is: (DPeek:  $VAR),	'UNDEF',		' $VAR undef');
  (is: (DPeek: \$VAR),	'\UNDEF',		'\$VAR undef');
  $VAR = 1;
  (is: (DPeek: $VAR),	'IV(1)',		' $VAR 1');
  (is: (DPeek: \$VAR),	'\IV(1)',		'\$VAR 1');
  $VAR = "";
  (is: (DPeek: $VAR),	'PVIV(""\0) [UTF8 ""]',		' $VAR ""');
  (is: (DPeek: \$VAR),	'\PVIV(""\0) [UTF8 ""]',		'\$VAR ""');
  $VAR = "\x[a8]";
  (is: (DPeek: $VAR),	'PVIV("\x[a8]"\0) [UTF8 "\x{0}"]',	' $VAR "\xa8"');
  (is: (DPeek: \$VAR),	'\PVIV("\x[a8]"\0) [UTF8 "\x{0}"]',	'\$VAR "\xa8"');
  $VAR = "a\x[0a]\x{20ac}";
  (is: (DPeek: $VAR), 'PVIV("a\n\x[e2]\x[82]\x[ac]"\0) [UTF8 "a\n\x{20ac}"]'
       ' $VAR "a\x[0a]\x{20ac}"');
  $VAR = sub { "VAR" };
  (is: (DPeek: $VAR),	'CV()',	' $VAR sub { "VAR" }');
  (is: (DPeek: \$VAR),	'\CV()',	'\$VAR sub { "VAR" }');
  $VAR = 0;

  (is: (DPeek: \&VAR),	'\CV()',		'\&VAR');
  (is: (DPeek:  *VAR),	'GV()',			' *VAR');

  (is: (DPeek: *VAR{GLOB}),	'\GV()',	' *VAR{GLOB}');
(like: (DPeek: *VAR{SCALAR}), qr'\\IV\(0\)',' *VAR{SCALAR}')
  (is: (DPeek: *VAR{ARRAY}),	'\AV()',	' *VAR{ARRAY}')
  (is: (DPeek: *VAR{HASH}),	'\HV()',	' *VAR{HASH}')
  (is: (DPeek: *VAR{CODE}),	'\CV()',	' *VAR{CODE}')
  (is: (DPeek: *VAR{IO}),		'\IO()',	' *VAR{IO}')

1
