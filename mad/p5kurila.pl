#/usr/bin/perl

use lib "$ENV{madpath}/mad";

use strict;
use warnings;

my $filename = shift @ARGV;

use XML::Twig;

sub entersub_handler {
    my ($twig, $sub) = @_;

    # Remove indirect object syntax.


    # check is method
    my ($method_named) = $twig->findnodes([$sub], "op_method_named");
    return if not $method_named;

    # skip special subs
    return if $sub->att("flags") =~ m/SPECIAL/;

    # check is indirect object syntax.
    my $x = $twig->findnodes([$sub], qq|madprops/mad_sv[\@key="A"][\@val="-&gt;"]|);
    return if $x;

    # make indirect object syntax.
    my $madprops = ($twig->findnodes([$sub], qq|madprops|))[0] || $sub->insert_new_elt("madprops");

    $madprops->insert_new_elt( "mad_sv", { key => "A", val => "-&gt;" } );
    $madprops->insert_new_elt( "mad_sv", { key => "(", val => "(" } );
    $madprops->insert_new_elt( "mad_sv", { key => ")", val => ")" } );

    # move widespace from method to object and visa versa.
    my ($method_ws) = $twig->findnodes([$method_named],
                                       qq|madprops/mad_op/op_method/op_const/madprops/mad_sv[\@key="_"]|);
    my ($obj_ws) = $twig->findnodes([$sub], qq|op_const/madprops/mad_sv[\@key="_"]|);
    if ($method_ws and $obj_ws) {
        my $x_method_ws = $method_ws->att('val');
        my $x_obj_ws = $obj_ws->att('val');
        $x_obj_ws =~ s/\s+$//;
        $method_ws->set_att("val" => $x_obj_ws);
        $obj_ws->set_att("val" => $x_method_ws);
    }
}

sub const_handler {
    my ($twig, $const) = @_;

    # Convert BARE words

    # real bareword
    return unless $const->att('private') && ($const->att('private') =~ m/BARE/);
    return unless $const->att('flags') eq "SCALAR";
    return if $const->parent( sub { $_[0]->tag eq "mad_op" } );
    return if $const->parent->tag eq "op_require";

    # helem:  $aap{noot}
    # negate: -Level
    # method: $aap->SUPER::noot()
    return if $const->parent->tag =~ m/^op_(helem|negate|method)$/;
    return if $const->parent->tag eq "op_null" 
      and ($const->parent->att("was") || '') =~ m/^(helem|negate|method)$/;

    # Seems to work
    return unless $twig->findnodes([$const], q|../madprops/mad_sv[@key=","][@val=","]|);

    {
        # keep qq| foo => |
        my $x = $const->parent->tag eq "op_null" ? $const->parent : $const;
        my ($next) = $x->parent->child($x->pos + 1);
        return if $next && $twig->findnodes([$next], q|madprops/mad_sv[@key=","][@val="=&gt;"]|);
    }

    # Make it a string constant
    my ($madprops) = $twig->findnodes([$const], q|madprops|);
    $const->del_att('private');
    my ($const_ws) = $twig->findnodes([$const], q|madprops/mad_sv[@key="_"]|);
    $const_ws->delete if $const_ws;
    $madprops->insert_new_elt( "mad_sv", { key => '_', val => q| | } );
    $madprops->insert_new_elt( "mad_sv", { key => 'q', val => q|'| } );
    $madprops->insert_new_elt( 'last_child', "mad_sv", { key => 'Q', val => q|'| } );
    my ($const_X) = $twig->findnodes([$const], q|madprops/mad_sv[@key="X"]|);
    $const_X->set_att("key" => q|=|);
}

my $twig= XML::Twig->new( keep_spaces => 1, keep_encoding => 1 );

$twig->parsefile( "-" );

for my $op ($twig->findnodes(q|//op_entersub|)) {
    entersub_handler($twig, $op);
}

for my $op_const ($twig->findnodes(q|//op_const|)) {
    const_handler($twig, $op_const);
}

$twig->print;
