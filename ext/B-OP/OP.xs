#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "perlapi.h"
#include "XSUB.h"

#ifdef PERL_OBJECT
#undef PL_op_name
#undef PL_opargs 
#undef PL_op_desc
#define PL_op_name (get_op_names())
#define PL_opargs (get_opargs())
#define PL_op_desc (get_op_descs())
#endif

static char *svclassnames[] = {
    "B::NULL",
    "B::BIND",
    "B::IV",
    "B::NV",
    "B::PV",
    "B::PVIV",
    "B::PVNV",
    "B::PVMG",
    "B::REGEXP",
    "B::GV",
    "B::PVLV",
    "B::AV",
    "B::HV",
    "B::CV",
    "B::IO",
};

typedef enum {
    OPc_NULL,	/* 0 */
    OPc_BASEOP,	/* 1 */
    OPc_UNOP,	/* 2 */
    OPc_BINOP,	/* 3 */
    OPc_LOGOP,	/* 4 */
    OPc_LISTOP,	/* 5 */
    OPc_PMOP,	/* 6 */
    OPc_SVOP,	/* 7 */
    OPc_PADOP,	/* 8 */
    OPc_PVOP,	/* 9 */
    OPc_LOOP,	/* 10 */
    OPc_COP	/* 11 */
} opclass;

static char *opclassnames[] = {
    "B::NULL",
    "B::OP",
    "B::UNOP",
    "B::BINOP",
    "B::LOGOP",
    "B::LISTOP",
    "B::PMOP",
    "B::SVOP",
    "B::PADOP",
    "B::PVOP",
    "B::LOOP",
    "B::COP"
};

static const size_t opsizes[] = {
    0,	
    sizeof(OP),
    sizeof(UNOP),
    sizeof(BINOP),
    sizeof(LOGOP),
    sizeof(LISTOP),
    sizeof(PMOP),
    sizeof(SVOP),
    sizeof(PADOP),
    sizeof(PVOP),
    sizeof(LOOP),
    sizeof(COP)	
};

static int walkoptree_debug = 0; /* Flag for walkoptree debug hook */

static SV *specialsv_list[6];

SV** my_current_pad;
SV** tmp_pad;

HV* root_cache;

#define GEN_PAD      { set_active_sub(find_cv_by_root((OP*)o));tmp_pad = PL_curpad;PL_curpad = my_current_pad; }
#define OLD_PAD      (PL_curpad = tmp_pad)
/* #define GEN_PAD */
/* #define OLD_PAD */

void
set_active_sub(SV *sv)
{
    AV* padlist; 
    SV** svp;
    /* dTHX; */
    //      sv_dump(SvRV(sv));
    padlist = CvPADLIST(SvRV(sv));
    if(!padlist) {
        dTHX;
        sv_dump(sv);
        sv_dump((SV*)padlist);
    }
    svp = AvARRAY(padlist);
    my_current_pad = AvARRAY((AV*)svp[1]);
}

static SV *
find_cv_by_root(OP* o) {
  dTHX;
  OP* root = o;
  SV* key;
  SV* val;
  SV* cached;

  if(PL_compcv && SvTYPE(PL_compcv) == SVt_PVCV &&
        !PL_eval_root) {
    if(SvROK(PL_compcv))
       sv_dump(SvRV(PL_compcv));
    return newRV((SV*)PL_compcv);
  }     


  if(!root_cache)
    root_cache = newHV();

  while(root->op_next)
    root = root->op_next;

  key = newSViv(PTR2IV(root));
  
  cached = hv_fetch(root_cache, key, strlen(key), 0);
  if(cached) {
      return cached;
  }
  

  if(PL_main_root == root) {
    /* Special case, this is the main root */
      cached = newRV((SV*)PL_main_cv);
      hv_store_ent(root_cache, key, cached, 0);
  } else if(PL_eval_root == root && PL_compcv) { 
    SV* tmpcv = (SV*)NEWSV(1104,0);
    sv_upgrade((SV *)tmpcv, SVt_PVCV);
    CvPADLIST(tmpcv) = CvPADLIST(PL_compcv);
    SvREFCNT_inc(CvPADLIST(tmpcv));
    CvROOT(tmpcv) = root;
    OP_REFCNT_LOCK;
    OpREFCNT_inc(root);
    OP_REFCNT_UNLOCK;
    cached = newRV((SV*)tmpcv);
    hv_store_ent(root_cache, key, cached, 0);
  } else {
    /* Need to walk the symbol table, yay */
    CV* cv = 0;
    SV* sva;
    SV* sv;
    register SV* svend;

    for (sva = PL_sv_arenaroot; sva; sva = (SV*)SvANY(sva)) {
      svend = &sva[SvREFCNT(sva)];
      for (sv = sva + 1; sv < svend; ++sv) {
        if (SvTYPE(sv) != SVTYPEMASK && SvREFCNT(sv)) {
          if(SvTYPE(sv) == SVt_PVCV &&
             CvROOT(sv) == root
             ) {
            cv = (CV*) sv;
          } else if(SvTYPE(sv) == SVt_PVGV && GvGP(sv) &&
                    GvCV(sv) && !CvXSUB(GvCV(sv)) &&
                    CvROOT(GvCV(sv)) == root)
                     {
            cv = (CV*) GvCV(sv);
          }
        }
      }
    }

    if(!cv) {
      Perl_die(aTHX_ "I am sorry but we couldn't find this root!\n");
    }

    cached = newRV((SV*)cv);
    hv_store_ent(root_cache, key, cached, 0);
  }

  return cached;
}


static SV *
make_sv_object(pTHX_ SV *arg, SV *sv)
{
    char *type = 0;
    IV iv;

    for (iv = 0; iv < sizeof(specialsv_list)/sizeof(SV*); iv++) {
    if (sv == specialsv_list[iv]) {
        type = "B::SPECIAL";
        break;
    }
    }
    if (!type) {
    type = svclassnames[SvTYPE(sv)];
    iv = PTR2IV(sv);
    }
    sv_setiv(newSVrv(arg, type), iv);
    return arg;
}


/*
   #define PERL_CUSTOM_OPS
   now defined by Build.PL, if building for 5.8.x
 */
static I32
op_name_to_num(SV * name)
{
    dTHX;
    char const *s;
    char *wanted = SvPV_nolen(name);
    int i =0;
    int topop = OP_max;

#ifdef PERL_CUSTOM_OPS
    topop--;
#endif

    if (SvIOK(name) && SvIV(name) >= 0 && SvIV(name) < topop)
        return SvIV(name);

    for (s = PL_op_name[i]; s; s = PL_op_name[++i]) {
        if (strEQ(s, wanted))
            return i;
    }
#ifdef PERL_CUSTOM_OPS
    if (PL_custom_op_names) {
        HE* ent;
        SV* value;
        /* This is sort of a hv_exists, backwards */
        (void)hv_iterinit(PL_custom_op_names);
        while ((ent = hv_iternext(PL_custom_op_names))) {
            if (strEQ(SvPV_nolen(hv_iterval(PL_custom_op_names,ent)),wanted))
                return OP_CUSTOM;
        }
    }
#endif

    croak("No such op \"%s\"", SvPV_nolen(name));

    return -1;
}

#ifdef PERL_CUSTOM_OPS
static void* 
custom_op_ppaddr(char *name)
{
    dTHX;
    HE *ent;
    SV *value;
    if (!PL_custom_op_names)
        return 0;
    
    /* This is sort of a hv_fetch, backwards */
    (void)hv_iterinit(PL_custom_op_names);
    while ((ent = hv_iternext(PL_custom_op_names))) {
        if (strEQ(SvPV_nolen(hv_iterval(PL_custom_op_names,ent)),name))
            return (void*)SvIV(hv_iterkeysv(ent));
    }

    return 0;
}
#endif

static opclass
cc_opclass(pTHX_ const OP *o)
{
    if (!o)
	return OPc_NULL;

    if (o->op_type == 0)
	return (o->op_flags & OPf_KIDS) ? OPc_UNOP : OPc_BASEOP;

    if (o->op_type == OP_SASSIGN)
	return (OPc_BINOP);

    if (o->op_type == OP_AELEMFAST) {
	if (o->op_flags & OPf_SPECIAL)
	    return OPc_BASEOP;
	else
	    return OPc_SVOP;
    }
    
    switch (PL_opargs[o->op_type] & OA_CLASS_MASK) {
    case OA_BASEOP:
	return OPc_BASEOP;

    case OA_UNOP:
	return OPc_UNOP;

    case OA_BINOP:
	return OPc_BINOP;

    case OA_LOGOP:
	return OPc_LOGOP;

    case OA_LISTOP:
	return OPc_LISTOP;

    case OA_PMOP:
	return OPc_PMOP;

    case OA_SVOP:
	return OPc_SVOP;

    case OA_PADOP:
	return OPc_PADOP;

    case OA_LOOP:
	return OPc_LOOP;

    case OA_COP:
	return OPc_COP;

    case OA_BASEOP_OR_UNOP:
	/*
	 * UNI(OP_foo) in toke.c returns token UNI or FUNC1 depending on
	 * whether parens were seen. perly.y uses OPf_SPECIAL to
	 * signal whether a BASEOP had empty parens or none.
	 * Some other UNOPs are created later, though, so the best
	 * test is OPf_KIDS, which is set in newUNOP.
	 */
	return (o->op_flags & OPf_KIDS) ? OPc_UNOP : OPc_BASEOP;

    case OA_FILESTATOP:
	/*
	 * The file stat OPs are created via UNI(OP_foo) in toke.c but use
	 * the OPf_REF flag to distinguish between OP types instead of the
	 * usual OPf_SPECIAL flag. As usual, if OPf_KIDS is set, then we
	 * return OPc_UNOP so that walkoptree can find our children. If
	 * OPf_KIDS is not set then we check OPf_REF. Without OPf_REF set
	 * (no argument to the operator) it's an OP; with OPf_REF set it's
	 * an SVOP (and op_sv is the GV for the filehandle argument).
	 */
	return ((o->op_flags & OPf_KIDS) ? OPc_UNOP :
#ifdef USE_ITHREADS
		(o->op_flags & OPf_REF) ? OPc_PADOP : OPc_BASEOP);
#else
		(o->op_flags & OPf_REF) ? OPc_SVOP : OPc_BASEOP);
#endif
    case OA_LOOPEXOP:
	/*
	 * next, last, redo, dump and goto use OPf_SPECIAL to indicate that a
	 * label was omitted (in which case it's a BASEOP) or else a term was
	 * seen. In this last case, all except goto are definitely PVOP but
	 * goto is either a PVOP (with an ordinary constant label), an UNOP
	 * with OPf_STACKED (with a non-constant non-sub) or an UNOP for
	 * OP_REFGEN (with goto &sub) in which case OPf_STACKED also seems to
	 * get set.
	 */
	if (o->op_flags & OPf_STACKED)
	    return OPc_UNOP;
	else if (o->op_flags & OPf_SPECIAL)
	    return OPc_BASEOP;
	else
	    return OPc_PVOP;
    }
    warn("can't determine class of operator %s, assuming BASEOP\n",
	 PL_op_name[o->op_type]);
    return OPc_BASEOP;
}

static char *
cc_opclassname(pTHX_ OP *o)
{
    return opclassnames[cc_opclass(aTHX_ o)];
}

static OP * 
SVtoO(SV* sv) {
    dTHX;
    if (SvROK(sv)) {
        IV tmp = SvIV((SV*)SvRV(sv));
        return INT2PTR(OP*,tmp);
    }
    else {
        return 0;
    }
        croak("Argument is not a reference");
    return 0; /* Not reached */
}

static void
walkoptree(pTHX_ SV *opsv, const char *method)
{
    dSP;
    OP *o, *kid;

    if (!SvROK(opsv))
	croak("opsv is not a reference");
    opsv = sv_mortalcopy(opsv);
    o = INT2PTR(OP*,SvIV((SV*)SvRV(opsv)));
    if (walkoptree_debug) {
	PUSHMARK(sp);
	XPUSHs(opsv);
	PUTBACK;
	perl_call_method("walkoptree_debug", G_DISCARD);
    }
    PUSHMARK(sp);
    XPUSHs(opsv);
    PUTBACK;
    perl_call_method(method, G_DISCARD);
    if (o && (o->op_flags & OPf_KIDS)) {
	for (kid = ((UNOP*)o)->op_first; kid; kid = kid->op_sibling) {
	    /* Use the same opsv. Rely on methods not to mess it up. */
	    sv_setiv(newSVrv(opsv, cc_opclassname(aTHX_ kid)), PTR2IV(kid));
	    walkoptree(aTHX_ opsv, method);
	}
    }
    if (o && (cc_opclass(aTHX_ o) == OPc_PMOP) && o->op_type != OP_PUSHRE
#if PERL_VERSION >= 9
	    && (kid = cPMOPo->op_pmreplrootu.op_pmreplroot)
#else
	    && (kid = cPMOPo->op_pmreplroot)
#endif
	)
    {
	sv_setiv(newSVrv(opsv, cc_opclassname(aTHX_ kid)), PTR2IV(kid));
	walkoptree(aTHX_ opsv, method);
    }
}

static SV **
oplist(pTHX_ OP *o, SV **SP)
{
    for(; o; o = o->op_next) {
	SV *opsv;
#if PERL_VERSION >= 9
	if (o->op_opt == 0)
	    break;
	o->op_opt = 0;
#else
	if (o->op_seq == 0)
	    break;
	o->op_seq = 0;
#endif
	opsv = sv_newmortal();
	sv_setiv(newSVrv(opsv, cc_opclassname(aTHX_ (OP*)o)), PTR2IV(o));
	XPUSHs(opsv);
        switch (o->op_type) {
	case OP_SUBST:
#if PERL_VERSION >= 9
            SP = oplist(aTHX_ cPMOPo->op_pmstashstartu.op_pmreplstart, SP);
#else
            SP = oplist(aTHX_ cPMOPo->op_pmreplstart, SP);
#endif
            continue;
	case OP_SORT:
	    if (o->op_flags & OPf_STACKED && o->op_flags & OPf_SPECIAL) {
		OP *kid = cLISTOPo->op_first->op_sibling;   /* pass pushmark */
		kid = kUNOP->op_first;                      /* pass rv2gv */
		kid = kUNOP->op_first;                      /* pass leave */
		SP = oplist(aTHX_ kid->op_next, SP);
	    }
	    continue;
        }
	switch (PL_opargs[o->op_type] & OA_CLASS_MASK) {
	case OA_LOGOP:
	    SP = oplist(aTHX_ cLOGOPo->op_other, SP);
	    break;
	case OA_LOOP:
	    SP = oplist(aTHX_ cLOOPo->op_lastop, SP);
	    SP = oplist(aTHX_ cLOOPo->op_nextop, SP);
	    SP = oplist(aTHX_ cLOOPo->op_redoop, SP);
	    break;
	}
    }
    return SP;
}

static SV *
make_temp_object(pTHX_ SV *arg, SV *temp)
{
    SV *target;
    const char *const type = svclassnames[SvTYPE(temp)];
    const IV iv = PTR2IV(temp);

    target = newSVrv(arg, type);
    sv_setiv(target, iv);

    /* Need to keep our "temp" around as long as the target exists.
       Simplest way seems to be to hang it from magic, and let that clear
       it up.  No vtable, so won't actually get in the way of anything.  */
    sv_magicext(target, temp, PERL_MAGIC_ext, NULL, NULL, 0);
    /* magic object has had its reference count increased, so we must drop
       our reference.  */
    SvREFCNT_dec(temp);
    return arg;
}

static SV *
make_warnings_object(pTHX_ SV *arg, STRLEN *warnings)
{
    const char *type = 0;
    IV iv = sizeof(specialsv_list)/sizeof(SV*);

    /* Counting down is deliberate. Before the split between make_sv_object
       and make_warnings_obj there appeared to be a bug - Nullsv and pWARN_STD
       were both 0, so you could never get a B::SPECIAL for pWARN_STD  */

    while (iv--) {
	if ((SV*)warnings == specialsv_list[iv]) {
	    type = "B::SPECIAL";
	    break;
	}
    }
    if (type) {
	sv_setiv(newSVrv(arg, type), iv);
	return arg;
    } else {
	/* B assumes that warnings are a regular SV. Seems easier to keep it
	   happy by making them into a regular SV.  */
	return make_temp_object(aTHX_ arg,
				newSVpvn((char *)(warnings + 1), *warnings));
    }
}

static SV *
make_cop_io_object(pTHX_ SV *arg, COP *cop)
{
    SV *const value = newSV(0);

    Perl_emulate_cop_io(aTHX_ cop, value);

    if(SvOK(value)) {
	return make_temp_object(aTHX_ arg, newSVsv(value));
    } else {
	SvREFCNT_dec(value);
	return make_sv_object(aTHX_ arg, NULL);
    }
}

typedef OP      *B__OP;
typedef UNOP    *B__UNOP;
typedef BINOP   *B__BINOP;
typedef LOGOP   *B__LOGOP;
typedef LISTOP  *B__LISTOP;
typedef PMOP    *B__PMOP;
typedef SVOP    *B__SVOP;
typedef PADOP   *B__PADOP;
typedef PVOP    *B__PVOP;
typedef LOOP    *B__LOOP;
typedef COP     *B__COP;

typedef SV      *B__SV;
typedef SV      *B__IV;
typedef SV      *B__PV;
typedef SV      *B__NV;
typedef SV      *B__PVMG;
typedef SV      *B__PVLV;
typedef SV      *B__BM;
typedef SV      *B__RV;
typedef AV      *B__AV;
typedef HV      *B__HV;
typedef CV      *B__CV;
typedef GV      *B__GV;
typedef IO      *B__IO;

typedef MAGIC   *B__MAGIC;

#define OP_next(o)	o->op_next
#define OP_sibling(o)	o->op_sibling
#define OP_desc(o)	(char *)PL_op_desc[o->op_type]
#define OP_targ(o)	o->op_targ
#define OP_type(o)	o->op_type
#define OP_opt(o)	o->op_opt
#define OP_flags(o)	o->op_flags
#define OP_private(o)	o->op_private
#define OP_spare(o)	o->op_spare

MODULE = B::OP    PACKAGE = B::OP         PREFIX = OP_

B::CV
OP_find_cv(o)
        B::OP   o
    CODE:
        RETVAL = (CV*)SvRV(find_cv_by_root((OP*)o));
    OUTPUT:
        RETVAL

void
OP_set_next(o, next)
        B::OP           o
        B::OP           next
    CODE:
        o->op_next = next;

void
OP_set_sibling(o, sibling)
        B::OP           o
        B::OP           sibling
    CODE:
        o->op_sibling = sibling;

void
OP_set_ppaddr(o, ppaddr)
        B::OP           o
    CODE:
        o->op_ppaddr = (void*)SvIV(ST(1));

void
OP_set_targ(o, targ)
        B::OP           o
        PADOFFSET             targ
    CODE:
        o->op_targ = targ; /* (PADOFFSET)SvIV(targ); */

void
OP_set_type(o, type)
        B::OP           o
        U16             type
    CODE:
        o->op_type = type;
        o->op_ppaddr = PL_ppaddr[o->op_type];

void
OP_set_flags(o, flags)
        B::OP           o
        U8              flags
    CODE:
        o->op_flags = flags;

void
OP_set_private(o, private)
        B::OP           o
        U8              private
    CODE:
        o->op_private = private;

void
OP_dump(o)
    B::OP o
    CODE:
        op_dump(o);

void
OP_clean(o)
    B::OP o
    CODE:
        if (o == PL_main_root)
            o->op_next = Nullop;

void
OP_free(o)
    B::OP o
    CODE:
        op_free(o);
        sv_setiv(SvRV(ST(0)), 0);

void
OP_new(class, type, flags, location)
    SV * class
    SV * type
    I32 flags
    SV * location
    SV** sparepad = NO_INIT
    OP *o = NO_INIT
    OP *saveop = NO_INIT
    I32 typenum = NO_INIT
    CODE:
        sparepad = PL_curpad;
        saveop = PL_op;
        PL_curpad = AvARRAY(PL_comppad);
        typenum = op_name_to_num(type);
        o = newOP(typenum, flags, newSVsv(location));
#ifdef PERL_CUSTOM_OPS
        if (typenum == OP_CUSTOM)
            o->op_ppaddr = custom_op_ppaddr(SvPV_nolen(type));
#endif
        PL_curpad = sparepad;
        PL_op = saveop;
            ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::OP"), PTR2IV(o));

void
OP_newstate(class, flags, label, oldo, location)
    SV * class
    I32 flags
    char * label
    B::OP oldo
    SV* location
    SV** sparepad = NO_INIT
    OP *o = NO_INIT
    OP *saveop = NO_INIT
    CODE:
        sparepad = PL_curpad;
        saveop = PL_op;
        PL_curpad = AvARRAY(PL_comppad);
        o = newSTATEOP(flags, label, oldo, newSVsv(location));
        PL_curpad = sparepad;
        PL_op = saveop;
            ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::LISTOP"), PTR2IV(o));

B::OP
OP_mutate(o, type)
    B::OP o
    SV* type
    I32 rtype = NO_INIT
    CODE:
        rtype = op_name_to_num(type);
        o->op_ppaddr = PL_ppaddr[rtype];
        o->op_type = rtype;

    OUTPUT:
        o

MODULE = B::OP    PACKAGE = B::UNOP               PREFIX = UNOP_

void
UNOP_set_first(o, first)
        B::UNOP o
        B::OP   first
    CODE:
        o->op_first = first;
    
void
UNOP_new(class, type, flags, sv_first, location)
    SV * class
    SV * type
    I32 flags
    SV * sv_first
    SV * location
    OP *first = NO_INIT
    OP *o = NO_INIT
    I32 typenum = NO_INIT
    CODE:
        if (SvROK(sv_first)) {
            if (!sv_derived_from(sv_first, "B::OP"))
                Perl_croak(aTHX_ "Reference 'first' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_first));
                first = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_first))
            Perl_croak(aTHX_ 
            "'first' argument to B::UNOP->new should be a B::OP object or a false value");
        else
            first = Nullop;
        {
        I32 padflag = 0;
        SV**sparepad = PL_curpad;
        OP* saveop = PL_op; 

        PL_curpad = AvARRAY(PL_comppad);
        typenum = op_name_to_num(type);
        o = newUNOP(typenum, flags, first, newSVsv(location));
#ifdef PERL_CUSTOM_OPS
        if (typenum == OP_CUSTOM)
            o->op_ppaddr = custom_op_ppaddr(SvPV_nolen(type));
#endif
        PL_op = saveop;
        }
            ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::UNOP"), PTR2IV(o));

MODULE = B::OP    PACKAGE = B::BINOP              PREFIX = BINOP_

void
BINOP_null(o)
        B::BINOP        o
        CODE:
                op_null((OP*)o);

void
BINOP_set_last(o, last)
        B::BINOP        o
        B::OP           last
    CODE:
        o->op_last = last;

void
BINOP_new(class, type, flags, sv_first, sv_last, location)
    SV * class
    SV * type
    I32 flags
    SV * sv_first
    SV * sv_last
    SV * location
    OP *first = NO_INIT
    OP *last = NO_INIT
    OP *o = NO_INIT
    CODE:
        if (SvROK(sv_first)) {
            if (!sv_derived_from(sv_first, "B::OP"))
                Perl_croak(aTHX_ "Reference 'first' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_first));
                first = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_first))
            Perl_croak(aTHX_ 
            "'first' argument to B::UNOP->new should be a B::OP object or a false value");
        else
            first = Nullop;

        if (SvROK(sv_last)) {
            if (!sv_derived_from(sv_last, "B::OP"))
                Perl_croak(aTHX_ "Reference 'last' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_last));
                last = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_last))
            Perl_croak(aTHX_ 
            "'last' argument to B::BINOP->new should be a B::OP object or a false value");
        else
            last = Nullop;

        {
        SV**sparepad = PL_curpad;
        OP* saveop = PL_op;
        I32 typenum = op_name_to_num(type);

        PL_curpad = AvARRAY(PL_comppad);
        
        if (typenum == OP_SASSIGN) 
            o = newASSIGNOP(flags, first, 0, last, newSVsv(location));
        else {
            o = newBINOP(typenum, flags, first, last, newSVsv(location));
#ifdef PERL_CUSTOM_OPS
            if (typenum == OP_CUSTOM)
                o->op_ppaddr = custom_op_ppaddr(SvPV_nolen(type));
#endif
        }

        PL_curpad = sparepad;
        PL_op = saveop;
        }
            ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::BINOP"), PTR2IV(o));

MODULE = B::OP    PACKAGE = B::LISTOP             PREFIX = LISTOP_

void
LISTOP_new(class, type, flags, sv_first, sv_last, location)
    SV * class
    SV * type
    I32 flags
    SV * sv_first
    SV * sv_last
    SV * location
    OP *first = NO_INIT
    OP *last = NO_INIT
    OP *o = NO_INIT
    CODE:
        if (SvROK(sv_first)) {
            if (!sv_derived_from(sv_first, "B::OP"))
                Perl_croak(aTHX_ "Reference 'first' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_first));
                first = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_first))
            Perl_croak(aTHX_ 
            "'first' argument to B::UNOP->new should be a B::OP object or a false value");
        else
            first = Nullop;

        if (SvROK(sv_last)) {
            if (!sv_derived_from(sv_last, "B::OP"))
                Perl_croak(aTHX_ "Reference 'last' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_last));
                last = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_last))
            Perl_croak(aTHX_ 
            "'last' argument to B::BINOP->new should be a B::OP object or a false value");
        else
            last = Nullop;

        {
        SV**sparepad = PL_curpad;
        OP* saveop   = PL_op;
        I32 typenum = op_name_to_num(type);

        PL_curpad = AvARRAY(PL_comppad);
        o = newLISTOP(typenum, flags, first, last, newSVsv(location));
#ifdef PERL_CUSTOM_OPS
        if (typenum == OP_CUSTOM)
            o->op_ppaddr = custom_op_ppaddr(SvPV_nolen(type));
#endif
        PL_curpad = sparepad;
        PL_op = saveop;
        }
            ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::LISTOP"), PTR2IV(o));

MODULE = B::OP    PACKAGE = B::LOGOP              PREFIX = LOGOP_

void
LOGOP_new(class, type, flags, sv_first, sv_last, location)
    SV * class
    SV * type
    I32 flags
    SV * sv_first
    SV * sv_last
    SV * location
    OP *first = NO_INIT
    OP *last = NO_INIT
    OP *o = NO_INIT
    CODE:
        if (SvROK(sv_first)) {
            if (!sv_derived_from(sv_first, "B::OP"))
                Perl_croak(aTHX_ "Reference 'first' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_first));
                first = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_first))
            Perl_croak(aTHX_ 
            "'first' argument to B::UNOP->new should be a B::OP object or a false value");
        else
            first = Nullop;

        if (SvROK(sv_last)) {
            if (!sv_derived_from(sv_last, "B::OP"))
                Perl_croak(aTHX_ "Reference 'last' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_last));
                last = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_last))
            Perl_croak(aTHX_ 
            "'last' argument to B::BINOP->new should be a B::OP object or a false value");
        else
            last = Nullop;

        {
        SV**sparepad = PL_curpad;
        OP* saveop   = PL_op;
        I32 typenum  = op_name_to_num(type);
        PL_curpad = AvARRAY(PL_comppad);
        o = newLOGOP(typenum, flags, first, last, newSVsv(location));
#ifdef PERL_CUSTOM_OPS
        if (typenum == OP_CUSTOM)
            o->op_ppaddr = custom_op_ppaddr(SvPV_nolen(type));
#endif
        PL_curpad = sparepad;
        PL_op = saveop;
        }
            ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::LOGOP"), PTR2IV(o));

void
LOGOP_newcond(class, flags, sv_first, sv_last, sv_else, location)
    SV * class
    I32 flags
    SV * sv_first
    SV * sv_last
    SV * sv_else
    SV * location
    OP *first = NO_INIT
    OP *last = NO_INIT
    OP *elseo = NO_INIT
    OP *o = NO_INIT
    CODE:
        if (SvROK(sv_first)) {
            if (!sv_derived_from(sv_first, "B::OP"))
                Perl_croak(aTHX_ "Reference 'first' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_first));
                first = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_first))
            Perl_croak(aTHX_ 
            "'first' argument to B::UNOP->new should be a B::OP object or a false value");
        else
            first = Nullop;

        if (SvROK(sv_last)) {
            if (!sv_derived_from(sv_last, "B::OP"))
                Perl_croak(aTHX_ "Reference 'last' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_last));
                last = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_last))
            Perl_croak(aTHX_ 
            "'last' argument to B::BINOP->new should be a B::OP object or a false value");
        else
            last = Nullop;

        if (SvROK(sv_else)) {
            if (!sv_derived_from(sv_else, "B::OP"))
                Perl_croak(aTHX_ "Reference 'else' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_else));
                elseo = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_else))
            Perl_croak(aTHX_ 
            "'last' argument to B::BINOP->new should be a B::OP object or a false value");
        else
            elseo = Nullop;

        {
        SV**sparepad = PL_curpad;
        OP* saveop   = PL_op;
        PL_curpad = AvARRAY(PL_comppad);
        o = newCONDOP(flags, first, last, elseo, newSVsv(location));
        PL_curpad = sparepad;
        PL_op = saveop;
        }
            ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::LOGOP"), PTR2IV(o));

void
LOGOP_set_other(o, other)
        B::LOGOP        o
        B::OP           other
    CODE:
        o->op_other = other;

MODULE = B::OP    PACKAGE = B::SVOP               PREFIX = SVOP_

void
SVOP_set_sv(o, ...)
        B::SVOP o
    PREINIT:
        SV *sv;
    CODE:
        GEN_PAD;
        if (items > 1) {
            sv = newSVsv(ST(1));
            cSVOPx(o)->op_sv = sv;
        }
        OLD_PAD;

void
SVOP_new(class, type, flags, sv, location)
    SV * class
    SV * type
    I32 flags
    SV * sv
    SV * location
    SV** sparepad = NO_INIT
    OP *o = NO_INIT
    OP *saveop = NO_INIT
    SV* param = NO_INIT
    I32 typenum = NO_INIT
    CODE:
        sparepad = PL_curpad;
        PL_curpad = AvARRAY(PL_comppad);
        saveop = PL_op;
        typenum = op_name_to_num(type); /* XXX More classes here! */
        if (typenum == OP_GVSV) {
            if (*(SvPV_nolen(sv)) == '$') 
                param = (SV*)gv_fetchpv(SvPVX_const(sv)+1, TRUE, SVt_PV);
            else
            Perl_croak(aTHX_ 
            "First character to GVSV was not dollar");
        } else
            param = newSVsv(sv);
        o = newSVOP(typenum, flags, param, newSVsv(location));
#ifdef PERL_CUSTOM_OPS
        if (typenum == OP_CUSTOM)
            o->op_ppaddr = custom_op_ppaddr(SvPV_nolen(type));
#endif
            //PL_curpad = sparepad;
            ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::SVOP"), PTR2IV(o));
        PL_op = saveop;

MODULE = B::OP    PACKAGE = B::PADOP              PREFIX = PADOP_

void
PADOP_set_padix(o, ...)
        B::PADOP o
    CODE:
        if (items > 1)
            o->op_padix = (PADOFFSET)SvIV(ST(1));

MODULE = B::OP    PACKAGE = B::LOOP               PREFIX = LOOP_

void
LOOP_set_redoop(o, redoop)
        B::LOOP o
        B::OP   redoop
    CODE:
        o->op_redoop = redoop;

void
LOOP_set_nextop(o, nextop)
        B::LOOP o
        B::OP   nextop
    CODE:
        o->op_nextop = nextop;

void
LOOP_set_lastop(o, lastop)
        B::LOOP o
        B::OP   lastop
    CODE:
        o->op_lastop = lastop;

MODULE = B::OP    PACKAGE = B::COP                PREFIX = COP_

B::COP
COP_new(class, flags, name, sv_first, location)
    SV * class
    char * name
    I32 flags
    SV * sv_first
    SV * location
    OP *first = NO_INIT
    OP *o = NO_INIT
    CODE:
        if (SvROK(sv_first)) {
            if (!sv_derived_from(sv_first, "B::OP"))
                Perl_croak(aTHX_ "Reference 'first' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_first));
                first = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_first))
            Perl_croak(aTHX_ 
            "'first' argument to B::COP->new should be a B::OP object or a false value");
        else
            first = Nullop;

        {
        SV**sparepad = PL_curpad;
        OP* saveop = PL_op;
        PL_curpad = AvARRAY(PL_comppad);
        o = newSTATEOP(flags, name, first, newSVsv(location));
        PL_curpad = sparepad;
        PL_op = saveop;
        }
            ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::COP"), PTR2IV(o));

MODULE = B::OP  PACKAGE = B::SV  PREFIX = Sv

SV*
Svsv(sv)
    B::SV   sv
    CODE:
        RETVAL = newSVsv(sv);
    OUTPUT:
        RETVAL

void*
Svdump(sv)
    B::SV   sv
    CODE:
        sv_dump(sv);

U32
SvFLAGS(sv, ...)
    B::SV   sv
    CODE:
        if (items > 1)
            sv->sv_flags = SvIV(ST(1));
        RETVAL = SvFLAGS(sv);
    OUTPUT:
        RETVAL

MODULE = B::OP    PACKAGE = B::PV         PREFIX = Sv

void
SvPV(sv,...)
        B::PV   sv
    CODE:
{
  if(items > 1) {
    sv_setpv(sv, SvPV_nolen(ST(1)));    
  } 
  ST(0) = sv_newmortal();
  if( SvPOK(sv) ) { 
    sv_setpvn(ST(0), SvPVX_const(sv), SvCUR(sv));
  }
  else {
    /* XXX for backward compatibility, but should fail */
    /* croak( "argument is not SvPOK" ); */
    sv_setpvn(ST(0), NULL, 0);
  }
}

MODULE = B::OP	PACKAGE = B::OP		PREFIX = OP_
size_t
OP_size(o)
	B::OP		o
    CODE:
	RETVAL = opsizes[cc_opclass(aTHX_ o)];
    OUTPUT:
	RETVAL

B::OP
OP_next(o)
	B::OP		o

B::OP
OP_sibling(o)
	B::OP		o

char *
OP_name(o)
	B::OP		o
    CODE:
	RETVAL = (char *)PL_op_name[o->op_type];
    OUTPUT:
	RETVAL


void
OP_ppaddr(o)
	B::OP		o
    PREINIT:
	int i;
	SV *sv = sv_newmortal();
    CODE:
	sv_setpvn(sv, "PL_ppaddr[OP_", 13);
	sv_catpv(sv, PL_op_name[o->op_type]);
	for (i=13; (STRLEN)i < SvCUR(sv); ++i)
	    SvPVX_mutable(sv)[i] = toUPPER(SvPVX_const(sv)[i]);
	sv_catpv(sv, "]");
	ST(0) = sv;

char *
OP_desc(o)
	B::OP		o

PADOFFSET
OP_targ(o)
	B::OP		o

U16
OP_type(o)
	B::OP		o

U8
OP_opt(o)
	B::OP		o

U8
OP_flags(o)
	B::OP		o

U8
OP_private(o)
	B::OP		o

U8
OP_spare(o)
	B::OP		o

SV*
OP_location(o)
        B::OP           o
    CODE:
        RETVAL = SvREFCNT_inc(o->op_location ? o->op_location : &PL_sv_undef);
    OUTPUT:
        RETVAL

void
OP_oplist(o)
	B::OP		o
    PPCODE:
	SP = oplist(aTHX_ o, SP);

#define UNOP_first(o)	o->op_first

MODULE = B::OP	PACKAGE = B::UNOP		PREFIX = UNOP_

B::OP 
UNOP_first(o)
	B::UNOP	o

#define BINOP_last(o)	o->op_last

MODULE = B::OP	PACKAGE = B::BINOP		PREFIX = BINOP_

B::OP
BINOP_last(o)
	B::BINOP	o

#define LOGOP_other(o)	o->op_other

MODULE = B::OP	PACKAGE = B::LOGOP		PREFIX = LOGOP_

B::OP
LOGOP_other(o)
	B::LOGOP	o

MODULE = B::OP	PACKAGE = B::LISTOP		PREFIX = LISTOP_

U32
LISTOP_children(o)
	B::LISTOP	o
	OP *		kid = NO_INIT
	int		i = NO_INIT
    CODE:
	i = 0;
	for (kid = o->op_first; kid; kid = kid->op_sibling)
	    i++;
	RETVAL = i;
    OUTPUT:
        RETVAL

#if PERL_VERSION >= 9
#  define PMOP_pmreplstart(o)	o->op_pmstashstartu.op_pmreplstart
#else
#  define PMOP_pmreplstart(o)	o->op_pmreplstart
#  define PMOP_pmpermflags(o)	o->op_pmpermflags
#  define PMOP_pmdynflags(o)      o->op_pmdynflags
#endif
#define PMOP_pmnext(o)		o->op_pmnext
#define PMOP_pmflags(o)		o->op_pmflags

MODULE = B::OP	PACKAGE = B::PMOP		PREFIX = PMOP_

void
PMOP_pmreplroot(o)
	B::PMOP		o
    CODE:
	ST(0) = sv_newmortal();
	if (o->op_type == OP_PUSHRE) {
	    GV *const target = o->op_pmreplrootu.op_pmtargetgv;
	    sv_setiv(newSVrv(ST(0), target ?
			     svclassnames[SvTYPE((SV*)target)] : "B::SV"),
		     PTR2IV(target));
	}
	else {
	    OP *const root = o->op_pmreplrootu.op_pmreplroot; 
	    sv_setiv(newSVrv(ST(0), cc_opclassname(aTHX_ root)),
		     PTR2IV(root));
	}

B::OP
PMOP_pmreplstart(o)
	B::PMOP		o

U32
PMOP_pmflags(o)
	B::PMOP		o

#if PERL_VERSION < 9

U32
PMOP_pmpermflags(o)
	B::PMOP		o

U8
PMOP_pmdynflags(o)
        B::PMOP         o

#endif

void
PMOP_precomp(o)
	B::PMOP		o
	REGEXP *	rx = NO_INIT
    CODE:
	ST(0) = sv_newmortal();
	rx = PM_GETRE(o);
	if (rx)
	    sv_setpvn(ST(0), RX_PRECOMP(rx), RX_PRELEN(rx));

#if PERL_VERSION >= 9

void
PMOP_reflags(o)
	B::PMOP		o
	REGEXP *	rx = NO_INIT
    CODE:
	ST(0) = sv_newmortal();
	rx = PM_GETRE(o);
	if (rx)
	    sv_setuv(ST(0), RX_EXTFLAGS(rx));

#endif

#define SVOP_sv(o)     cSVOPo->op_sv
#define SVOP_gv(o)     ((GV*)cSVOPo->op_sv)

MODULE = B::OP	PACKAGE = B::SVOP		PREFIX = SVOP_

B::SV
SVOP_sv(o)
	B::SVOP	o

B::GV
SVOP_gv(o)
	B::SVOP	o

#define PADOP_padix(o)	o->op_padix
#define PADOP_sv(o)	(o->op_padix ? PAD_SVl(o->op_padix) : Nullsv)
#define PADOP_gv(o)	((o->op_padix \
			  && SvTYPE(PAD_SVl(o->op_padix)) == SVt_PVGV) \
			 ? (GV*)PAD_SVl(o->op_padix) : Nullgv)

MODULE = B::OP	PACKAGE = B::PADOP		PREFIX = PADOP_

PADOFFSET
PADOP_padix(o)
	B::PADOP o

B::SV
PADOP_sv(o)
	B::PADOP o

B::GV
PADOP_gv(o)
	B::PADOP o

MODULE = B::OP	PACKAGE = B::PVOP		PREFIX = PVOP_

void
PVOP_pv(o)
	B::PVOP	o
    CODE:
        ST(0) = sv_2mortal(newSVpv(o->op_pv, 0));

#define LOOP_redoop(o)	o->op_redoop
#define LOOP_nextop(o)	o->op_nextop
#define LOOP_lastop(o)	o->op_lastop

MODULE = B::OP	PACKAGE = B::LOOP		PREFIX = LOOP_


B::OP
LOOP_redoop(o)
	B::LOOP	o

B::OP
LOOP_nextop(o)
	B::LOOP	o

B::OP
LOOP_lastop(o)
	B::LOOP	o

#define COP_label(o)	o->cop_label
#define COP_stashpv(o)	CopSTASHPV(o)
#define COP_stash(o)	CopSTASH(o)
#define COP_cop_seq(o)	o->cop_seq
#define COP_hints(o)	CopHINTS_get(o)
#if PERL_VERSION < 9
#  define COP_warnings(o)  o->cop_warnings
#  define COP_io(o)	o->cop_io
#endif

MODULE = B::OP	PACKAGE = B::COP		PREFIX = COP_

char *
COP_label(o)
	B::COP	o

char *
COP_stashpv(o)
	B::COP	o

B::HV
COP_stash(o)
	B::COP	o

U32
COP_cop_seq(o)
	B::COP	o

#define COP_hints_hash(o) o->cop_hints_hash

HV*
COP_hints_hash(o)
	B::COP	o

void
COP_warnings(o)
	B::COP	o
	PPCODE:
	ST(0) = make_warnings_object(aTHX_ sv_newmortal(), o->cop_warnings);
	XSRETURN(1);

void
COP_io(o)
	B::COP	o
	PPCODE:
	ST(0) = make_cop_io_object(aTHX_ sv_newmortal(), o);
	XSRETURN(1);

U32
COP_hints(o)
	B::COP	o

MODULE = B::OP	PACKAGE = B::CV		PREFIX = Cv

B::OP
CvSTART(cv)
	B::CV	cv
    CODE:
	RETVAL = CvISXSUB(cv) ? NULL : CvSTART(cv);
    OUTPUT:
	RETVAL

B::OP
CvROOT(cv)
	B::CV	cv
    CODE:
	RETVAL = CvISXSUB(cv) ? NULL : CvROOT(cv);
    OUTPUT:
	RETVAL

B::CV
Cvnewsub_simple(class, name, block)
    SV* class
    SV* name
    B::OP block
    CV* mycv  = NO_INIT
    OP* o = NO_INIT

    CODE:
        o = newSVOP(OP_CONST, 0, name, NULL);
        mycv = newNAMEDSUB(start_subparse(0), o, Nullop, block);
        /*op_free(o); */
        RETVAL = mycv;
    OUTPUT:
        RETVAL


MODULE = B::OP    PACKAGE = B     PREFIX = B_

void
B_walkoptree(opsv, method)
	SV *	opsv
	const char *	method
    CODE:
	walkoptree(aTHX_ opsv, method);

int
B_walkoptree_debug(...)
    CODE:
	RETVAL = walkoptree_debug;
	if (items > 0 && SvTRUE(ST(1)))
	    walkoptree_debug = 1;
    OUTPUT:
	RETVAL

#define B_main_root()	PL_main_root
#define B_main_start()	PL_main_start

B::OP
B_main_root()

B::OP
B_main_start()

void
B_fudge()
    CODE:
        SSCHECK(2);
        SSPUSHPTR((SV*)PL_comppad);  
        SSPUSHINT(SAVEt_COMPPAD);

B::OP
B_set_main_root(...)
    PROTOTYPE: ;$
    CODE:
        if (items > 0)
            PL_main_root = SVtoO(ST(0));
        RETVAL = PL_main_root;
    OUTPUT:
        RETVAL
    
B::OP
B_set_main_start(...)
    PROTOTYPE: ;$
    CODE:
        if (items > 0)
            PL_main_start = SVtoO(ST(0));
        RETVAL = PL_main_start;
    OUTPUT:
        RETVAL


MODULE = B::PAD    PACKAGE = B::PAD     PREFIX = B_PAD_

int
B_PAD_allocmy(char* name)
    CODE:
        SV **old_curpad           = PL_curpad;
        AV *old_comppad           = PL_comppad;

        PL_comppad =           *(AV**) av_fetch(CvPADLIST(PL_compcv), 1, 0);
        PL_curpad            = AvARRAY(PL_comppad);
        
        RETVAL = Perl_pad_add_name(aTHX_ name, NULL, FALSE);

        PL_comppad = old_comppad;
        PL_curpad  = old_curpad;
    OUTPUT:
        RETVAL

MODULE = B::OP    PACKAGE = B::OP     PREFIX = B_

BOOT:
    specialsv_list[0] = Nullsv;
    specialsv_list[1] = &PL_sv_undef;
    specialsv_list[2] = &PL_sv_yes;
    specialsv_list[3] = &PL_sv_no;
    specialsv_list[4] = (SV*) pWARN_ALL;
    specialsv_list[5] = (SV*) pWARN_NONE;
    specialsv_list[6] = (SV*) pWARN_STD;


