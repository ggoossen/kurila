package Cname;
our $Evil='A';

sub translator(?$str) {
    if ( $str eq 'EVIL' ) {
        (my $c=substr("A".$Evil,-1))++;
        my $r=$Evil;
        $Evil.=$c;
        return $r;
    }
    if ( $str eq 'EMPTY-STR') {
        return "";
    }
    return $str;
}

sub import(@< @_) {
    shift @_;
    $^HINTS{+charnames} = \&translator;
}
1;  
