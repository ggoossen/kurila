
/* This file contains the functions to propate the context through the optree */

#include "EXTERN.h"
#define PERL_IN_OP_CONTEXT_C
#include "perl.h"
#include "keywords.h"

OP *
Perl_scalarkids(pTHX_ OP *o)
{
    if (o && o->op_flags & OPf_KIDS) {
        OP *kid;
	for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling)
	    scalar(kid);
    }
    return o;
}

OP *
Perl_scalarboolean(pTHX_ OP *o)
{
    dVAR;

    PERL_ARGS_ASSERT_SCALARBOOLEAN;

    if (o->op_type == OP_SASSIGN && cBINOPo->op_first->op_type == OP_CONST) {
	if (ckWARN(WARN_SYNTAX)) {
	    Perl_warner(aTHX_ packWARN(WARN_SYNTAX), "Found = in conditional, should be ==");
	}
    }
    return scalar(o);
}

OP *
Perl_scalar(pTHX_ OP *o)
{
    dVAR;
    OP *kid;

    /* assumes no premature commitment */
    if (!o || (PL_parser && PL_parser->error_count)
	 || (o->op_flags & OPf_WANT)
	 || o->op_type == OP_RETURN)
    {
	return o;
    }

    o->op_flags = (o->op_flags & ~OPf_WANT) | OPf_WANT_SCALAR;

    switch (o->op_type) {
    case OP_REPEAT:
	scalar(cBINOPo->op_first);
	break;

    case OP_COND_EXPR:
	for (kid = cUNOPo->op_first->op_sibling; kid; kid = kid->op_sibling)
	    scalar(kid);
	break;
    case OP_MATCH:
    case OP_QR:
    case OP_SUBST:
    case OP_NULL:
    default:
	if (o->op_flags & OPf_KIDS) {
	    for (kid = cUNOPo->op_first; kid; kid = kid->op_sibling)
		scalar(kid);
	}
	break;
    case OP_LEAVE:
    case OP_LEAVETRY:
	kid = cLISTOPo->op_first;
	scalar(kid);
	while ((kid = kid->op_sibling)) {
	    if (kid->op_sibling)
		scalarvoid(kid);
	    else
		scalar(kid);
	}
	PL_curcop = &PL_compiling;
	break;
    case OP_SCOPE:
    case OP_LINESEQ:
    case OP_LISTLAST:
	for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling) {
	    if (kid->op_sibling)
		scalarvoid(kid);
	    else
		scalar(kid);
	}
	PL_curcop = &PL_compiling;
	break;
    case OP_LISTFIRST:
        assert(cLISTOPo->op_first->op_type == OP_PUSHMARK);
	kid = cLISTOPo->op_first->op_sibling;
	if (kid) {
            scalar(kid);
            for (kid = kid->op_sibling; kid; kid = kid->op_sibling) {
                scalarvoid(kid);
            }
	}
	PL_curcop = &PL_compiling;
	break;
    case OP_LIST:
	Perl_croak_at(aTHX_ o->op_location, "%s may not be used in scalar context", PL_op_desc[o->op_type]);
	break;
    case OP_ANONARRAY:
	break;
    }
    return o;
}

OP *
Perl_scalarvoid(pTHX_ OP *o)
{
    dVAR;
    OP *kid;
    const char* useless = NULL;
    SV* sv;
    U8 want;

    PERL_ARGS_ASSERT_SCALARVOID;

    /* trailing mad null ops don't count as "there" for void processing */
    if (PL_madskills &&
    	o->op_type != OP_NULL &&
	o->op_sibling &&
	o->op_sibling->op_type == OP_NULL)
    {
	OP *sib;
	for (sib = o->op_sibling;
		sib && sib->op_type == OP_NULL;
		sib = sib->op_sibling) ;
	
	if (!sib)
	    return o;
    }

    if (o->op_type == OP_NEXTSTATE
	|| o->op_type == OP_DBSTATE
	|| (o->op_type == OP_NULL && (o->op_targ == OP_NEXTSTATE
				      || o->op_targ == OP_DBSTATE)))
	PL_curcop = (COP*)o;		/* for warning below */

    /* assumes no premature commitment */
    want = o->op_flags & OPf_WANT;
    if ((want && want != OPf_WANT_SCALAR)
	 || (PL_parser && PL_parser->error_count)
	 || o->op_type == OP_RETURN)
    {
	return o;
    }

    if ((o->op_flags & OPf_TARGET_MY)
	&& (PL_opargs[o->op_type] & OA_TARGLEX))/* OPp share the meaning */
    {
	return scalar(o);			/* As if inside SASSIGN */
    }

    o->op_flags = (o->op_flags & ~OPf_WANT) | OPf_WANT_VOID;

    switch (o->op_type) {
    default:
	if (!(PL_opargs[o->op_type] & OA_FOLDCONST))
	    break;
	/* FALL THROUGH */
    case OP_REPEAT:
	if (o->op_flags & OPf_STACKED)
	    break;
	goto func_ops;
    case OP_SUBSTR:
    case OP_VEC:
	if (o->op_private == 4)
	    break;
	/* FALL THROUGH */
    case OP_GVSV:
    case OP_GV:
    case OP_PADSV:
    case OP_REF:
    case OP_SREFGEN:
    case OP_DEFINED:
    case OP_HEX:
    case OP_OCT:
    case OP_LENGTH:
    case OP_INDEX:
    case OP_RINDEX:
    case OP_SPRINTF:
    case OP_ASLICE:
    case OP_HSLICE:
    case OP_UNPACK:
    case OP_PACK:
    case OP_JOIN:
    case OP_LSLICE:
    case OP_SORT:
    case OP_REVERSE:
    case OP_RANGE:
    case OP_CALLER:
    case OP_FILENO:
    case OP_EOF:
    case OP_TELL:
    case OP_GETSOCKNAME:
    case OP_GETPEERNAME:
    case OP_READLINK:
    case OP_TELLDIR:
    case OP_GETPPID:
    case OP_GETPGRP:
    case OP_GETPRIORITY:
    case OP_TIME:
    case OP_TMS:
    case OP_LOCALTIME:
    case OP_GMTIME:
    case OP_GHBYNAME:
    case OP_GHBYADDR:
    case OP_GHOSTENT:
    case OP_GNBYNAME:
    case OP_GNBYADDR:
    case OP_GNETENT:
    case OP_GPBYNAME:
    case OP_GPBYNUMBER:
    case OP_GPROTOENT:
    case OP_GSBYNAME:
    case OP_GSBYPORT:
    case OP_GSERVENT:
    case OP_GPWNAM:
    case OP_GPWUID:
    case OP_GGRNAM:
    case OP_GGRGID:
    case OP_GETLOGIN:
    case OP_PROTOTYPE:
      func_ops:
	if (!(o->op_private & (OPpLVAL_INTRO|OPpOUR_INTRO)))
	    /* Otherwise it's "Useless use of grep iterator" */
	    useless = OP_DESC(o);
	break;
    case OP_HELEM:
    case OP_AELEM:
    case OP_AELEMFAST:
	if (!(o->op_private & (OPpLVAL_INTRO|OPpOUR_INTRO|OPpELEM_ADD)))
	    /* Otherwise it's "Useless use of grep iterator" */
	    useless = OP_DESC(o);
	break;

    case OP_ANONARRAY:
    case OP_ANONHASH:
	useless = OP_DESC(o);
	break;

    case OP_NOT:
       kid = cUNOPo->op_first;
       if (kid->op_type != OP_MATCH && kid->op_type != OP_SUBST) {
	   goto func_ops;
       }
       useless = "negative pattern binding (!~)";
       break;

    case OP_RV2GV:
    case OP_RV2SV:
    case OP_RV2AV:
    case OP_RV2HV:
	if (!(o->op_private & (OPpLVAL_INTRO|OPpOUR_INTRO)) &&
	    (!o->op_sibling || o->op_sibling->op_type != OP_READLINE))
	    useless = "a variable";
	break;

    case OP_CONST:
	sv = cSVOPo_sv;
	if (cSVOPo->op_private & OPpCONST_STRICT)
            Perl_croak_at(aTHX_
                o->op_location,
                "Bareword \"%"SVf"\" not allowed while \"strict subs\" in use",
                SVfARG(cSVOPo_sv));
	else {
	    if (ckWARN(WARN_VOID)) {
		useless = "a constant";
		/* don't warn on optimised away booleans, eg 
		 * use constant Foo, 5; Foo || print; */
		if (cSVOPo->op_private & OPpCONST_SHORTCIRCUIT)
		    useless = NULL;
		/* the constants 0 and 1 are permitted as they are
		   conventionally used as dummies in constructs like
		        1 while some_condition_with_side_effects;  */
		else if (SvNIOK(sv) && (SvNV(sv) == 0.0 || SvNV(sv) == 1.0))
		    useless = NULL;
		else if (SvPOK(sv)) {
                  /* perl4's way of mixing documentation and code
                     (before the invention of POD) was based on a
                     trick to mix nroff and perl code. The trick was
                     built upon these three nroff macros being used in
                     void context. The pink camel has the details in
                     the script wrapman near page 319. */
		    const char * const maybe_macro = SvPVX_const(sv);
		    if (strnEQ(maybe_macro, "di", 2) ||
			strnEQ(maybe_macro, "ds", 2) ||
			strnEQ(maybe_macro, "ig", 2))
			    useless = NULL;
		}
	    }
	}
	op_null(o);		/* don't execute or even remember it */
	break;

#ifndef PERL_MAD
    case OP_POSTINC:
	o->op_type = OP_PREINC;		/* pre-increment is faster */
	o->op_ppaddr = PL_ppaddr[OP_PREINC];
	break;

    case OP_POSTDEC:
	o->op_type = OP_PREDEC;		/* pre-decrement is faster */
	o->op_ppaddr = PL_ppaddr[OP_PREDEC];
	break;

    case OP_I_POSTINC:
	o->op_type = OP_I_PREINC;	/* pre-increment is faster */
	o->op_ppaddr = PL_ppaddr[OP_I_PREINC];
	break;

    case OP_I_POSTDEC:
	o->op_type = OP_I_PREDEC;	/* pre-decrement is faster */
	o->op_ppaddr = PL_ppaddr[OP_I_PREDEC];
	break;
#endif /* MAD */

    case OP_OR:
    case OP_AND:
    case OP_DOR:
    case OP_COND_EXPR:
	for (kid = cUNOPo->op_first->op_sibling; kid; kid = kid->op_sibling)
	    scalarvoid(kid);
	break;

    case OP_NULL:
	if (o->op_flags & OPf_STACKED)
	    break;
	/* FALL THROUGH */
    case OP_NEXTSTATE:
    case OP_DBSTATE:
    case OP_ENTERTRY:
    case OP_ENTER:
	if (!(o->op_flags & OPf_KIDS))
	    break;
	/* FALL THROUGH */
    case OP_SCOPE:
    case OP_LEAVE:
    case OP_LEAVETRY:
    case OP_LEAVELOOP:
    case OP_LINESEQ:
    case OP_LIST:
    case OP_LISTLAST:
    case OP_LISTFIRST:
	for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling)
	    scalarvoid(kid);
	break;
    case OP_SASSIGN:
	scalarvoid(cBINOPo->op_last);
	break;
    case OP_ENTEREVAL:
	scalarkids(o);
	break;
    case OP_REQUIRE:
	/* all requires must return a boolean value */
	o->op_flags &= ~OPf_WANT;
	/* FALL THROUGH */
    case OP_SCALAR:
	return scalar(o);
    case OP_SPLIT:
	if ((kid = cLISTOPo->op_first) && kid->op_type == OP_PUSHRE) {
	    if (!kPMOP->op_pmreplrootu.op_pmreplroot)
		deprecate_old("implicit split to @_");
	}
	break;
    }
    if (useless && !(o->op_flags & OPf_ASSIGN) 
	&& ckWARN(WARN_VOID))
	Perl_warner_at(aTHX_ o->op_location, packWARN(WARN_VOID), "Useless use of %s in void context", useless);
    return o;
}

OP *
Perl_listkids(pTHX_ OP *o)
{
    if (o && o->op_flags & OPf_KIDS) {
        OP *kid;
	for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling)
	    list(kid);
    }
    return o;
}

OP *
Perl_list(pTHX_ OP *o)
{
    dVAR;
    OP *kid;

    /* assumes no premature commitment */
    if (!o || (o->op_flags & OPf_WANT)
	 || (PL_parser && PL_parser->error_count)
	 || o->op_type == OP_RETURN)
    {
	return o;
    }

    if ((o->op_flags & OPf_TARGET_MY)
	&& (PL_opargs[o->op_type] & OA_TARGLEX))/* OPp share the meaning */
    {
	return o;				/* As if inside SASSIGN */
    }

    o->op_flags = (o->op_flags & ~OPf_WANT) | OPf_WANT_LIST;

    switch (o->op_type) {
    case OP_REPEAT:
	list(cBINOPo->op_first);
	break;
    case OP_OR:
    case OP_AND:
    case OP_COND_EXPR:
	for (kid = cUNOPo->op_first->op_sibling; kid; kid = kid->op_sibling)
	    list(kid);
	break;
    default:
    case OP_MATCH:
    case OP_QR:
    case OP_SUBST:
    case OP_NULL:
	if (!(o->op_flags & OPf_KIDS))
	    break;
    case OP_LIST:
	listkids(o);
	break;
    case OP_LEAVE:
    case OP_LEAVETRY:
	kid = cLISTOPo->op_first;
	list(kid);
	while ((kid = kid->op_sibling)) {
	    if (kid->op_sibling)
		scalarvoid(kid);
	    else
		list(kid);
	}
	PL_curcop = &PL_compiling;
	break;
    case OP_SCOPE:
    case OP_LINESEQ:
	for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling) {
	    if (kid->op_sibling)
		scalarvoid(kid);
	    else
		list(kid);
	}
	PL_curcop = &PL_compiling;
	break;
    case OP_REQUIRE:
	/* all requires must return a boolean value */
	o->op_flags &= ~OPf_WANT;
	return scalar(o);
    }
    return o;
}

OP *
Perl_scalarseq(pTHX_ OP *o)
{
    dVAR;
    if (o) {
	const OPCODE type = o->op_type;

	if (type == OP_LINESEQ || type == OP_SCOPE ||
	    type == OP_LEAVE || type == OP_LEAVETRY)
	{
            OP *kid;
	    for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling) {
		if (kid->op_sibling) {
		    scalarvoid(kid);
		}
	    }
	    PL_curcop = &PL_compiling;
	}
	o->op_flags &= ~OPf_PARENS;
	if (PL_hints & HINT_BLOCK_SCOPE)
	    o->op_flags |= OPf_PARENS;
    }
    else
	o = newOP(OP_STUB, 0, NULL);
    return o;
}

OP *
Perl_modkids(pTHX_ OP *o, I32 type)
{
    if (o && o->op_flags & OPf_KIDS) {
        OP **tokid;
	for (tokid = &(cLISTOPo->op_first); *tokid; tokid = &((*tokid)->op_sibling))
	    *tokid = mod(*tokid, type);
    }
    return o;
}

/* Propagate lvalue ("modifiable") context to an op and its children.
 * 'type' represents the context type, roughly based on the type of op that
 * would do the modifying, although local() is represented by OP_NULL.
 * It's responsible for detecting things that can't be modified,  flag
 * things that need to behave specially in an lvalue context (e.g., "$$x = 5"
 * might have to vivify a reference in $x), and so on.
 *
 * For example, "$a+1 = 2" would cause mod() to be called with o being
 * OP_ADD and type being OP_SASSIGN, and would output an error.
 */

OP *
Perl_mod(pTHX_ OP *o, I32 type)
{
    dVAR;
    OP **tokid;
    /* -1 = error on localize, 0 = ignore localize, 1 = ok to localize */
    int localize = -1;

    if (!o || (PL_parser && PL_parser->error_count))
	return o;

    if ((o->op_flags & OPf_TARGET_MY)
	&& (PL_opargs[o->op_type] & OA_TARGLEX))/* OPp share the meaning */
    {
	return o;
    }

    switch (o->op_type) {
    case OP_UNDEF:
	localize = 0;
	return o;
    case OP_STUB:
	if ((o->op_flags & OPf_PARENS) || PL_madskills)
	    break;
	goto nomod;
    default:
      nomod:
	/* grep, foreach, subcalls, refgen */
	if (type == OP_GREPSTART || type == OP_ENTERSUB || type == OP_SREFGEN)
	    break;
	Perl_croak_at(aTHX_ o->op_location, 
		      "Can't modify %s in %s",
		      (o->op_type == OP_NULL && (o->op_flags & OPf_SPECIAL)
		       ? "do block"
		       : OP_DESC(o)),
		      type ? PL_op_desc[type] : "local");
	return o;

    case OP_PREINC:
    case OP_PREDEC:
    case OP_POW:
    case OP_MULTIPLY:
    case OP_DIVIDE:
    case OP_MODULO:
    case OP_REPEAT:
    case OP_ADD:
    case OP_SUBTRACT:
    case OP_CONCAT:
    case OP_LEFT_SHIFT:
    case OP_RIGHT_SHIFT:
    case OP_BIT_AND:
    case OP_BIT_XOR:
    case OP_BIT_OR:
    case OP_I_MULTIPLY:
    case OP_I_DIVIDE:
    case OP_I_MODULO:
    case OP_I_ADD:
    case OP_I_SUBTRACT:
	if (!(o->op_flags & OPf_STACKED))
	    goto nomod;
	break;

    case OP_COND_EXPR:
	localize = 1;
	for (tokid = &(cUNOPo->op_first->op_sibling); *tokid; tokid = &((*tokid)->op_sibling))
	    *tokid = mod(*tokid, type);
	break;

    case OP_RV2GV:
/* 	if (scalar_mod_type(o, type)) */
/* 	    goto nomod; */
	doref(cUNOPo->op_first, o->op_type, TRUE);
	localize = 1;
	break;
    case OP_ASLICE:
    case OP_HSLICE:
	localize = 1;
	/* FALL THROUGH */
    case OP_NEXTSTATE:
    case OP_DBSTATE:
	break;
    case OP_RV2CV:
    case OP_RV2AV:
    case OP_RV2HV:
    case OP_RV2SV:
	doref(cUNOPo->op_first, o->op_type, TRUE);
	localize = 1;
	/* FALL THROUGH */
    case OP_GV:
	PL_hints |= HINT_BLOCK_SCOPE;
        break;
    case OP_SASSIGN:
    case OP_ANDASSIGN:
    case OP_ORASSIGN:
    case OP_DORASSIGN:
        break;

    case OP_AELEMFAST:
	localize = -1;
	break;

    case OP_EXPAND:
	cUNOPo->op_first = mod(cUNOPo->op_first, type);
	break;

    case OP_DOTDOTDOT:
    case OP_PLACEHOLDER:
	localize = 0;
	break;

    case OP_PADSV:
	if (!type) /* local() */
	    Perl_croak(aTHX_ "Can't localize lexical variable %s",
		 PAD_COMPNAME_PV(o->op_targ));
	break;

    case OP_MAGICSV:
	localize = 1;
	if ( type && type != OP_SASSIGN && type != OP_SUBST )
	    goto nomod;
	break;

    case OP_PUSHMARK:
	localize = 0;
	break;

    case OP_KEYS:
        goto nomod;
	break;

    case OP_AELEM:
    case OP_HELEM:
        o = op_mod_assign(
            o,
            &(cBINOPo->op_first),
            type == OP_NULL ? o->op_type : type
            );
	localize = 1;
	break;

    case OP_ENTERSUB_SAVE:
        o = op_mod_assign(
            o,
            &(cUNOPo->op_first),
            type == OP_NULL ? o->op_type : type
            );

	localize = 1;
        break;
    case OP_ENTERSUB:
        if ( ! type ) {
            /* add localize opcode */
            const PADOFFSET po = pad_alloc(OP_SASSIGN, SVs_PADTMP);
            o->op_targ = po;
            o->op_private |= OPpENTERSUB_SAVEARGS;
            o = newUNOP(OP_ENTERSUB_SAVE, 0, scalar(o), o->op_location);
            o->op_targ = po;
        }
	localize = 1;
        break;

    case OP_SCOPE:
    case OP_LEAVE:
    case OP_ENTER:
    case OP_LINESEQ:
	localize = 0;
	if (o->op_flags & OPf_KIDS)
	    cLISTOPo->op_last = mod(cLISTOPo->op_last, type);
	break;

    case OP_NULL:
	localize = 0;
	if (o->op_flags & OPf_SPECIAL)		/* do BLOCK */
	    goto nomod;
	else if (!(o->op_flags & OPf_KIDS))
	    break;
	if (o->op_targ != OP_LIST) {
	    cBINOPo->op_first = mod(cBINOPo->op_first, type);
	    break;
	}
	/* FALL THROUGH */
    case OP_HASHEXPAND:
    case OP_ARRAYEXPAND:
    case OP_LIST:
	localize = 0;
	for (tokid = &(cLISTOPo->op_first); *tokid; tokid = &((*tokid)->op_sibling))
	    *tokid = mod(*tokid, type);
	break;

    case OP_ANONARRAY:
    case OP_ANONHASH:
    case OP_ANONSCALAR:
        if ( ! type ) {
            /* propagate localize */
            for (tokid = &(cLISTOPo->op_first); *tokid; tokid = &((*tokid)->op_sibling))
                *tokid = mod(*tokid, type);
        }
        localize = 0;
        break;
        
    case OP_LISTLAST:
	localize = 0;
	if (o->op_flags & OPf_KIDS)
	    cLISTOPo->op_last = mod(cLISTOPo->op_last, type);
	break;

    case OP_LISTFIRST:
	localize = 0;
	if (o->op_flags & OPf_KIDS)
	    cLISTOPo->op_first->op_sibling = mod(cLISTOPo->op_first->op_sibling, type);
	break;

    case OP_RETURN:
	goto nomod;
	break; /* mod()ing was handled by ck_return() */
    }

    /* [20011101.069] File test operators interpret OPf_REF to mean that
       their argument is a filehandle; thus \stat(".") should not set
       it. AMS 20011102 */
    if (type == OP_SREFGEN &&
        PL_check[o->op_type] == MEMBER_TO_FPTR(Perl_ck_ftst))
        return o;

    o->op_flags |= OPf_MOD;

    if (type == OP_SASSIGN)
	o->op_flags |= OPf_SPECIAL|OPf_REF;
    else if (!type) { /* local() */
	switch (localize) {
	case 1:
	    o->op_private |= OPpLVAL_INTRO;
	    o->op_flags &= ~OPf_SPECIAL;
	    PL_hints |= HINT_BLOCK_SCOPE;
	    break;
	case 0:
	    break;
	case -1:
	    Perl_croak(aTHX_ "Can't localize %s", OP_DESC(o));
	}
    }
    else if (type != OP_GREPSTART && type != OP_ENTERSUB)
	o->op_flags |= OPf_REF;
    return o;
}


OP *
Perl_refkids(pTHX_ OP *o, I32 type)
{
    if (o && o->op_flags & OPf_KIDS) {
        OP *kid;
	for (kid = cLISTOPo->op_first; kid; kid = kid->op_sibling)
	    doref(kid, type, TRUE);
    }
    return o;
}

OP *
Perl_doref(pTHX_ OP *o, I32 type, bool set_op_ref)
{
    dVAR;
    OP *kid;

    PERL_ARGS_ASSERT_DOREF;

    if (!o || (PL_parser && PL_parser->error_count))
	return o;

    switch (o->op_type) {
    case OP_ENTERSUB:
	break;
    case OP_COND_EXPR:
	for (kid = cUNOPo->op_first->op_sibling; kid; kid = kid->op_sibling)
	    doref(kid, type, set_op_ref);
	break;
    case OP_RV2SV:
	if (type == OP_DEFINED)
	    o->op_flags |= OPf_SPECIAL;		/* don't create GV */
	doref(cUNOPo->op_first, o->op_type, set_op_ref);
	/* FALL THROUGH */
    case OP_PADSV:
	if (type == OP_RV2SV || type == OP_RV2AV || type == OP_RV2HV) {
	    o->op_private |= (type == OP_RV2AV ? OPpDEREF_AV
			      : type == OP_RV2HV ? OPpDEREF_HV
			      : OPpDEREF_SV);
	    o->op_flags |= OPf_MOD;
	}
	break;

    case OP_RV2CV:
        o->op_flags |= OPf_SPECIAL;
        break;
    case OP_RV2AV:
    case OP_RV2HV:
	if (set_op_ref)
	    o->op_flags |= OPf_REF;
	/* FALL THROUGH */
    case OP_RV2GV:
	if (type == OP_DEFINED)
	    o->op_flags |= OPf_SPECIAL;		/* don't create GV */
	doref(cUNOPo->op_first, o->op_type, set_op_ref);
	break;

    case OP_ANONARRAY:
    case OP_ANONHASH:
	if (set_op_ref)
	    o->op_flags |= OPf_REF;
	break;

    case OP_SCALAR:
    case OP_NULL:
	if (!(o->op_flags & OPf_KIDS))
	    break;
	doref(cBINOPo->op_first, type, set_op_ref);
	break;
    case OP_AELEM:
    case OP_HELEM:
	doref(cBINOPo->op_first, o->op_type, set_op_ref);
	if (type == OP_RV2SV || type == OP_RV2AV || type == OP_RV2HV) {
	    o->op_private |= (type == OP_RV2AV ? OPpDEREF_AV
			      : type == OP_RV2HV ? OPpDEREF_HV
			      : OPpDEREF_SV);
	    o->op_flags |= OPf_MOD;
	}
	break;

    case OP_SCOPE:
    case OP_LEAVE:
	set_op_ref = FALSE;
	/* FALL THROUGH */
    case OP_ENTER:
    case OP_LIST:
    case OP_LISTLAST:
	if (!(o->op_flags & OPf_KIDS))
	    break;
	doref(cLISTOPo->op_last, type, set_op_ref);
	break;
    case OP_LISTFIRST:
	if (!(o->op_flags & OPf_KIDS))
	    break;
	doref(cLISTOPo->op_first, type, set_op_ref);
	break;
    default:
	break;
    }
    return scalar(o);

}
