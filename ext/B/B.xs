/*	B.xs
 *
 *	Copyright (c) 1996 Malcolm Beattie
 *
 *	You may distribute under the terms of either the GNU General Public
 *	License or the Artistic License, as specified in the README file.
 *
 */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef PerlIO
typedef PerlIO * InputStream;
#else
typedef FILE * InputStream;
#endif


static const char* const svclassnames[] = {
    "B::NULL",
    "B::BIND",
    "B::IV",
    "B::NV",
    "B::RV",
    "B::PV",
    "B::PVIV",
    "B::PVNV",
    "B::PVMG",
    "B::GV",
    "B::PVLV",
    "B::AV",
    "B::HV",
    "B::CV",
    "B::IO",
};

#define MY_CXT_KEY "B::_guts" XS_VERSION

typedef struct {
    int		x_walkoptree_debug;	/* Flag for walkoptree debug hook */
    SV *	x_specialsv_list[7];
} my_cxt_t;

START_MY_CXT

#define walkoptree_debug	(MY_CXT.x_walkoptree_debug)
#define specialsv_list		(MY_CXT.x_specialsv_list)

static SV *
make_sv_object(pTHX_ SV *arg, SV *sv)
{
    const char *type = 0;
    IV iv;
    dMY_CXT;
    
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

#if PERL_VERSION >= 9
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
    sv_magicext(target, temp, PERL_MAGIC_sv, NULL, NULL, 0);
    /* magic object has had its reference count increased, so we must drop
       our reference.  */
    SvREFCNT_dec(temp);
    return arg;
}

#endif

static SV *
make_mg_object(pTHX_ SV *arg, MAGIC *mg)
{
    sv_setiv(newSVrv(arg, "B::MAGIC"), PTR2IV(mg));
    return arg;
}

static SV *
cstring(pTHX_ SV *sv, bool perlstyle)
{
    SV *sstr = newSVpvn("", 0);

    if (!SvOK(sv))
	sv_setpvn(sstr, "0", 1);
    else if (perlstyle) {
	SV *tmpsv = sv_newmortal(); /* Temporary SV to feed sv_uni_display */
	const STRLEN len = SvCUR(sv);
	const char *s = sv_uni_display(tmpsv, sv, 8*len, UNI_DISPLAY_QQ);
	sv_setpvn(sstr,"\"",1);
	while (*s)
	{
	    if (*s == '"')
		sv_catpvn(sstr, "\\\"", 2);
	    else if (*s == '$')
		sv_catpvn(sstr, "\\$", 2);
	    else if (*s == '@')
		sv_catpvn(sstr, "\\@", 2);
	    else if (*s == '\\')
	    {
		if (strchr("nrftax\\",*(s+1)))
		    sv_catpvn(sstr, s++, 2);
		else
		    sv_catpvn(sstr, "\\\\", 2);
	    }
	    else /* should always be printable */
		sv_catpvn(sstr, s, 1);
	    ++s;
	}
	sv_catpv(sstr, "\"");
	return sstr;
    }
    else
    {
	/* XXX Optimise? */
	STRLEN len;
	const char *s = SvPV(sv, len);
	sv_catpv(sstr, "\"");
	for (; len; len--, s++)
	{
	    /* At least try a little for readability */
	    if (*s == '"')
		sv_catpv(sstr, "\\\"");
	    else if (*s == '\\')
		sv_catpv(sstr, "\\\\");
            /* trigraphs - bleagh */
            else if (!perlstyle && *s == '?' && len>=3 && s[1] == '?') {
		char escbuff[5]; /* to fit backslash, 3 octals + trailing \0 */
                sprintf(escbuff, "\\%03o", '?');
                sv_catpv(sstr, escbuff);
            }
	    else if (perlstyle && *s == '$')
		sv_catpv(sstr, "\\$");
	    else if (perlstyle && *s == '@')
		sv_catpv(sstr, "\\@");
#ifdef EBCDIC
	    else if (isPRINT(*s))
#else
	    else if (*s >= ' ' && *s < 127)
#endif /* EBCDIC */
		sv_catpvn(sstr, s, 1);
	    else if (*s == '\n')
		sv_catpv(sstr, "\\n");
	    else if (*s == '\r')
		sv_catpv(sstr, "\\r");
	    else if (*s == '\t')
		sv_catpv(sstr, "\\t");
	    else if (*s == '\a')
		sv_catpv(sstr, "\\a");
	    else if (*s == '\b')
		sv_catpv(sstr, "\\b");
	    else if (*s == '\f')
		sv_catpv(sstr, "\\f");
	    else if (!perlstyle && *s == '\v')
		sv_catpv(sstr, "\\v");
	    else
	    {
		/* Don't want promotion of a signed -1 char in sprintf args */
		char escbuff[5]; /* to fit backslash, 3 octals + trailing \0 */
		const unsigned char c = (unsigned char) *s;
		sprintf(escbuff, "\\%03o", c);
		sv_catpv(sstr, escbuff);
	    }
	    /* XXX Add line breaks if string is long */
	}
	sv_catpv(sstr, "\"");
    }
    return sstr;
}

static SV *
cchar(pTHX_ SV *sv)
{
    SV *sstr = newSVpvn("'", 1);
    const char *s = SvPV_nolen(sv);

    if (*s == '\'')
	sv_catpvn(sstr, "\\'", 2);
    else if (*s == '\\')
	sv_catpvn(sstr, "\\\\", 2);
#ifdef EBCDIC
    else if (isPRINT(*s))
#else
    else if (*s >= ' ' && *s < 127)
#endif /* EBCDIC */
	sv_catpvn(sstr, s, 1);
    else if (*s == '\n')
	sv_catpvn(sstr, "\\n", 2);
    else if (*s == '\r')
	sv_catpvn(sstr, "\\r", 2);
    else if (*s == '\t')
	sv_catpvn(sstr, "\\t", 2);
    else if (*s == '\a')
	sv_catpvn(sstr, "\\a", 2);
    else if (*s == '\b')
	sv_catpvn(sstr, "\\b", 2);
    else if (*s == '\f')
	sv_catpvn(sstr, "\\f", 2);
    else if (*s == '\v')
	sv_catpvn(sstr, "\\v", 2);
    else
    {
	/* no trigraph support */
	char escbuff[5]; /* to fit backslash, 3 octals + trailing \0 */
	/* Don't want promotion of a signed -1 char in sprintf args */
	unsigned char c = (unsigned char) *s;
	sprintf(escbuff, "\\%03o", c);
	sv_catpv(sstr, escbuff);
    }
    sv_catpvn(sstr, "'", 1);
    return sstr;
}

typedef SV	*B__SV;
typedef SV	*B__IV;
typedef SV	*B__PV;
typedef SV	*B__NV;
typedef SV	*B__PVMG;
typedef SV	*B__PVLV;
typedef SV	*B__BM;
typedef SV	*B__RV;
typedef SV	*B__FM;
typedef AV	*B__AV;
typedef HV	*B__HV;
typedef CV	*B__CV;
typedef GV	*B__GV;
typedef IO	*B__IO;

typedef MAGIC	*B__MAGIC;
typedef HE      *B__HE;

MODULE = B	PACKAGE = B	PREFIX = B_

PROTOTYPES: DISABLE

BOOT:
{
    HV *stash = gv_stashpvn("B", 1, GV_ADD);
    AV *export_ok = perl_get_av("B::EXPORT_OK",TRUE);
    MY_CXT_INIT;
    specialsv_list[0] = Nullsv;
    specialsv_list[1] = &PL_sv_undef;
    specialsv_list[2] = &PL_sv_yes;
    specialsv_list[3] = &PL_sv_no;
    specialsv_list[4] = (SV *) pWARN_ALL;
    specialsv_list[5] = (SV *) pWARN_NONE;
    specialsv_list[6] = (SV *) pWARN_STD;
#if PERL_VERSION <= 8
#  define OPpPAD_STATE 0
#endif
#include "defsubs.h"
}

#define B_main_cv()	PL_main_cv
#define B_init_av()	PL_initav
#define B_inc_gv()	PL_incgv
#define B_check_av()	PL_checkav_save
#if PERL_VERSION > 8
#  define B_unitcheck_av()	PL_unitcheckav_save
#else
#  define B_unitcheck_av()	NULL
#endif
#define B_begin_av()	PL_beginav_save
#define B_end_av()	PL_endav
#define B_amagic_generation()	PL_amagic_generation
#define B_sub_generation()	PL_sub_generation
#define B_defstash()	PL_defstash
#define B_curstash()	PL_curstash
#define B_dowarn()	PL_dowarn
#define B_comppadlist()	(PL_main_cv ? CvPADLIST(PL_main_cv) : CvPADLIST(PL_compcv))
#define B_sv_undef()	&PL_sv_undef
#define B_sv_yes()	&PL_sv_yes
#define B_sv_no()	&PL_sv_no
#define B_formfeed()	PL_formfeed
#ifdef USE_ITHREADS
#define B_regex_padav()	PL_regex_padav
#endif

B::AV
B_init_av()

B::AV
B_check_av()

#if PERL_VERSION >= 9

B::AV
B_unitcheck_av()

#endif

B::AV
B_begin_av()

B::AV
B_end_av()

B::GV
B_inc_gv()

#ifdef USE_ITHREADS

B::AV
B_regex_padav()

#endif

B::CV
B_main_cv()

long 
B_amagic_generation()

long
B_sub_generation()

B::AV
B_comppadlist()

B::SV
B_sv_undef()

B::SV
B_sv_yes()

B::SV
B_sv_no()

B::HV
B_curstash()

B::HV
B_defstash()

U8
B_dowarn()

B::SV
B_formfeed()

void
B_warnhook()
    CODE:
	ST(0) = make_sv_object(aTHX_ sv_newmortal(), PL_warnhook);

void
B_diehook()
    CODE:
	ST(0) = make_sv_object(aTHX_ sv_newmortal(), PL_diehook);

MODULE = B	PACKAGE = B

#define address(sv) PTR2IV(sv)

IV
address(sv)
	SV *	sv

B::SV
svref_2object(sv)
	SV *	sv
    CODE:
	if (!SvROK(sv))
	    croak("argument is not a reference");
	RETVAL = (SV*)SvRV(sv);
    OUTPUT:
	RETVAL              

void
opnumber(name)
const char *	name
CODE:
{
 int i; 
 IV  result = -1;
 ST(0) = sv_newmortal();
 if (strncmp(name,"pp_",3) == 0)
   name += 3;
 for (i = 0; i < PL_maxo; i++)
  {
   if (strcmp(name, PL_op_name[i]) == 0)
    {
     result = i;
     break;
    }
  }
 sv_setiv(ST(0),result);
}

void
ppname(opnum)
	int	opnum
    CODE:
	ST(0) = sv_newmortal();
	if (opnum >= 0 && opnum < PL_maxo) {
	    sv_setpvn(ST(0), "pp_", 3);
	    sv_catpv(ST(0), PL_op_name[opnum]);
	}

void
hash(sv)
	SV *	sv
    CODE:
	STRLEN len;
	U32 hash = 0;
	char hexhash[19]; /* must fit "0xffffffffffffffff" plus trailing \0 */
	const char *s = SvPV(sv, len);
	PERL_HASH(hash, s, len);
	sprintf(hexhash, "0x%"UVxf, (UV)hash);
	ST(0) = sv_2mortal(newSVpv(hexhash, 0));

#define cast_I32(foo) (I32)foo
IV
cast_I32(i)
	IV	i

void
minus_c()
    CODE:
	PL_minus_c = TRUE;

void
save_BEGINs()
    CODE:
	PL_savebegin = TRUE;

SV *
cstring(sv)
	SV *	sv
    CODE:
	RETVAL = cstring(aTHX_ sv, 0);
    OUTPUT:
	RETVAL

SV *
perlstring(sv)
	SV *	sv
    CODE:
	RETVAL = cstring(aTHX_ sv, 1);
    OUTPUT:
	RETVAL

SV *
cchar(sv)
	SV *	sv
    CODE:
	RETVAL = cchar(aTHX_ sv);
    OUTPUT:
	RETVAL

void
threadsv_names()
    PPCODE:
#if PERL_VERSION <= 8
# ifdef USE_5005THREADS
	int i;
	const STRLEN len = strlen(PL_threadsv_names);

	EXTEND(sp, len);
	for (i = 0; i < len; i++)
	    PUSHs(sv_2mortal(newSVpvn(&PL_threadsv_names[i], 1)));
# endif
#endif

MODULE = B	PACKAGE = B::SV

U32
SvTYPE(sv)
	B::SV	sv

#define object_2svref(sv)	sv
#define SVREF SV *
	
SVREF
object_2svref(sv)
	B::SV	sv

MODULE = B	PACKAGE = B::SV		PREFIX = Sv

U32
SvREFCNT(sv)
	B::SV	sv

U32
SvFLAGS(sv)
	B::SV	sv

U32
SvPOK(sv)
	B::SV	sv

U32
SvROK(sv)
	B::SV	sv

U32
SvMAGICAL(sv)
	B::SV	sv

MODULE = B	PACKAGE = B::IV		PREFIX = Sv

IV
SvIV(sv)
	B::IV	sv

IV
SvIVX(sv)
	B::IV	sv

UV 
SvUVX(sv) 
	B::IV   sv
                      

MODULE = B	PACKAGE = B::IV

#define needs64bits(sv) ((I32)SvIVX(sv) != SvIVX(sv))

int
needs64bits(sv)
	B::IV	sv

void
packiv(sv)
	B::IV	sv
    CODE:
	if (sizeof(IV) == 8) {
	    U32 wp[2];
	    const IV iv = SvIVX(sv);
	    /*
	     * The following way of spelling 32 is to stop compilers on
	     * 32-bit architectures from moaning about the shift count
	     * being >= the width of the type. Such architectures don't
	     * reach this code anyway (unless sizeof(IV) > 8 but then
	     * everything else breaks too so I'm not fussed at the moment).
	     */
#ifdef UV_IS_QUAD
	    wp[0] = htonl(((UV)iv) >> (sizeof(UV)*4));
#else
	    wp[0] = htonl(((U32)iv) >> (sizeof(UV)*4));
#endif
	    wp[1] = htonl(iv & 0xffffffff);
	    ST(0) = sv_2mortal(newSVpvn((char *)wp, 8));
	} else {
	    U32 w = htonl((U32)SvIVX(sv));
	    ST(0) = sv_2mortal(newSVpvn((char *)&w, 4));
	}

MODULE = B	PACKAGE = B::NV		PREFIX = Sv

NV
SvNV(sv)
	B::NV	sv

NV
SvNVX(sv)
	B::NV	sv

U32
COP_SEQ_RANGE_LOW(sv)
	B::NV	sv

U32
COP_SEQ_RANGE_HIGH(sv)
	B::NV	sv

U32
PARENT_PAD_INDEX(sv)
	B::NV	sv

U32
PARENT_FAKELEX_FLAGS(sv)
	B::NV	sv

MODULE = B	PACKAGE = B::RV		PREFIX = Sv

B::SV
SvRV(sv)
	B::RV	sv

MODULE = B	PACKAGE = B::PV		PREFIX = Sv

char*
SvPVX(sv)
	B::PV	sv

B::SV
SvRV(sv)
        B::PV   sv
    CODE:
        if( SvROK(sv) ) {
            RETVAL = SvRV(sv);
        }
        else {
            croak( "argument is not SvROK" );
        }
    OUTPUT:
        RETVAL

void
SvPV(sv)
	B::PV	sv
    CODE:
        ST(0) = sv_newmortal();
        if( SvPOK(sv) ) {
	    /* FIXME - we need a better way for B to identify PVs that are
	       in the pads as variable names.  */
	    if((SvLEN(sv) && SvCUR(sv) >= SvLEN(sv))) {
		/* It claims to be longer than the space allocated for it -
		   presuambly it's a variable name in the pad  */
		sv_setpv(ST(0), SvPV_nolen_const(sv));
	    } else {
		sv_setpvn(ST(0), SvPVX_const(sv), SvCUR(sv));
	    }
        }
        else {
            /* XXX for backward compatibility, but should fail */
            /* croak( "argument is not SvPOK" ); */
            sv_setpvn(ST(0), NULL, 0);
        }

# This used to read 257. I think that that was buggy - should have been 258.
# (The "\0", the flags byte, and 256 for the table.  Not that anything
# anywhere calls this method.  NWC.
void
SvPVBM(sv)
	B::PV	sv
    CODE:
        ST(0) = sv_newmortal();
	sv_setpvn(ST(0), SvPVX_const(sv),
	    SvCUR(sv) + (SvVALID(sv) ? 256 + PERL_FBM_TABLE_OFFSET : 0));


STRLEN
SvLEN(sv)
	B::PV	sv

STRLEN
SvCUR(sv)
	B::PV	sv

MODULE = B	PACKAGE = B::PVMG	PREFIX = Sv

void
SvMAGIC(sv)
	B::PVMG	sv
	MAGIC *	mg = NO_INIT
    PPCODE:
	for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic)
	    XPUSHs(make_mg_object(aTHX_ sv_newmortal(), mg));

MODULE = B	PACKAGE = B::PVMG

B::HV
SvSTASH(sv)
	B::PVMG	sv

#define MgMOREMAGIC(mg) mg->mg_moremagic
#define MgPRIVATE(mg) mg->mg_private
#define MgTYPE(mg) mg->mg_type
#define MgFLAGS(mg) mg->mg_flags
#define MgOBJ(mg) mg->mg_obj
#define MgLENGTH(mg) mg->mg_len
#define MgREGEX(mg) PTR2IV(mg->mg_obj)

MODULE = B	PACKAGE = B::MAGIC	PREFIX = Mg	

B::MAGIC
MgMOREMAGIC(mg)
	B::MAGIC	mg
     CODE:
	if( MgMOREMAGIC(mg) ) {
	    RETVAL = MgMOREMAGIC(mg);
	}
	else {
	    XSRETURN_UNDEF;
	}
     OUTPUT:
	RETVAL

U16
MgPRIVATE(mg)
	B::MAGIC	mg

char
MgTYPE(mg)
	B::MAGIC	mg

U8
MgFLAGS(mg)
	B::MAGIC	mg

B::SV
MgOBJ(mg)
	B::MAGIC	mg

IV
MgREGEX(mg)
	B::MAGIC	mg
    CODE:
        if(mg->mg_type == PERL_MAGIC_qr) {
            RETVAL = MgREGEX(mg);
        }
        else {
            croak( "REGEX is only meaningful on r-magic" );
        }
    OUTPUT:
        RETVAL

SV*
precomp(mg)
        B::MAGIC        mg
    CODE:
        if (mg->mg_type == PERL_MAGIC_qr) {
            REGEXP* rx = (REGEXP*)mg->mg_obj;
            RETVAL = Nullsv;
            if( rx )
                RETVAL = newSVpvn( rx->precomp, rx->prelen );
        }
        else {
            croak( "precomp is only meaningful on r-magic" );
        }
    OUTPUT:
        RETVAL

I32 
MgLENGTH(mg)
	B::MAGIC	mg
 
void
MgPTR(mg)
	B::MAGIC	mg
    CODE:
	ST(0) = sv_newmortal();
 	if (mg->mg_ptr){
		if (mg->mg_len >= 0){
	    		sv_setpvn(ST(0), mg->mg_ptr, mg->mg_len);
		} else if (mg->mg_len == HEf_SVKEY) {
			ST(0) = make_sv_object(aTHX_
				    sv_newmortal(), (SV*)mg->mg_ptr);
		}
	}

MODULE = B	PACKAGE = B::PVLV	PREFIX = Lv

U32
LvTARGOFF(sv)
	B::PVLV	sv

U32
LvTARGLEN(sv)
	B::PVLV	sv

char
LvTYPE(sv)
	B::PVLV	sv

B::SV
LvTARG(sv)
	B::PVLV sv

MODULE = B	PACKAGE = B::BM		PREFIX = Bm

I32
BmUSEFUL(sv)
	B::BM	sv

U32
BmPREVIOUS(sv)
	B::BM	sv

U8
BmRARE(sv)
	B::BM	sv

void
BmTABLE(sv)
	B::BM	sv
	STRLEN	len = NO_INIT
	char *	str = NO_INIT
    CODE:
	str = SvPV(sv, len);
	/* Boyer-Moore table is just after string and its safety-margin \0 */
	ST(0) = sv_2mortal(newSVpvn(str + len + PERL_FBM_TABLE_OFFSET, 256));

MODULE = B	PACKAGE = B::GV		PREFIX = Gv

void
GvNAME(gv)
	B::GV	gv
    CODE:
	ST(0) = sv_2mortal(newSVpvn(GvNAME(gv), GvNAMELEN(gv)));

bool
is_empty(gv)
        B::GV   gv
    CODE:
        RETVAL = GvGP(gv) == Null(GP*);
    OUTPUT:
        RETVAL

void*
GvGP(gv)
	B::GV	gv

B::HV
GvSTASH(gv)
	B::GV	gv

B::SV
GvSV(gv)
	B::GV	gv

B::IO
GvIO(gv)
	B::GV	gv

B::AV
GvAV(gv)
	B::GV	gv

B::HV
GvHV(gv)
	B::GV	gv

B::GV
GvEGV(gv)
	B::GV	gv

B::CV
GvCV(gv)
	B::GV	gv

U32
GvCVGEN(gv)
	B::GV	gv

U32
GvLINE(gv)
	B::GV	gv

char *
GvFILE(gv)
	B::GV	gv

B::GV
GvFILEGV(gv)
	B::GV	gv

MODULE = B	PACKAGE = B::GV

U32
GvREFCNT(gv)
	B::GV	gv

U8
GvFLAGS(gv)
	B::GV	gv

MODULE = B	PACKAGE = B::IO		PREFIX = Io

long
IoLINES(io)
	B::IO	io

short
IoSUBPROCESS(io)
	B::IO	io

bool
IsSTD(io,name)
	B::IO	io
	const char*	name
    PREINIT:
	PerlIO* handle = 0;
    CODE:
	if( strEQ( name, "stdin" ) ) {
	    handle = PerlIO_stdin();
	}
	else if( strEQ( name, "stdout" ) ) {
	    handle = PerlIO_stdout();
	}
	else if( strEQ( name, "stderr" ) ) {
	    handle = PerlIO_stderr();
	}
	else {
	    croak( "Invalid value '%s'", name );
	}
	RETVAL = handle == IoIFP(io);
    OUTPUT:
	RETVAL

MODULE = B	PACKAGE = B::IO

char
IoTYPE(io)
	B::IO	io

U8
IoFLAGS(io)
	B::IO	io

MODULE = B	PACKAGE = B::AV		PREFIX = Av

SSize_t
AvFILL(av)
	B::AV	av

SSize_t
AvMAX(av)
	B::AV	av

#if PERL_VERSION < 9
			   

#define AvOFF(av) ((XPVAV*)SvANY(av))->xof_off

IV
AvOFF(av)
	B::AV	av

#endif

void
AvARRAY(av)
	B::AV	av
    PPCODE:
	if (AvFILL(av) >= 0) {
	    SV **svp = AvARRAY(av);
	    I32 i;
	    for (i = 0; i <= AvFILL(av); i++)
		XPUSHs(make_sv_object(aTHX_ sv_newmortal(), svp[i]));
	}

void
AvARRAYelt(av, idx)
	B::AV	av
	int	idx
    PPCODE:
    	if (idx >= 0 && AvFILL(av) >= 0 && idx <= AvFILL(av))
	    XPUSHs(make_sv_object(aTHX_ sv_newmortal(), (AvARRAY(av)[idx])));
	else
	    XPUSHs(make_sv_object(aTHX_ sv_newmortal(), NULL));

#if PERL_VERSION < 9
				   
MODULE = B	PACKAGE = B::AV

U8
AvFLAGS(av)
	B::AV	av

#endif

MODULE = B	PACKAGE = B::CV		PREFIX = Cv

U32
CvCONST(cv)
	B::CV	cv

B::HV
CvSTASH(cv)
	B::CV	cv

B::GV
CvGV(cv)
	B::CV	cv

char *
CvFILE(cv)
	B::CV	cv

long
CvDEPTH(cv)
	B::CV	cv

B::AV
CvPADLIST(cv)
	B::CV	cv

B::CV
CvOUTSIDE(cv)
	B::CV	cv

U32
CvOUTSIDE_SEQ(cv)
	B::CV	cv

void
CvXSUB(cv)
	B::CV	cv
    CODE:
	ST(0) = sv_2mortal(newSViv(CvISXSUB(cv) ? PTR2IV(CvXSUB(cv)) : 0));


void
CvXSUBANY(cv)
	B::CV	cv
    CODE:
	ST(0) = CvCONST(cv) ?
	    make_sv_object(aTHX_ sv_newmortal(),(SV *)CvXSUBANY(cv).any_ptr) :
	    sv_2mortal(newSViv(CvISXSUB(cv) ? CvXSUBANY(cv).any_iv : 0));

MODULE = B    PACKAGE = B::CV

U16
CvFLAGS(cv)
      B::CV   cv

MODULE = B	PACKAGE = B::CV		PREFIX = cv_

B::SV
cv_const_sv(cv)
	B::CV	cv


MODULE = B	PACKAGE = B::HV		PREFIX = Hv

STRLEN
HvFILL(hv)
	B::HV	hv

STRLEN
HvMAX(hv)
	B::HV	hv

I32
HvKEYS(hv)
	B::HV	hv

I32
HvRITER(hv)
	B::HV	hv

char *
HvNAME(hv)
	B::HV	hv

void
HvARRAY(hv)
	B::HV	hv
    PPCODE:
	if (HvKEYS(hv) > 0) {
	    SV *sv;
	    char *key;
	    I32 len;
	    (void)hv_iterinit(hv);
	    EXTEND(sp, HvKEYS(hv) * 2);
	    while ((sv = hv_iternextsv(hv, &key, &len))) {
		PUSHs(newSVpvn(key, len));
		PUSHs(make_sv_object(aTHX_ sv_newmortal(), sv));
	    }
	}

MODULE = B	PACKAGE = B::HE		PREFIX = He

B::SV
HeVAL(he)
	B::HE he

U32
HeHASH(he)
	B::HE he

B::SV
HeSVKEY_force(he)
	B::HE he
