#!./perl

BEGIN { require './test.pl'; }

plan:  tests => 4 

do
    open: my $fh, '<', "TEST" or die: 
    is: (iohandle::input_line_number:  $fh ), 0, "input_line_number start at line 0"
    ~< $fh
    is: (iohandle::input_line_number:  $fh ), 1, "input_line_number is increaed"

    iohandle::input_line_number:  $fh, 55 
    is: (iohandle::input_line_number:  $fh ), 55, "input_line_number set"

    dies_like:  { (iohandle::input_line_number:  undef ) }
                qr/expected a filehandle not UNDEF/
                "input_line_number on undef" 

