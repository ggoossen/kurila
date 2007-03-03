#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

double XS_BASE = 0;
double XS_BASE_LEN = 0;

MODULE = Math::BigInt::FastCalc		PACKAGE = Math::BigInt::FastCalc

 #############################################################################
 # 2002-08-12 0.03 Tels unreleased
 #  * is_zero/is_one/is_odd/is_even/len work now (pass v1.61 tests)
 # 2002-08-13 0.04 Tels unreleased
 #  * returns no/yes for is_foo() methods to be faster
 # 2002-08-18 0.06alpha
 #  * added _num(), _inc() and _dec()
 # 2002-08-25 0.06 Tels
 #  * added __strip_zeros(), _copy()
 # 2004-08-13 0.07 Tels
 #  * added _is_two(), _is_ten(), _ten()

void 
_set_XS_BASE(BASE, BASE_LEN)
  SV* BASE
  SV* BASE_LEN

  CODE:
    XS_BASE = SvNV(BASE); 
    XS_BASE_LEN = SvIV(BASE_LEN); 

##############################################################################
# _copy

void
_copy(class, x)
  SV*	x
  INIT:
    AV*	a;
    AV*	a2;
    I32	elems;

  CODE:
    a = (AV*)SvRV(x);			/* ref to aray, don't check ref */
    elems = av_len(a);			/* number of elems in array */
    a2 = (AV*)sv_2mortal((SV*)newAV());
    av_extend (a2, elems);		/* prepadd */
    while (elems >= 0)
      {
      /* av_store( a2,  elems, newSVsv( (SV*)*av_fetch(a, elems, 0) ) ); */

      /* looking and trying to preserve IV is actually slower when copying */
      /* temp = (SV*)*av_fetch(a, elems, 0);
      if (SvIOK(temp))
        {
        av_store( a2,  elems, newSViv( SvIV( (SV*)*av_fetch(a, elems, 0) )));
        }
      else
        {
        av_store( a2,  elems, newSVnv( SvNV( (SV*)*av_fetch(a, elems, 0) )));
        }
      */
      av_store( a2,  elems, newSVnv( SvNV( (SV*)*av_fetch(a, elems, 0) )));
      elems--;
      }
    ST(0) = sv_2mortal( newRV_inc((SV*) a2) );

##############################################################################
# __strip_zeros (also check for empty arrays from div)

void
__strip_zeros(x)
  SV*	x
  INIT:
    AV*	a;
    SV*	temp;
    I32	elems;
    I32	index;

  CODE:
    a = (AV*)SvRV(x);			/* ref to aray, don't check ref */
    elems = av_len(a);			/* number of elems in array */
    ST(0) = x;				/* we return x */
    if (elems == -1)
      { 
      av_push (a, newSViv(0));		/* correct empty arrays */
      XSRETURN(1);
      }
    if (elems == 0)
      {
      XSRETURN(1);			/* nothing to do since only one elem */
      }
    index = elems;
    while (index > 0)
      {
      temp = *av_fetch(a, index, 0);	/* fetch ptr to current element */
      if (SvNV(temp) != 0)
        {
        break;
        }
      index--;
      }
    if (index < elems)
      {
      index = elems - index;
      while (index-- > 0)
        {
        av_pop (a);
        }
      }
    XSRETURN(1);

##############################################################################
# decrement (subtract one)

void
_dec(class,x)
  SV*	x
  INIT:
    AV*	a;
    SV*	temp;
    I32	elems;
    I32	index;
    NV	MAX;

  CODE:
    a = (AV*)SvRV(x);			/* ref to aray, don't check ref */
    elems = av_len(a);			/* number of elems in array */
    ST(0) = x;				/* we return x */

    MAX = XS_BASE - 1;
    index = 0;
    while (index <= elems)
      {
      temp = *av_fetch(a, index, 0);	/* fetch ptr to current element */
      sv_setnv (temp, SvNV(temp)-1);
      if (SvNV(temp) >= 0)
        {
        break;				/* early out */
        }
      sv_setnv (temp, MAX);		/* overflow, so set this to $MAX */
      index++;
      } 
    /* do have more than one element? */
    /* (more than one because [0] should be kept as single-element) */
    if (elems > 0)
      {
      temp = *av_fetch(a, elems, 0);	/* fetch last element */
      if (SvIV(temp) == 0)		/* did last elem overflow? */ 
        {
        av_pop(a);			/* yes, so shrink array */
        				/* aka remove leading zeros */
        }
      }
    XSRETURN(1);			/* return x */

##############################################################################
# increment (add one)

void
_inc(class,x)
  SV*	x
  INIT:
    AV*	a;
    SV*	temp;
    I32	elems;
    I32	index;
    NV	BASE;

  CODE:
    a = (AV*)SvRV(x);			/* ref to aray, don't check ref */
    elems = av_len(a);			/* number of elems in array */
    ST(0) = x;				/* we return x */

    BASE = XS_BASE;
    index = 0;
    while (index <= elems)
      {
      temp = *av_fetch(a, index, 0);	/* fetch ptr to current element */
      sv_setnv (temp, SvNV(temp)+1);
      if (SvNV(temp) < BASE)
        {
        XSRETURN(1);			/* return (early out) */
        }
      sv_setiv (temp, 0);		/* overflow, so set this elem to 0 */
      index++;
      } 
    temp = *av_fetch(a, elems, 0);	/* fetch last element */
    if (SvIV(temp) == 0)		/* did last elem overflow? */
      {
      av_push(a, newSViv(1));		/* yes, so extend array by 1 */
      }
    XSRETURN(1);			/* return x */

##############################################################################
# Make a number (scalar int/float) from a BigInt object

void
_num(class,x)
  SV*	x
  INIT:
    AV*	a;
    NV	fac;
    SV*	temp;
    NV	num;
    I32	elems;
    I32	index;
    NV	BASE;

  CODE:
    a = (AV*)SvRV(x);			/* ref to aray, don't check ref */
    elems = av_len(a);			/* number of elems in array */

    if (elems == 0)			/* only one element? */
      {
      ST(0) = *av_fetch(a, 0, 0);	/* fetch first (only) element */
      XSRETURN(1);			/* return it */
      }
    fac = 1.0;				/* factor */
    index = 0;
    num = 0.0;
    BASE = XS_BASE;
    while (index <= elems)
      {
      temp = *av_fetch(a, index, 0);	/* fetch current element */
      num += fac * SvNV(temp);
      fac *= BASE;
      index++;
      }
    ST(0) = newSVnv(num);

##############################################################################

#define CONSTANT_OBJ(int)		\
    RETVAL = newAV();			\
    sv_2mortal((SV*)RETVAL);		\
    av_push (RETVAL, newSViv( int ));

AV *
_zero(class)
  CODE:
    CONSTANT_OBJ(0)
  OUTPUT:
    RETVAL

##############################################################################

AV *
_one(class)
  CODE:
    CONSTANT_OBJ(1)
  OUTPUT:
    RETVAL

##############################################################################

AV *
_two(class)
  CODE:
    CONSTANT_OBJ(2)
  OUTPUT:
    RETVAL

##############################################################################

AV *
_ten(class)
  CODE:
    CONSTANT_OBJ(10)
  OUTPUT:
    RETVAL

##############################################################################

void
_is_even(class, x)
  SV*	x
  INIT:
    AV*	a;
    SV*	temp;

  CODE:
    a = (AV*)SvRV(x);		/* ref to aray, don't check ref */
    temp = *av_fetch(a, 0, 0);	/* fetch first element */
    ST(0) = boolSV((SvIV(temp) & 1) == 0);

##############################################################################

void
_is_odd(class, x)
  SV*	x
  INIT:
    AV*	a;
    SV*	temp;

  CODE:
    a = (AV*)SvRV(x);		/* ref to aray, don't check ref */
    temp = *av_fetch(a, 0, 0);	/* fetch first element */
    ST(0) = boolSV((SvIV(temp) & 1) != 0);

##############################################################################

void
_is_one(class, x)
  SV*	x
  INIT:
    AV*	a;
    SV*	temp;

  CODE:
    a = (AV*)SvRV(x);			/* ref to aray, don't check ref */
    if ( av_len(a) != 0)
      {
      ST(0) = &PL_sv_no;
      XSRETURN(1);			/* len != 1, can't be '1' */
      }
    temp = *av_fetch(a, 0, 0);		/* fetch first element */
    ST(0) = boolSV((SvIV(temp) == 1));

##############################################################################

void
_is_two(class, x)
  SV*	x
  INIT:
    AV*	a;
    SV*	temp;

  CODE:
    a = (AV*)SvRV(x);			/* ref to aray, don't check ref */
    if ( av_len(a) != 0)
      {
      ST(0) = &PL_sv_no;
      XSRETURN(1);			/* len != 1, can't be '2' */
      }
    temp = *av_fetch(a, 0, 0);		/* fetch first element */
    ST(0) = boolSV((SvIV(temp) == 2));

##############################################################################

void
_is_ten(class, x)
  SV*	x
  INIT:
    AV*	a;
    SV*	temp;

  CODE:
    a = (AV*)SvRV(x);			/* ref to aray, don't check ref */
    if ( av_len(a) != 0)
      {
      ST(0) = &PL_sv_no;
      XSRETURN(1);			/* len != 1, can't be '10' */
      }
    temp = *av_fetch(a, 0, 0);		/* fetch first element */
    ST(0) = boolSV((SvIV(temp) == 10));

##############################################################################

void
_is_zero(class, x)
  SV*	x
  INIT:
    AV*	a;
    SV*	temp;

  CODE:
    a = (AV*)SvRV(x);			/* ref to aray, don't check ref */
    if ( av_len(a) != 0)
      {
      ST(0) = &PL_sv_no;
      XSRETURN(1);			/* len != 1, can't be '0' */
      }
    temp = *av_fetch(a, 0, 0);		/* fetch first element */
    ST(0) = boolSV((SvIV(temp) == 0));

##############################################################################

void
_len(class,x)
  SV*	x
  INIT:
    AV*	a;
    SV*	temp;
    NV	elems;
    STRLEN len;

  CODE:
    a = (AV*)SvRV(x);			/* ref to aray, don't check ref */
    elems = (NV) av_len(a);		/* number of elems in array */
    temp = *av_fetch(a, elems, 0);	/* fetch last element */
    SvPV(temp, len);			/* convert to string & store length */
    len += XS_BASE_LEN * elems;
    ST(0) = newSViv(len);

##############################################################################

void
_acmp(class, cx, cy);
  SV*  cx
  SV*  cy
  INIT:
    AV* array_x;
    AV* array_y;
    I32 elemsx, elemsy, diff;
    SV* tempx;
    SV* tempy;
    STRLEN lenx;
    STRLEN leny;
    NV diff_nv;
    I32 diff_str;

  CODE:
    array_x = (AV*)SvRV(cx);		/* ref to aray, don't check ref */
    array_y = (AV*)SvRV(cy);		/* ref to aray, don't check ref */
    elemsx =  av_len(array_x);
    elemsy =  av_len(array_y);
    diff = elemsx - elemsy;		/* difference */

    if (diff > 0)
      {
      ST(0) = newSViv(1);		/* len differs: X > Y */
      XSRETURN(1);
      }
    if (diff < 0)
      {
      ST(0) = newSViv(-1);		/* len differs: X < Y */
      XSRETURN(1);
      }
    /* both have same number of elements, so check length of last element
       and see if it differes */
    tempx = *av_fetch(array_x, elemsx, 0);	/* fetch last element */
    tempy = *av_fetch(array_y, elemsx, 0);	/* fetch last element */
    SvPV(tempx, lenx);			/* convert to string & store length */
    SvPV(tempy, leny);			/* convert to string & store length */
    diff_str = (I32)lenx - (I32)leny;
    if (diff_str > 0)
      {
      ST(0) = newSViv(1);		/* same len, but first elems differs in len */
      XSRETURN(1);
      }
    if (diff_str < 0)
      {
      ST(0) = newSViv(-1);		/* same len, but first elems differs in len */
      XSRETURN(1);
      }
    /* same number of digits, so need to make a full compare */
    diff_nv = 0;
    while (elemsx >= 0)
      {
      tempx = *av_fetch(array_x, elemsx, 0);	/* fetch curr x element */
      tempy = *av_fetch(array_y, elemsx, 0);	/* fetch curr y element */
      diff_nv = SvNV(tempx) - SvNV(tempy);
      if (diff_nv != 0)
        {
        break; 
        }
      elemsx--;
      } 
    if (diff_nv > 0)
      {
      ST(0) = newSViv(1);
      XSRETURN(1);
      }
    if (diff_nv < 0)
      {
      ST(0) = newSViv(-1);
      XSRETURN(1);
      }
    ST(0) = newSViv(0);		/* equal */

