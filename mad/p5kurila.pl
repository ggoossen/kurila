#/usr/bin/perl

use lib "$ENV{madpath}/mad";

use strict;
use warnings;
use version;

use XML::Twig;
use XML::Twig::XPath;
use Getopt::Long;
use Carp::Assert;

sub fst(@) {
    return $_[0];
}

sub find_ops {
    my ($xml, $name) = @_;
    return $xml->findnodes(qq[//op_null[\@was="$name"]]), $xml->findnodes(qq[//op_$name]);
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

sub is_in_string {
    my $op = shift;

    return 1 if $op->tag eq "op_stringify" or
      ($op->tag eq "op_null" and ($op->att('was') || '') eq "stringify");
    return 1 if $op->tag eq "op_concat";
    return 1 if $op->tag eq "op_substcont";

    return $op->parent && is_in_string($op->parent);
}

sub is_string_op {
    my $op = shift;

    # string constants, concatenations
    return 1 if $op->tag =~ m/^op_(const|concat)$/;
    # core functions returning a string
    return 1 if $op->tag =~ m/^op_(sprintf|join)$/;
    # stringify
    return 1 if $op->tag eq "op_stringify" or
      ($op->tag eq "op_null" and ($op->att('was') || '') eq "stringify");

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
        # starts with a 'v' or a digital with at least two '.'
        next unless (get_madprop($op_const, "value") || '') =~ m/\A(v|\d.*[.].*[.])/;

        next if get_madprop($op_const, "forcedword");
        next if $op_const->att('private') && ($op_const->att('private') =~ m/BARE/);
        next if get_madprop($op_const->parent, "quote_open");
        next if $op_const->parent->tag eq "mad_op";
        next if $op_const->parent->tag eq "op_require";
        next if not $op_const->att('PVMG');

        set_madprop($op_const, "quote_open", "&#34;", wsbefore => get_madprop($op_const, "value", "wsbefore"));
        set_madprop($op_const, "quote_close", "&#34;");
        my $v = get_madprop($op_const, "value");
        $v =~ s/^v//;
        $v =~ s/_//g; # strip '_'
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

sub use_pkg_version {
    my $xml = shift;
    # "use MODULE 0.9" to "use MODULE v0.9"
    for my $madv ($xml->findnodes(qq|//mad_op[\@key='version']|)) {
        my $const = $madv->child(0);
        next if get_madprop($const, 'value') =~ m/^v/;
        set_madprop($const, 'value', "v" . get_madprop($const, 'value'));
    }
}

sub lvalue_subs {
    my ($xml, $opname) = @_;
    for my $op ($xml->findnodes(qq|//op_$opname|)) {
        next unless ($op->parent->tag eq "op_sassign");
        next unless $op->pos == 3;
        my $assign = $op->parent;

        if ($op->children_count < 4+1) {
            # create third argument 'undef'
            my $third = $op->insert_new_elt('last_child', 'op_null');
            set_madprop($third, "comma", ",");
            set_madprop($third, "null_type", ",");
            my $third_v = $third->insert_new_elt('last_child', "op_const");
            set_madprop($third_v, "value", 'undef', wsbefore => ' ');
        }

        # move rhs to 4th argument
        my $fourth = $op->insert_new_elt('last_child', 'op_null');
        set_madprop($fourth, "comma", ",");
        set_madprop($fourth, "null_type", ",");
        $assign->child(1)->move($fourth);
        
        $op->replace($assign);
    }
}

sub force_m {
    my $xml = shift;
    for my $op ($xml->findnodes(qq|//op_match|), $xml->findnodes(qq|//op_pushre|)) {
        next unless get_madprop($op, "quote_open") eq "/";
        set_madprop($op, quote_open => "m/");
    }
}

sub rename_pointy_ops {
    my $xml = shift;

    # rename '<FH>' to '~< *FH'
    for my $op ($xml->findnodes(qq|//op_readline|)) {
        my $v = get_madprop($op, "value") or next;
        $v =~ m/^&lt;(.*)&gt;$/ or next;
        $v = $1;
        $v ||= "ARGV";
        $v = "*" . $v if $v =~ m/^\w/;
        set_madprop($op, "value" => "~&lt; " . $v, 
                    wsbefore => get_madprop($op, "value", "wsbefore") || " " );
    }

    # rename '<' to '+<'
    for my $op (map { $xml->findnodes(qq'//$_') } map { ("op_i_$_", "op_$_") } qw|lt le gt ge|) {
        next unless get_madprop($op, "operator") =~ m/^(?:&lt;|&gt;)/;
        set_madprop($op, operator => '+' . get_madprop($op, "operator") );
    }

    # rename '<=>' to '<+>'
    for my $op (map { $xml->findnodes("//$_") } qw|op_ncmp op_i_ncmp|) {
        next unless get_madprop($op, "operator") eq "&lt;=&gt;";
        set_madprop($op, operator => '&lt;+&gt;');
    }
}

sub open_3args {
    my $xml = shift;
    for my $op_open ($xml->findnodes(qq|//op_open|)) {
        next unless $op_open->children == 2+2;
        my $arg = $op_open->child(3);
        my $argo = $arg->child(1);
        if (($argo->att('was') || '') eq "rv2sv" or
            $argo->tag eq "op_padsv" or
            ($argo->tag eq "op_stringify" and 
             $argo->children == 3 and
             ($argo->child(-1)->att('was') || '') eq "rv2sv")) {
            # horrible way to insert "<"
            set_madprop($arg, "comma", ', &quot;&lt;&quot;,');
            next;
        }
        my $c = $arg->child(1);
        if ($c and ($c->att('was') || '') eq "stringify") {
            $c = $c->child(2)->child(1);
        }
        if ($c and $c->tag eq "op_concat") {
            $c = $c->child(1);
        }
        next unless $c and $c->tag eq "op_const";
        my $prop = get_madprop($c, "value") ? "value" : "assign";
        my $v = get_madprop($c, $prop);
        next if $v eq "-" or $v eq "&gt;-";
        my $mode = '&lt;';
        if ($v =~ s/^ ( [+-]? (?: &lt; | &gt;(?:&gt;)? | \| ) (?:&amp;)? ) \s* //x) {
            $mode = $1;
            $mode eq "|" and $mode = "|-";
        } elsif ($v =~ s/\s* ( [|] ) $//x) {
            $mode = '-|';
        }
        set_madprop($arg, "comma", ", &quot;$mode&quot;,");
        set_madprop($c, $prop => $v);
    }
}

sub error_str {
    my $xml = shift;

    for my $op (map { $xml->findnodes($_) } qw|//op_rv2sv //op_null[@was="rv2sv"]|) {
        next unless (get_madprop($op, "variable") || '') eq '$@';
        next unless $op->parent->tag eq "op_match" or
          $op->parent->findnodes(q|.//*[@gv="main::like"]|);

        # horrible way to insert description
        set_madprop($op, "variable", '$@->{description}');
    }

    # replae $SIG{__DIE__} with $^DIE_HOOK
    for my $op_const ($xml->findnodes('//op_const')) {
        for my $name (qw|DIE WARN|) {
            next unless ($op_const->att('PV') || '') eq "__${name}__";
            next unless $op_const->parent->tag eq "op_helem";
            my $rv2hv = $op_const->parent->child(1);
            next unless $rv2hv->tag eq "op_rv2hv";
            next unless get_madprop($rv2hv, "variable") eq '$SIG';
            set_madprop($rv2hv, "variable", '$^' . $name . '_HOOK');
            set_madprop($op_const->parent, "curly_open", '');
            set_madprop($op_const->parent, "curly_close", '');
            set_madprop($op_const, $_, '') for qw|value quote_open quote_close assign|;
        }
    }
}

sub qstring {
    my $xml = shift;
    for my $mad_quote ($xml->findnodes(qq|//madprops/mad_null_type_first[\@val="quote"]|)) {
        my $op = $mad_quote->parent->parent;
        next unless get_madprop($op, "quote_open") eq "'";
        my $v = get_madprop($op, 'assign');
        next unless $v =~ m/\\/;
        $v =~ s/\\([\\\'])/$1/g;
        set_madprop($op, 'assign' => $v);
        if ($v =~ m/\'/) {
            my ($delim) = grep { $v !~ m/\Q$_/ } qw{| " ! : / \ + =};
            set_madprop($op, "quote_open" => "q$delim");
            set_madprop($op, "quote_close" => "$delim");
        }
    }
}

sub pointy_anon_hash {
    my $xml = shift;
    for my $op ($xml->findnodes(qq|//op_anonhash|)) {
        next unless get_madprop($op, "curly_open");
        set_madprop($op, "curly_open" => '&lt;');
        set_madprop($op, "curly_close" => ']');
    }
}

sub remove_dolsharp {
    my $xml = shift;
    # conversion of $#foo to (@foo-1)
    for my $op (map { $xml->findnodes($_) } qw|//op_av2arylen|) {
        my $varop = (grep { $_->tag =~ m/^op_(pad.v|rv2av)$/ } $op->children)[0] || $op;
        if (get_madprop($varop, "arylen") =~ m/^\$\#/) {
            my $name = get_madprop($varop, "arylen");
            $name =~ s/^\$\#/\@/;
            set_madprop($varop, "arylen", $name);
            set_madprop($varop, "wrap_open", "(");
            set_madprop($varop, "wrap_close", "-1)");
        }
    }
}

sub qq_escape_op {
    my ($op, $chars) = @_;

    for my $prop (qw|assign value|) {
        my $v = get_madprop($op, $prop);
        next unless $v;
        # sort of parser of '\\' and '\x{...}'
        my @v = split m/\\\\/, $v, -1;
        my @v_x = map { [split m'(\\[xN]{[^}]+})', $_, -1] } @v;
        for my $vx (@v_x) {
            my $i = 0;
            for (@$vx) {
                next if $i++ % 2;
                for my $char (@$chars) {
                    s/(\A|[^\\])([$char])/$1\\$2/g;
                    s/(\A|[^\\])([$char])/$1\\$2/g;
                }
            }
        }
        $v = join "\\\\", map { join '', @$_ } @v_x;
        set_madprop($op, $prop, $v);
    }
    for my $child ($op->children) {
        next if $child->tag eq "madprops";
        qq_escape_op($child, $chars);
    }
}

sub qq_escape {
    # escape '%' inside a double quoted string
    my ($xml, $chars) = @_;
    for my $mad_quote ($xml->findnodes(qq|//madprops/mad_null_type_first[\@val="quote"]|)) {
        my $op = $mad_quote->parent->parent;
        next unless get_madprop($op, "quote_open") =~ m/^(&#34;|&lt;&lt;[^']|qq)/;
        qq_escape_op($op, $chars);
    }

    # '{' and '}' inside s/../../g;
    for my $op_subst ($xml->findnodes(qq|//op_subst/|)) {
        my $op = $op_subst->child(-1);
        next unless $op and $op->tag ne "op_regcomp";
        next unless get_madprop($op_subst, "subst_open") ne "'";
        qq_escape_op($op, $chars);
    }
}

sub no_sigil_change {
    my $xml = shift;

    # conversion of $foo[1] to @foo[1]
    for my $op (map { $xml->findnodes($_) } qw|//op_aelemfast|) {
        if ((get_madprop($op, "variable") || '') =~ m/^\$/) {
            my $name = get_madprop($op, "variable");
            $name =~ s/^\$/\@/;
            set_madprop($op, "variable", $name);
        }
    }

    # conversion of $foo[$a] to @foo[$a] and $foo{$a} to %foo{$a}
    for my $op (map { $xml->findnodes($_) } qw|//op_aelem //op_null[@was='aelem'] //op_helem //op_null[@was='helem']|) {
        my $varop = $op;
        if (my $cop = $op->child(1)) {
            $varop = $cop if ($cop->tag || '') =~ m/^op_pad.v$/;
            $varop = $cop if ($cop->att('was') || $cop->tag || '') =~ m/^(op_)?rv2.v$/;
        }
        if ((get_madprop($varop, "variable") || '') =~ m/^\$/) {
            my $name = get_madprop($varop, "variable");
            ($op->tag eq "op_helem" || ($op->att('was') || '') eq 'helem') ? $name =~ s/^\$/\%/ : $name =~ s/^\$/\@/;
            set_madprop($varop, "variable", $name);
        }
    }

    # conversion of @foo{@bar} to %foo{[@bar]}
    for my $op (map { $xml->findnodes($_) } qw|//op_hslice //op_null[@was='hslice']|) {
        set_madprop($op, "curly_open", '{[');
        set_madprop($op, "curly_close", ']}');
        my $vop = $op->child(-1);
        next unless $vop->tag =~ m/hv$/;
        next unless get_madprop($vop, "ary") =~ m/^\@/;
        my $name = get_madprop($vop, "ary");
        $name =~ s/^\@/\%/;
        set_madprop($vop, 'ary', $name);
    }

    # conversion of @foo[1,2] to @foo[[1,2]]
    for my $op (map { $xml->findnodes($_) } qw|//op_aslice //op_null[@was='aslice'] //op_lslice //op_null[@was='lslice']|) {
        set_madprop($op, "square_open", '[[');
        set_madprop($op, "square_close", ']]');
    }
}

sub no_bracket_names {
    my $xml = shift;
    for my $prop (qw|variable ary|) {
        for my $var ($xml->findnodes("//madprops/mad_$prop")) {
            my $op = $var->parent->parent;
            if (get_madprop($op, $prop) =~ m/^(\$|\@)\{/) {
                my $v = get_madprop($op, $prop);
                if (is_in_string($op)) {
                    $v =~ s/(\$|\@)\{(.*)\}/\{$1$2\}/;
                } else {
                    $v =~ s/(\$|\@)\{(.*)\}/$1$2/;
                }
                set_madprop($op, $prop, $v);
            }
        }
    }
}

sub anon_aryhsh {
    my $xml = shift;
    for my $op ($xml->findnodes("//op_anonlist")) {
        next unless get_madprop($op, 'square_open');
        set_madprop($op, 'square_open', '\@(');
        set_madprop($op, 'square_close', ')');
    }
    for my $op ($xml->findnodes("//op_anonhash")) {
        next unless get_madprop($op, 'curly_open');
        set_madprop($op, 'curly_open', '\%(');
        set_madprop($op, 'curly_close', ')');
    }
}

sub eval_to_try {
    my $xml = shift;
    for my $op ($xml->findnodes("//op_leavetry")) {
        set_madprop($op, 'operator', 'try');
    }
}

sub sv_array_hash {
    my $xml = shift;
    for my $op ($xml->findnodes("//op_aassign")) {
        my (undef, $right, $left) = $op->children;

        next if $left->att('flags') =~ m/PARENS/;

        my $svt;
        $svt = $1 eq 'av' ? '@' : '%' if $left->child(1)->tag =~ m/op_(?:pad|rv2)(av|hv)/;
        next unless $svt;

        if ($right->child(1)->tag eq "op_null" 
            and (get_madprop($right->child(1), 'round_open') || '') eq '(') {
            set_madprop($right->child(1), 'round_open', "$svt(");
        } else {
            set_madprop($right, 'round_open', " $svt(");
            set_madprop($right, 'round_close', ' )');
        }
    }

    for my $op (map { $xml->findnodes("//op_$_") } qw|padav rv2av anonlist|) {
        my $flags = $op->att('flags') || '';
        my $main_prop = $op->tag eq "op_anonlist" ? 'square_open' : 'ary';
        if ( $op->tag eq "op_anonlist" and $flags =~ m/\bSPECIAL\b/) {
            next;
        }
        if ($flags =~ m/SCALAR/ and $flags !~ m/REF/) {
            set_madprop($op, $main_prop, 'nelems(' . get_madprop($op, $main_prop));
            set_madprop($op, 'round_open', "");
            set_madprop($op, 'round_close', ')');
            next;
        }
        next unless $flags; # only expand in list context.
        next if ($op->att('private') || '') =~ m/INTRO/ and $flags =~ m/UNKNOWN/;
        next if $flags =~ m/VOID/ or $op->parent->tag eq 'op_list' and $op->parent->att('flags') =~ m/VOID/;
        next if $flags =~ m/SPECIAL/ and $op->parent->parent->tag eq "op_aassign";
        next unless get_madprop($op, $main_prop);
        next if $op->parent->tag =~ m/op_(aelem|push|unshift|shift|pop|splice|undef|tie|tied|delete|defined|aslice|chomp|return)/ or 
            ($op->parent->att('was') || '') =~ m/^(aelem|aslice)$/;
        next if $op->parent->parent->tag =~ m/op_(refgen|chomp)/;

        if ($op->parent->tag eq "op_null" and $op->parent->parent->tag eq "op_join" and get_madprop($op->parent, "comma") eq '') {
            # this is a auto generated join inside some double quoted construct.
            set_madprop($op, $main_prop, q|{join ' ', &lt;| . get_madprop($op, $main_prop));
            set_madprop($op, 'round_open', q||);
            set_madprop($op, 'round_close', q|}|);
            next;
        }
        set_madprop($op, $main_prop, '&lt; ' . get_madprop($op, $main_prop));
    }
    for my $op (map { $xml->findnodes("//op_$_") } qw|padhv rv2hv anonhash|) {
        my $flags = $op->att('flags') || '';
        my $main_prop = $op->tag eq "op_anonhash" ? 'curly_open' : 'hsh';
        if ($op->att('flags') =~ m/SCALAR/ and $op->att('flags') !~ m/REF/) {
            next; # probably hash used a boolean
        }
        next unless $flags =~ m/LIST/; # only expand in list context.
        next if ($op->att('private') || '') =~ m/INTRO/ and $flags =~ m/UNKNOWN/;
        next if $op->att('flags') =~ m/VOID/ or $op->parent->tag eq 'op_list' and $op->parent->att('flags') =~ m/VOID/;
        next if $op->att('flags') =~ m/SPECIAL/ and $op->parent->parent->tag eq "op_aassign";
        next unless get_madprop($op, $main_prop);
        next if $op->parent->tag =~ m/op_(helem|each|keys|values|hslice|undef|tie|tied|delete|defined|hslice|return)/ or 
            ($op->parent->att('was') || '') =~ m/helem|hslice/;
        next if $op->parent->parent->tag eq "op_refgen";
        next if (get_madprop($op, 'prototyped') || '') eq '\%';
        set_madprop($op, $main_prop, '&lt; ' . get_madprop($op, $main_prop));
    }

    # add '<' in front of subcalls in list context.
    for my $op (map { $xml->findnodes("//op_$_") } qw|entersub|) {
        next unless ($op->att('flags')||'') =~ m/LIST/; # must be list context.

        next if (get_madprop($op->parent, 'comma') || '') eq '=&gt;'; # skip if preceded by '=>'

        set_madprop($op, 'wrap_open', ' &lt;');
    }

    # add @(...) around things which are lists in unknown context.
    for my $op (map { $xml->findnodes(qq|//op_$_|) } qw|null split mapwhile grepwhile grep sort keys values list|) {
        next unless ($op->att('flags') || '') =~ m/UNKNOWN/;
        my $null_type = get_madprop($op, 'null_type') || '';
        next unless $null_type =~ m/[(]|listop/ or $op->tag =~ m/mapwhile|grepwhile|list|keys|values/;

        if ((get_madprop($op, 'null_type_first') || '') eq "quote") {
            my $type = "quote";
            set_madprop($op, $type."_open", '@(' . get_madprop($op, $type."_open"));
            set_madprop($op, $type."_close", get_madprop($op, $type."_close") . ')');
        }
        if ($null_type eq "(") {
            next unless $op->children > 3;
        }
        my $type = ($null_type eq "(" or $op->tag eq "op_list") ? "round" : "wrap";
        set_madprop($op, $type."_open", ' @(');
        set_madprop($op, $type."_close", ' )');
    }

    for my $op (map { $xml->findnodes(qq|//op_$_|) } qw|return|) {
        next unless $op->children > 3;
        set_madprop($op, 'operator', 'return @(');
        set_madprop($op, 'round_close', ' )');
    }
}

sub no_auto_deref {
    my $xml = shift;
    for my $x (qw|a h|) {
        for my $op ($xml->findnodes("//op_${x}elem"), $xml->findnodes(qq|//op_null[\@was="${x}elem"]|)) {
            next unless $op->child(1)->tag eq "op_rv2${x}v";
            next if $op->child(1)->child(0)->tag eq "madprops";
            set_madprop($op, 'arrow', '->');
        }
    }
}

sub map_array {
    my $xml = shift;
    for my $map ($xml->findnodes("//op_mapstart"), $xml->findnodes("//op_grepstart")) {
        if ($map->att('flags') =~ m/\bLIST\b/) {
            set_madprop($map->parent, 'operator', '&lt; ' . get_madprop($map->parent, 'operator'));
        }

        my $block = $map->child(1);
        my $args = $map->child(2);
        # set_madprop($block, 'wrap_close', ',');

        my $xargs = XML::Twig::Elt->new("op_null");
        $args->replace_with($xargs);
        while ($map->children > 3) {
            $map->child(-1)->move($xargs);
        }
        $args->move($xargs);
        set_madprop($xargs, 'wrap_open', '@(', wsbefore => ' ');
        set_madprop($xargs, 'wrap_close', ')');
        if (get_madprop($args, 'comma')) {
            set_madprop($args, 'comma', '');
            set_madprop($block, 'wrap_close', ',');
        }
    }

    for my $map (map { $xml->findnodes("//$_") } qw|op_sort op_split op_reverse op_keys op_values op_range|) {
        if (($map->att('flags')||'') =~ m/\bLIST\b/) {
            set_madprop($map, 'wrap_open', ' &lt;' . (get_madprop($map, 'wrap_open') || ''));
        }
    }

    for my $map ($xml->findnodes("//op_null")) {
        next unless get_madprop($map, "quote_open");
        if ($map->att('flags') =~ m/\bLIST\b/) {
            set_madprop($map, 'wrap_open', ' &lt;' . (get_madprop($map, 'wrap_open') || ''));
        }
    }

    for my $map (map { $xml->findnodes("//$_") } qw|op_sort op_reverse|) {
        next if $map->tag eq "op_sort" and $map->att('flags') =~ m/\bSPECIAL\b/;
        my $args = $map->child(2);
        my $xargs = XML::Twig::Elt->new("op_null");
        $args->replace_with($xargs);
        while ($map->children > 3) {
            $map->child(-1)->move($xargs);
        }
        $args->move($xargs);
        set_madprop($xargs, 'wrap_open', '@(', wsbefore => ' ');
        set_madprop($xargs, 'wrap_close', ')');
    }

    for my $map (map { $xml->findnodes("//$_") } qw|op_join op_sort|) {
        next if $map->tag eq "op_sort" and not $map->att('flags') =~ m/\bSPECIAL\b/;
        my $preargs = $map->child(2);
        my $args = $map->child(3);
        my $xargs = XML::Twig::Elt->new("op_null");
        $args->replace_with($xargs);
        while ($map->children > 4) {
            $map->child(-1)->move($xargs);
        }
        $args->move($xargs);
        set_madprop($xargs, 'wrap_open', '@(', wsbefore => ' ');
        set_madprop($xargs, 'wrap_close', ')');

        if (get_madprop($args, 'comma')) {
            set_madprop($xargs, 'wrap_open', ', @(', wsbefore => '');
            set_madprop($args, 'comma', '');
        }
    }

    for my $leaveloop ($xml->findnodes("//op_leaveloop")) {
        next unless (get_madprop($leaveloop, 'while') || get_madprop($leaveloop, 'whilepost') || '') =~ m/^for/;
        my $op_enteriter = $leaveloop->child(1);
        next if $op_enteriter->att('flags') =~ m/\bSPECIAL\b/; # skip ranges
        my $x = ($op_enteriter->child(0)->tag eq "madprops") ? $op_enteriter->child(2) : $op_enteriter->child(1);
        next unless $x->tag eq "op_null";
        my $what = $x->child(1);
        if ($what->tag eq "op_expand") {
            set_madprop($what, "operator", '');
        }
        else {
            my $nwhat = XML::Twig::Elt->new("op_null");
            if (get_madprop($leaveloop, 'whilepost')) {
                set_madprop($nwhat, 'wrap_open', ' @(');
            } else {
                set_madprop($nwhat, 'wrap_open', '@(');
            }
            set_madprop($nwhat, 'wrap_close', ')');
            $what->replace_with($nwhat);
            while ($x->children > 2) {
                $x->child(-1)->move($nwhat);
            }
            $what->move($nwhat);
        }
    }

    for my $slice (map { $xml->findnodes("//$_",) } qw|op_aslice op_hslice|) {
        my $indices = $slice->child(2);
        my $thing = $slice->child(3);

        my $ni = XML::Twig::Elt->new("op_null");
        set_madprop($ni, 'wrap_open', '@(');
        set_madprop($ni, 'wrap_close', ')');
        $indices->replace_with($ni);
        $indices->move($ni);

        my $nt = XML::Twig::Elt->new("op_null");
        set_madprop($nt, 'wrap_open', ' &lt;');
        $thing->replace_with($nt);
        $thing->move($nt);
    }
}

sub simplify_array {
    my $xml = shift;

    for my $alop ($xml->find_nodes("//op_anonlist")) {
        next unless $alop->children_count == 3;
        next unless $alop->child(2)->tag eq "op_expand";
        $alop->child(2)->child(1)->replace($alop);
    }
}

sub ampcall {
    my $xml = shift;

    for my $esop ($xml->find_nodes("//op_entersub")) {
        next unless $esop->att('private') =~ m/\bAMPER\b/;
        next unless $esop->att('flags') !~ m/\bSTACKED\b/;
        set_madprop($esop, 'round_open', '( &lt; @_ ');
        set_madprop($esop, 'round_close', ')');
    }
}

sub doblock {
    my $xml = shift;

    for my $lineseq ($xml->find_nodes("//op_lineseq")) {
        next unless (get_madprop($lineseq, 'curly_open')||'') eq "\{";
        next if $lineseq->att('flags') =~ m/\bATTACHED\b/;
        next unless $lineseq->parent->tag eq "op_leaveloop";
        set_madprop($lineseq, 'curly_open', "do \{");
        set_madprop($lineseq, 'curly_close', "\};");
    }

    for my $scope ($xml->find_nodes("//op_scope"),
                   $xml->find_nodes("//op_leave")) {
        next unless is_in_string($scope);
        next unless (get_madprop($scope, 'curly_open')||'') eq "\{";
        next if $scope->att('flags') =~ m/\bLIST\b/;
        next if $scope->parent->tag =~ m/^op_rv2/;
        next if (get_madprop($scope->parent, 'do') || '') eq "do";
        set_madprop($scope, 'curly_open', "\$(");
        set_madprop($scope, 'curly_close', ")");
    }
}

sub remove_use_strict {
    my $xml = shift;
    for my $mad ($xml->findnodes(qq|//mad_op[\@key="use"]|)) {
        next unless $mad->child(0)->att("PV") eq "strict.pm";
        set_madprop($mad->child(0), "value", "", wsbefore => '');
        my ($args) = $mad->parent->findnodes(qq|mad_op[\@key="bigarrow"]|);
        $args->delete if $args;
        my $wsbefore = get_madprop($mad->parent->parent, "operator", "wsbefore");
        $wsbefore =~ s/&#xA;$//;
        set_madprop($mad->parent->parent, "operator", "", wsbefore => $wsbefore);
        set_madprop($mad->parent->parent, "semicolon", "");
    }
}

sub add_call_parens {
    my $xml = shift;
    for my $op ($xml->findnodes("//op_entersub")) {
        if ( not get_madprop($op, "null_type") ) {
            my $gvop = $op->child(0)->child(1);
            if (my $value = get_madprop($gvop, "value") ) {
                set_madprop($gvop, "value", $value . "()");
            }
        }
        elsif ( get_madprop($op, "null_type") eq "noamp" ) {
            set_madprop($op, "round_open", "(");
            set_madprop($op, "round_close", ")");
        }
    }
}

sub rename_ternary_op {
    my $xml = shift;
    for my $madprop ($xml->findnodes(qq|//mad_conditional_op[\@val="?"]|)) {
        my $op = $madprop->parent->parent;
        set_madprop($op, "conditional_op", "??");
        set_madprop($op, "attribute", "!!");
    }
}

sub hashkey_regulator {
    my $xml = shift;
    for my $op ($xml->findnodes(qq|//op_helem|)) {
        if ($op->att("flags") =~ m/\bMOD\b/
              and ($op->att("private")||'') !~ m/\bLVAL_DEFER\b/) {
            if ( $op->att("flags") =~ m/(\bSPECIAL\b|\bREF\b)/ ) {
                set_madprop($op, "curly_open", "{+");
            }
        }
        else {
            next if $op->following_elt()->tag eq "op_method_named";
            set_madprop($op, "curly_open", "{?");
        }
    }
}

sub pattern_assignment {
    my $xml = shift;

    for my $op ($xml->findnodes("//op_aassign")) {
        my (undef, $dst, $subj) = $op->children;

        next if ($subj->child(1)->tag eq "op_padsv")
          && ($dst->child(1)->tag =~ m/op_entersub|op_const|op_padsv/);

        for my $side ($subj, $dst) {
            if ( $side->tag eq "op_null"
                   and get_madprop($side, "round_open")) {
                set_madprop($side, "round_open", "\@(");
            }
            elsif ($side->child(1)->att("flags") =~ m/\bPARENS\b/
                     and get_madprop($side->child(1), "round_open")) {
                set_madprop($side->child(1), "round_open", "\@(");
            }
            elsif ( $side->child(1)->tag eq "op_expand") {
                set_madprop($side->child(1), "operator", '');
            }
            else {
                set_madprop($side->child(1), "wrap_open", "\@(");
                set_madprop($side->child(1), "wrap_close", ")");
            }
        }

        my ($exp) = $op->child(2)->findnodes(".//op_expand");
        if ( $exp and get_madprop($exp, "operator") ) {
            my $var = "\@";
            if ((get_madprop($exp->child(1), "hsh") || '') =~ m/%/) {
                $var = "%";
            }
            set_madprop($exp, "operator", $var . "&lt;");
        }
    }
}

sub env_using_package {
    my $xml = shift;

    for my $op ($xml->findnodes("//op_rv2hv")) {
        next unless get_madprop($op, "hsh") eq "\%ENV";
        next unless $op->parent->tag eq "op_helem";
        if (get_madprop($op->parent, "local")) {
            set_madprop($op, "hsh", "env::temp_set_var");
            set_madprop($op->parent, "local", '');
        }
        elsif ($op->parent->att('flags') =~ m/\bASSIGN\b/) {
            set_madprop($op, "hsh", "env::set_var");
        }
        elsif (is_in_string($op->parent)) {
            set_madprop($op, "hsh", "\$(env::var");
        }
        else {
            set_madprop($op, "hsh", "env::var");
        }
        set_madprop($op->parent, "curly_open", "(");
        if (is_in_string($op->parent)) {
            set_madprop($op->parent, "curly_close", "))");
        } else {
            set_madprop($op->parent, "curly_close", ")");
        }
        if ( $op->next_sibling->tag eq "op_const"
         and $op->next_sibling->att("private") =~ m/\bBARE\b/ ) {
            set_madprop($op->next_sibling, "value",
                        qq['] . get_madprop($op->next_sibling, "value") . qq[']);
        }
    }
}

sub remove_vars {
    my $xml = shift;
    for my $madop ($xml->findnodes(qq(//mad_op[\@key="use"]))) {
        next unless $madop->child(0)->att("PV") eq "vars.pm";
        my $madprops = $madop->parent;
        my $arrow_op = $madprops->child(2);
        my $vars = get_madprop($arrow_op->child(0)->child(1), "assign");

        $vars =~ s/^\s+|\s+$//g;
        $vars =~ s/([\s\n]+)/,$1/g;

        # replace whole tree
        my $nullop = $madprops->parent;
        my $ws = get_madprop($nullop, "operator", "wsbefore" );
        $madop->delete();
        $arrow_op->delete();
        set_madprop($nullop, "value", qq[our ($vars)], wsbefore => $ws );
        set_madprop($nullop, "null_type", "valuestatement");
    }
}

sub rename_magic_vars {
    my $xml = shift;

    my $mapping = {
        '$|' => '$^OUTPUT_AUTOFLUSH',
        '$!' => '$^OS_ERROR',
        '$?' => '$^CHILD_ERROR',
        '$&lt;' => '$^UID',
        '$&gt;' => '$^EUID',
        '$$' => '$^PID',
        '$/' => '$^INPUT_RECORD_SEPARATOR',
        '$\\' => '$^OUTPUT_RECORD_SEPARATOR',
        '$@' => '$^EVAL_ERROR',
        '$,' => '$^OUTPUT_FIELD_SEPARATOR',
        '$0' => '$^PROGRAM_NAME',
        '$^C' => '$^COMPILING',
        '$^D' => '$^DEBUGGING',
        '$^E' => '$^EXTENDED_OS_ERROR',
        '$^F' => '$^SYSTEM_FD_MAX',
        '$^H' => '$^HINT_BITS',
        '$^I' => '$^INPLACE_EDIT',
        '$^N' => '$^LAST_SUBMATCH_RESULT',
        '$^M' => '$^EMERGENCY_MEMORY',
        '$^O' => '$^OS_NAME',
        '$^P' => '$^PERLDB',
        '$^R' => '$^LAST_REGEXP_CODE_RESULT',
        '$^S' => '$^EXCEPTIONS_BEING_CAUGHT',
        '$^T' => '$^BASETIME',
        '$^V' => '$^PERL_VERSION',
        '$^W' => '$^WARNING',
        '$^X' => '$^EXECUTABLE_NAME',
    };

    for my $propname (qw[value variable]) {
        for ( find_ops( $xml, "rv2sv" ) ) {
            my $var = get_madprop($_, $propname);
            if ($var and $mapping->{$var}) {
                set_madprop($_, $propname => $mapping->{$var});
            }
        }

        for ( find_ops( $xml, "rv2hv" ) ) {
            my $var = get_madprop($_, $propname);
            if ($var and $var eq "%^H") {
                set_madprop($_, $propname => "\$^HINTS");
            }
        }
    }
}

sub rename_inc_vars {
    my $xml = shift;
    for my $propname (qw[value variable]) {
        for ( find_ops( $xml, "rv2av" ) ) {
            my $var = get_madprop($_, $propname);
            if ($var and $var eq "\@INC") {
                set_madprop($_, $propname => "\$^INCLUDE_PATH");
            }
        }
        for ( find_ops( $xml, "rv2hv" ) ) {
            my $var = get_madprop($_, $propname);
            if ($var and $var eq "\%INC") {
                set_madprop($_, $propname => "\$^INCLUDED");
            }
        }
    }
}

sub print_filehandle {
    my $xml = shift;
    for my $op ( find_ops( $xml, "print" ), find_ops( $xml, "prtf" ) ) {
        my $has_fh = $op->att("flags") =~ m/\bSTACKED\b/;
        my $stdout = XML::Twig::Elt->new("op_null");
        if ($has_fh) {
            my $fh = $op->child(2);
            if ($fh->tag eq "op_rv2gv" and $fh->child(0)->tag eq "op_gv"
                  and get_madprop($fh->child(0), "value") =~ m/^(STDOUT|STDERR)$/ ) {
                set_madprop($fh->child(0), value => "\\*" . get_madprop($fh->child(0), "value"));
            }
            if ($fh->tag eq "op_rv2gv" and $fh->child(0)->tag eq "op_scope") {
                set_madprop($fh->child(0), "curly_open", "");
                set_madprop($fh->child(0), "curly_close", "");
            }
        }
        my $arg = $has_fh ? "," : get_madprop($op, "round_open") ? "\\*STDOUT, " : " \\*STDOUT," ;
        set_madprop($stdout, value => $arg);
        set_madprop($stdout, "null_type" => "value");
        $stdout->cut;
        $stdout->paste( after => $op->child( $has_fh ? 2 : 1 ) );
    }
    return;
}

sub block_arg {
    my $xml = shift;
    for my $op (find_ops($xml, "mapstart"), find_ops($xml, "grepstart")) {
        my ($scope) = map { $op->findnodes("op_null/op_null/$_") } qw|op_scope op_leave|;
        if ($scope) {
            set_madprop($scope, "curly_close", "},");
        }
        else {
            my ($opnull) = $op->findnodes("op_null");
            set_madprop($opnull, "wrap_open", " {");
            set_madprop($opnull, "wrap_close", " }");
        }
    }
    for my $op (find_ops($xml, "entersub")) {
        my ($refgen) = $op->findnodes("op_null/op_srefgen");
        next unless $refgen;
        next if get_madprop($refgen, "operator");
        my ($scope) = $op->findnodes("op_null/op_srefgen/op_anoncode/op_leavesub/op_lineseq");
        next unless $scope;
        set_madprop($scope, "curly_close", "},");
    }
    for my $op (find_ops($xml, "sort")) {
        my ($scope) = map { $op->findnodes("op_null/$_") } qw|op_scope op_leave|;
        next unless $scope;
        set_madprop($scope, "curly_close", "},");
    }
}

sub must_haveargs {
    my $xml = shift;
    for my $op (find_ops($xml, "entersub")) {
        next if $op->att('flags') =~ m/\bSTACKED\b/;
        set_madprop($op, 'round_open', "( &lt; \@_ ");
        set_madprop($op, 'round_close', ")");
    }
}

sub make_prototype {
    my $xml = shift;
    for my $amp ($xml->findnodes(q{//mad_op[@key="ampersand"]})) {
        my @args = $amp->findnodes(q{.//madprops/mad_value[@val='@_']});
        next if @args > 1;
        if (@args) {
            my $arg_op = $args[0]->parent->parent;
            if (($arg_op->parent->tag eq "op_sassign")
                  and $arg_op->pos == 2
                    and $arg_op->parent->child(2)->tag eq "op_anonarray") {
                my $new_prototype = $arg_op->parent->child(2);
                set_madprop($new_prototype, 'square_open', '(', wsbefore => '');
                set_madprop($new_prototype, 'square_close', ')', wsbefore => '');
                del_madprop($new_prototype, 'defintion');
                my $pt = $amp->parent->insert_new_elt("mad_op",
                                                      { key => 'prototype' });
                $new_prototype->move($pt);
                if ($arg_op->parent->next_sibling->tag eq "op_nextstate") {
                    set_madprop($arg_op->parent->next_sibling,
                                'semicolon', '');
                }
                $arg_op->parent->delete();
            }
        }
    }
}

sub mg_stdin {
    my $xml = shift;
    for my $op (find_ops($xml, "rv2gv")) {
        for my $name (qw[STDIN STDOUT STDERR]) {
            if ((get_madprop($op, "star") || '') eq "*" . $name) {
                set_madprop($op, "star", '$^' . $name);
                if ($op->parent->tag eq "op_srefgen") {
                    set_madprop($op->parent, "operator", '');
                }
            }
        }
    }
}

sub local_undef {
    my $xml = shift;
    for my $op (find_ops($xml, "null"), find_ops($xml, "magicsv")) {
        next unless ($op->att('flags') || '') !~ m/\bASSIGN\b/;
        next unless get_madprop($op, 'local');
        set_madprop($op, 'wrap_close', ' = undef');
    }
}

my $from; # floating point number with starting version of kurila.
GetOptions("from=s" => \$from);
$from =~ m/(\w+)[-]([\d.]+)$/ or die "invalid from: '$from'";
$from = { branch => $1, 'v' => qv $2};

my $filename = shift @ARGV;

# parsing
my $twig= XML::Twig->new( # keep_spaces => 1,
                         discard_spaces => 1,
 keep_encoding => 1 );

$twig->parsefile( "-" );

if ($from->{branch} ne "kurila" or $from->{v} < v1.4) {
    # replacing.
    for my $op ($twig->findnodes(q|//op_entersub|)) {
        entersub_handler($twig, $op);
    }

    for my $op_const ($twig->findnodes(q|//op_const|)) {
        const_handler($twig, $op_const);
    }

    make_glob_sub( $twig );

#     # add_encoding_latin1($twig);

    remove_rv2gv($twig);
    remove_typed_declaration($twig);
}

if ($from->{branch} ne "kurila" or $from->{v} < v1.5) {
    rename_bit_operators($twig);
    remove_useversion($twig);
    change_deref_method($twig);

    for my $op_const ($twig->findnodes(q|//op_const|)) {
        const_handler($twig, $op_const);
    }
    intuit_more($twig);
}
#t_parenthesis($twig);

if ($from->{branch} ne "kurila" or $from->{v} < v1.6) {
    remove_vstring( $twig );
    use_pkg_version($twig);
    lvalue_subs( $twig, "substr" );
}

#pointy_anon_hash( $twig );
if ($from->{branch} ne "kurila" or $from->{v} < v1.7) {
    rename_pointy_ops( $twig );
    force_m( $twig );
    qq_escape( $twig, ['{', '}'] );
    qstring( $twig );
    open_3args($twig);
}

if ($from->{branch} ne "kurila" or $from->{v} < v1.8) {
    error_str($twig);
}

if ($from->{branch} ne "kurila" or $from->{v} < qv '1.10') {
    remove_dolsharp($twig);
    qq_escape($twig, ['%']);
    no_sigil_change($twig);
    no_bracket_names($twig);
}

if ($from->{branch} ne "kurila" or $from->{v} < qv '1.11') {
    anon_aryhsh($twig);
    no_auto_deref($twig);
}

if ($from->{branch} ne "kurila" or $from->{v} < qv '1.12') {
    eval_to_try($twig);
}

if ($from->{branch} ne "kurila" or $from->{v} < qv '1.13') {
    sv_array_hash($twig);
}

if ($from->{branch} ne "kurila" or $from->{v} < qv '1.14') {
    map_array($twig);
}
#simplify_array($twig);

if ($from->{branch} ne "kurila" or $from->{v} < qv '1.15') {
    ampcall($twig);
    doblock($twig);
    lvalue_subs( $twig, "vec" );
    remove_use_strict($twig);
}

if ($from->{branch} ne "kurila" or $from->{v} < qv '1.16') {
    rename_ternary_op($twig);
    hashkey_regulator($twig);
    pattern_assignment($twig);
}

if ($from->{branch} ne "kurila" or $from->{v} < qv '1.17') {
    env_using_package($twig);
    remove_vars($twig);
    rename_magic_vars($twig);
}

if ($from->{branch} ne "kurila" or $from->{v} < qv '1.17') {
    rename_inc_vars($twig);
    print_filehandle($twig);
    block_arg($twig);
}

#must_haveargs($twig);

#make_prototype($twig);
mg_stdin($twig);
local_undef($twig);

#add_call_parens($twig);

# print
$twig->print( pretty_print => 'indented' );
