#/usr/bin/perl

use lib "$ENV{madpath}/mad";

use strict;
use warnings;

use XML::Twig;
use XML::Twig::XPath;
use Getopt::Long;
use Carp::Assert;

sub fst(@) {
    return $_[0];
}

sub entersub_handler {
    my ($twig, $sub) = @_;

    # Remove indirect object syntax.


    # check is method
    my ($method_named) = $twig->findnodes([$sub], "op_method_named");
    return if not $method_named;

    # skip special subs
    return if $sub->att("flags") =~ m/SPECIAL/;

    # check is indirect object syntax.
    return if (get_madprop($sub, "bigarrow") || '') eq "-&gt;";

    # make indirect object syntax.
    set_madprop($sub, "bigarrow", "-&gt;");
    set_madprop($sub, "round_open", "(");
    set_madprop($sub, "round_close", ")");

    # move widespace from method to object and visa versa.
    my ($method_mad) = $twig->findnodes([$method_named],
                                       qq|madprops/mad_op/op_method/op_const/madprops/mad_value|);
    my ($obj_mad) = $twig->findnodes([$sub], qq|op_const/madprops/mad_value|);
    if ($method_mad and $obj_mad) {
        my $x_method_ws = $method_mad->att('wsbefore');
        my $x_obj_ws = $obj_mad->att('wsbefore');
        $x_obj_ws =~ s/\s+$//;
        $method_mad->set_att("wsbefore" => $x_obj_ws);
        $obj_mad->set_att("wsbefore" => $x_method_ws);
    }
}

sub const_handler {
    my ($twig, $const) = @_;

    # Convert BARE words

    # real bareword
    return unless $const->att('private') && ($const->att('private') =~ m/BARE/);
    return unless $const->att('flags') =~ "SCALAR";

    return if (get_madprop($const, "forcedword") || '') eq "forced";

    # no conversion if 'use strict' is active.
    return if $const->att('private') && ($const->att('private') =~ m/STRICT/);

    # negate: -Level
    # method: $aap->SUPER::noot()
    return if $const->parent->tag =~ m/^op_(negate|method)$/;
    return if $const->parent->tag eq "op_null" 
      and ($const->parent->att("was") || '') =~ m/^(negate|method)$/;
    # open IN, "filename";
    return if $const->parent->tag =~ m/^mad_op$/ and $const->parent->att("key") eq "key";

    {
        # keep qq| foo => |
        my $x = ($const->parent->tag eq "op_null" and ! $const->parent->att('was')) ? $const->parent : $const;
        my $next = $x->parent->child($x->pos);
        if (get_madprop($const, "value") =~ m/^\w+$/) {
            return if $next && (get_madprop($next, "comma") || '') eq "=&gt;";
            return if get_madprop($const->parent, "bigarrow");
        }
    }

    # "-x XX"
    if ($const->parent->tag =~ m/^op_(ft.*|truncate|chdir|stat|lstat)$/ or
        (get_madprop($const, "prototyped") || '') eq "*"
       ) {
        get_madprop($const, "value") eq "_" and return; # not for -x '_'

        # Add '*' to make it a glob
        $const->set_tag("op_rv2gv");
        set_madprop($const, "star", "*" . get_madprop($const, "value"), wsbefore => get_madprop($const, "value", 'wsbefore'));
        del_madprop($const, "value");
#         my ($wsval) = $twig->findnodes([$const], q|madprops/mad_sv[@key="wsbefore-value"]|);
#         $wsval->set_att( "key", "wsbefore-star" ) if $wsval;
        $const->insert_new_elt( "op_const" );
        return;
    }

    # keep Foo::Bar->new()
    if ($const->parent->tag eq "op_entersub") {
        # but change Foo::->new() to Foo->new()
        if (get_madprop($const, 'value') =~ m/(.*)\:\:$/) {
            set_madprop($const, 'value', $1);
        }
        return;
    }

    # keep qq| $aap{noot} |
    if (($const->parent->tag eq "op_helem" or
         ($const->parent->tag eq "op_null" and ($const->parent->att("was") || '') eq "helem"))
        and get_madprop($const, "value") =~ m/^\w+$/) {
        return;
    }

    # keep qq| -Level |
    return if $const->parent->tag eq "op_negate";
    return if $const->parent->tag eq "op_null" and ($const->parent->att("was") || '') eq "negate";

    # Make it a string constant
    my ($madprops) = $twig->findnodes([$const], q|madprops|);
    $const->del_att('private');
    my ($const_ws) = get_madprop($const, "value", 'wsbefore');
    #set_madprop($const, "value", get_madprop($const, "value"), ''); # delete ws.
    #$const_ws->delete if $const_ws;
    set_madprop($const, "quote_open", q|'|, wsbefore => $const_ws);
    set_madprop($const, "quote_close", q|'|, wsbefore => '');
    set_madprop($const, "assign" => get_madprop($const, "value"));
    del_madprop($const, "value");
}

sub add_encoding_latin1 {
    my $twig = shift;
    my ($root) = $twig->findnodes(q|/op_leave/|);

    # check already existing encoding pragma.
    return if $twig->findnodes(q|//mad_op[@key="use"]/op_const[@PV="encoding.pm"]|);

    my $latin1 = 0;
    for my $item ($twig->findnodes(q|//|)) {
        if (grep { m/&#x..[;]/ } values %{ $item->atts() || {} }) {
            $latin1 = 1;
        }
    }
    return if not $latin1;
    my $madprops = $root->insert_new_elt("op_null")->insert_new_elt("madprops");
    $madprops->insert_new_elt("mad_sv", { key => 'p', val => qq|use encoding 'latin1';&#xA;| });
}

sub del_madprop {
    my ($op, $key) = @_;
    my ($madsv) = $op->findnodes(qq|madprops/mad_$key|);
    $madsv->delete if $madsv;
}

sub set_madprop {
    @_ % 2 or Carp::confess("invalid number of arguments");
    my ($op, $key, $val, %ws) = @_;
    my ($madprops) = $op->findnodes("madprops");
    $madprops ||= $op->insert_new_elt("madprops");
    my ($madsv) = $op->findnodes(qq|madprops/mad_$key|);
    if ($madsv) {
        $madsv->set_att("val", $val);
    } else {
        $madsv = $madprops->insert_new_elt("mad_$key", { val => $val } );
    }
    for (keys %ws) {
        $madsv->set_att($_, $ws{$_});
    }
}

sub get_madprop {
    my ($op, $key, $attr) = @_;
    assert($op);
    my ($madsv) = $op->findnodes(qq|madprops/mad_$key|);
    return $madsv && $madsv->att($attr || "val");
}

sub rename_madprop {
    my ($op, $oldkey, $newkey) = @_;
    set_madprop($op, $newkey, get_madprop($op, $oldkey));
    del_madprop($op, $oldkey);
}

sub make_glob_sub {
    my $twig = shift;
    for my $op_glob ($twig->findnodes(q|//op_null[@was="glob"]|)) {
        next if not get_madprop($op_glob, "quote_open");
        set_madprop($op_glob, "round_open", "(");
        set_madprop($op_glob, "round_close", ")");
        set_madprop($op_glob, "operator", "glob", wsbefore => get_madprop($op_glob, 'quote_open', 'wsbefore'));
        del_madprop($op_glob, "assign");
        del_madprop($op_glob, "quote_open");
        del_madprop($op_glob, "quote_close");

        my ($op_c) = $op_glob->findnodes(q|op_entersub/op_null/op_concat|);
        if ($op_c) {
            # TODO quote the op_concat by using op_strigify

        } else {
            $op_c = ($op_glob->findnodes(q|op_entersub/op_null/op_const|))[0];
            set_madprop($op_c, "quote_open", "&#34;");
            set_madprop($op_c, "quote_close", "&#34;");
            set_madprop($op_c, "assign", get_madprop($op_c, "value"));
        }
    }
}

sub is_string_op {
    my $op = shift;

    # string constants, concatenations
    return 1 if $op->tag =~ m/^op_(const|concat)$/;
    # core functions returning a string
    return 1 if $op->tag =~ m/^op_(sprintf|join)$/;
    # stringify
    return 1 if $op->tag eq "op_null" and ($op->att('was') || '') eq "stringify";

    if ($op->tag eq "op_padsv") {
        # lookup last change to variable and if string assignment

        # is variable a string?
        my $targ = $op->att("targ");
        if ($targ) {
            for my $op_x (reverse $op->findnodes("ancestor-or-self::*")) {
                last if $op_x->tag eq "op_leavesub";
                for (reverse $op_x->findnodes("preceding-sibling::*")) {
                    next unless ($_->findnodes("*[\@targ='$targ']"));
                    last if $_->tag eq "op_leavesub";
                    # assignment of string to $var
                    if ($_->tag eq "op_sassign") {
                        my ($src, $dst) = $_->findnodes("*[\@seq]");
                        if ($dst->tag eq "op_padsv" and $dst->att("targ") eq $targ
                            and is_string_op($src)) {
                            return 1;
                        }
                    }
                    # substitute on $var
                    if ($_->tag eq "op_subst") {
                        my $dst = fst $_->findnodes("*[\@seq]");
                        if ($dst->tag eq "op_padsv" and $dst->att("targ") eq $targ) {
                            return 1;
                        }
                    }
                    # unknown fail.
                    return 0;
                }
            }
            return 0;
        }
    }

    return 0;
}

sub remove_rv2gv {
    my $twig = shift;
    # stash
    for my $op_rv2hv (map { $twig->findnodes(qq|//$_|) } (qw|op_rv2hv|)) {
        my ($op_const) = $op_rv2hv->findnodes(q*op_const*);
        next unless $op_const and $op_const->att('PV') =~ m/[:][:]$/;

        my $op_scope = $op_rv2hv->insert_new_elt("op_scope");
        set_madprop($op_scope, curly_open => '{');
        set_madprop($op_scope, curly_close => '}');

        my $op_sub = $op_scope->insert_new_elt("op_entersub");

        # ()
        set_madprop($op_sub, "round_open", "(");
        set_madprop($op_sub, "round_close", ")");

        #args
        my $args = $op_sub->insert_new_elt("op_null", { was => "list" });
        set_madprop($args->insert_new_elt("op_gv"), "value", "Symbol::stash");
        $op_const->move($args);

        set_madprop($op_rv2hv, 'hsh', '%') if get_madprop($op_rv2hv, 'hsh');
        set_madprop($op_const, quote_open => '&#34;');
        my $name = $op_const->att('PV');
        $name =~ s/::$//;
        set_madprop($op_const, assign => $name);
        set_madprop($op_const, quote_close => '&#34;');
    }

    # strict refs
    for my $op_rv2gv (map { $twig->findnodes(qq|//$_|) } (qw|op_rv2gv op_rv2sv op_rv2hv op_rv2cv op_rv2av|,
                                                          q{op_null[@was="rv2cv"]}) ) {

        my $op_scope = fst $op_rv2gv->findnodes(q|op_scope|);
        my $op_const;
        if (($op_const) = (map { ($op_scope || $op_rv2gv)->findnodes($_) } qw|op_null[@was='rv2sv'] op_padsv|)) {
            # Special case *$AUTOLOAD

            # is variable a string?
            next unless (get_madprop($op_const, "variable") || '') =~ m/^\$(AUTOLOAD|name)$/
              or is_string_op($op_const);

            next if ($op_rv2gv->att("private") || '') =~ m/STRICT_REFS/;

            if (not $op_scope) {
                if ($op_rv2gv->name eq "op_null") {
                    $op_scope = $op_rv2gv;
                } else {
                    $op_scope = $op_rv2gv->insert_new_elt("op_scope");
                    set_madprop($op_scope, "curly_open" => "{");
                    set_madprop($op_scope, "curly_close" => "}");
                    $op_const->move($op_scope);
                }
            }
        } else {
            next if not $op_scope;
            $op_const = ($op_scope->findnodes(q*op_const*))[0] || ($op_scope->findnodes(q*op_concat*))[0]
              || ($op_scope->findnodes(q*op_null[@was="stringify"]*))[0];
            next if not $op_const;
        }

        my $op_sub = $op_scope->insert_new_elt("op_entersub");

        # ()
        set_madprop($op_sub, "round_open", "(");
        set_madprop($op_sub, "round_close", ")");

        #args
        my $args = $op_sub->insert_new_elt("op_null", { was => "list" });
        my $op_gv = $args->insert_new_elt("op_gv");
        $op_gv->set_att("gv", "Symbol::fetch_glob");
        set_madprop( $op_gv, "value", "Symbol::fetch_glob" );
        $op_const->move($args);

        if ($op_rv2gv->name ne "op_rv2gv") {
            my $new_gv = $op_scope->insert_new_elt("op_rv2gv");
            set_madprop($new_gv, "star", '*');
            my $new_scope = $new_gv->insert_new_elt("op_scope");
            set_madprop($new_scope, "curly_open", "{");
            set_madprop($new_scope, "curly_close", "}");
            $op_sub->move($new_scope);
        }
    }
}

sub remove_vstring {
    my $twig = shift;

    for my $op_const ($twig->findnodes(q|//op_const|), $twig->findnodes(q|op_null[@was="const"]|)) {
        next unless (get_madprop($op_const, "value") || '') =~ m/\Av/;
        next if get_madprop($op_const, "forcedword");
        next if $op_const->att('private') && ($op_const->att('private') =~ m/BARE/);
        next if get_madprop($op_const->parent, "quote_open");
        next if $op_const->parent->tag eq "mad_op";
        next if $op_const->parent->tag eq "op_require";
        next if $op_const->parent->tag eq "op_concat";

        set_madprop($op_const, "quote_open", "&#34;", wsbefore => get_madprop($op_const, "value", "wsbefore"));
        set_madprop($op_const, "quote_close", "&#34;");
        my $v = get_madprop($op_const, "value");
        $v =~ s/^v//;
        $v =~ m/^[\d.]+$/ or die "Invalid string '$v'";
        $v =~ s/(\d+)/ sprintf '\x{%x}', $1 /ge;
        $v =~ s/[.]//g;
        set_madprop($op_const, "assign", $v);
        del_madprop($op_const, "value");
    }
}

sub remove_typed_declaration {
    my $twig = shift;
    for my $op_pad (map { $twig->findnodes(qq|//$_|) } (qw|op_padsv op_list|)) {
        if ((get_madprop($op_pad, "defintion") || '') =~ m/^(my|our).+$/) {
            set_madprop($op_pad, "defintion", $1);
        }
    }
}

sub rename_bit_operators {
    my $xml = shift;
    for my $op_bit (map { $xml->findnodes("//$_") } qw{op_bit_or or op_bit_and op_bit_xor op_complement}) {
        my $mapping = { '|' => '^|^', '|=' => '^|^=', '~' => '^~^', 
                        '&amp;' => '^&amp;^', '&amp;=' => '^&amp;^=',
                        '^' => '^^^', '^=' => '^^^=',
                      };
        next unless my $newop = $mapping->{get_madprop($op_bit, "operator")};
        set_madprop($op_bit, "operator", $newop);
    }
}

sub remove_useversion {
    my $xml = shift;
    for my $op_x ($xml->findnodes(q{//mad_op[@key='use']})) {
        next if ($op_x->findnodes(q{op_const[@private='BARE']}));
        # convert to dummy constant.
        my $op = $op_x->parent->parent;
        $op_x->delete();

        my ($madprops) = $op->findnodes("madprops");

        my $ws = get_madprop($op, "operator", 'wsbefore');
        $ws =~ s/\&\#xA$//; # remove newline.
        #set_madprop($op, "value", "XX");
        set_madprop($op, "value", $ws);

        set_madprop($op, "null_type", "value");
        #$madprops->insert_new_elt('first_child', "mad_sv", { key => "value", val => '' } );
    }
    for my $op_x ($xml->findnodes(q{//op_require})) {
        my ($const) = $op_x->findnodes(q{op_const});
        next unless $const and (get_madprop($const, 'value') || '') =~ m/^v?\d/;
        set_madprop($op_x, "operator", '');
        set_madprop($const, "value", '', wsbefore => '');
        if (my $ons = $op_x->prev_sibling('op_nextstate')) {
            $ons->delete;
        }
    }
}

sub change_deref_method {
    my $xml = shift;
    # '->$...' to '->&$...'
    for my $op_method ($xml->findnodes(q{//op_method})) {
        next if $op_method->findnodes(q{op_const[@private='BARE']});
        set_madprop($op_method->parent, 'bigarrow', "-&gt;?");
    }
}

sub change_deref {
    my $xml = shift;
    # '@{...}' to '...->@', etc.
    for (['@', 'ary', 'av'], [qw|$ variable sv|], [qw|% hsh hv|], [qw|* star gv|], [qw|&amp; ampersand cv|]) {
        my ($sigil, $token, $xv) = @$_;
        for my $rv2av ($xml->findnodes("//op_rv2$xv"), $xml->findnodes("//op_null[\@was='rv2$xv']")) {
            next unless (get_madprop($rv2av, $token) || '') eq $sigil or # =~ m/^([\$\@\%*]|&amp;)$/ or
              (get_madprop($rv2av, 'variable') || '') eq '$' or # sigil change
              (get_madprop($rv2av, 'ary') || '') eq '@';        # sigil change
            set_madprop($rv2av, 'variable', '');
            set_madprop($rv2av, 'ary', '');
            set_madprop($rv2av, $token, '');
            set_madprop($rv2av, 'arrow', '-&gt;' . $sigil);
            if (my ($scope) = $rv2av->findnodes('op_scope')) {
                set_madprop($rv2av, 'arrow', "-&gt;$sigil", wsafter => get_madprop($scope, 'curly_close', 'wsafter'));
                my $round = (not map { $scope->findnodes($_) }
                             qw{op_anonlist op_null[@was="aelem"] op_null[@was="helem"]
                                op_helem op_aelem op_entersub op_padsv });
                set_madprop($scope, 'curly_open', $round ? '(' : '');
                set_madprop($scope, 'curly_close', ($round ? ')' : ''), wsafter => '');
            }
        }
    }
}

sub intuit_more {
    my $xml = shift;

    # remove $foo[..] where intuit_more would return false.
    for my $op_null ($xml->findnodes(q{//op_null})) {
        next unless (get_madprop($op_null, 'null_type') || '') eq ",";
        next if $op_null->parent->tag eq "op_subst";
        my ($const) = $op_null->findnodes(q{op_const});
        next unless $const and (($const->att('PV') || '') =~ m/^[\[]/) and 
          $const->att('PV') eq (get_madprop($const, 'value') || '');
        set_madprop($const, "value", "(?:)" . get_madprop($const, 'value'));
    }
}

sub t_parenthesis {
    my $xml = shift;
    for my $op ($xml->findnodes(q{//*})) {
        next unless get_madprop($op, "round_open");
#         next if (get_madprop($op, "null_type") || '') eq "(";
#         next if $op->att('flags') =~ m/PARENS/;
        next unless get_madprop($op, "operator") or $op->tag eq "op_entersub";
#        set_madprop($op, "round_open", get_madprop($op, "round_open"), wsbefore => '');
        set_madprop($op, "round_open", get_madprop($op, "round_open", 'wsbefore') ? '' : ' ');
        set_madprop($op, "round_close", '');

        # only statement.
        next if $op->prev_sibling('op_nextstate');
        # rhs of an assignment
        next if $op->parent->tag eq "op_sassign" and $op->pos() == 2;
        # rhs of a .= assignment
        next if (get_madprop($op->parent, 'operator') || '') =~ m/^?\=$/ and $op->pos() == 3;

        my $op_null = XML::Twig::Elt->new("op_null");
        $op->replace_with($op_null);
        $op->move($op_null);
        set_madprop($op_null, "null_type", "(");
        if ($op->tag eq "op_entersub") {
            my $func = $op->child(-1)->child(-1);
            $func = $func->child(-1) if $func->tag eq "op_null";
            set_madprop($op_null, "round_open", "(", wsbefore => get_madprop($func, "value", 'wsbefore'));
            set_madprop($func, "value", get_madprop($func, "value"), wsbefore => '');
        }
        else {
            set_madprop($op_null, "round_open", "(", wsbefore => get_madprop($op, "operator", 'wsbefore'));
            set_madprop($op, "operator", get_madprop($op, "operator"), wsbefore => '');
        }
        set_madprop($op_null, "round_close", ")");
    }
}

my $from = 0; # floating point number with starting version of kurila.
GetOptions("from=f" => \$from);

my $filename = shift @ARGV;

# parsing
my $twig= XML::Twig->new( # keep_spaces => 1,
                         discard_spaces => 1,
 keep_encoding => 1 );

$twig->parsefile( "-" );

if ($from < 1.4 - 0.05) {
    # replacing.
    for my $op ($twig->findnodes(q|//op_entersub|)) {
        entersub_handler($twig, $op);
    }

    for my $op_const ($twig->findnodes(q|//op_const|)) {
        const_handler($twig, $op_const);
    }

    make_glob_sub( $twig );
    remove_vstring( $twig );

#     # add_encoding_latin1($twig);

    remove_rv2gv($twig);
    remove_typed_declaration($twig);
}

if ($from < 1.405) {
    rename_bit_operators($twig);
    remove_useversion($twig);
}

if ($from < 1.415) {
    change_deref_method($twig);
}

for my $op_const ($twig->findnodes(q|//op_const|)) {
    const_handler($twig, $op_const);
}
intuit_more($twig);
#t_parenthesis($twig);

# print
$twig->print;
