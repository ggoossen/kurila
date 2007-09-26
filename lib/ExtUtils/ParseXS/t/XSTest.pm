package XSTest;

require DynaLoader;
@ISA = qw(Exporter DynaLoader);
$VERSION = '0.01';
 XSTest->bootstrap( $VERSION);

1;
