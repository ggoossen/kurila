#include "EXTERN.h"
#include "perl.h"

#define NO_XSLOCKS
#include "XSUB.h"

static void throws_exception(pTHX_ int throw_e)
{
  if (throw_e)
    croak(aTHX_ "boo\n");
}

/* Don't give this the same name as exection() in ext/Devel/PPPort/module3.c
   as otherwise building entirely staticly will cause a test to fail, as
   PPPort's execption() gets used in place of this one.  */
   
int apitest_exception(int throw_e)
{
  dTHR;
  dXCPT;
  SV *caught = get_sv("XS::APItest::exception_caught", 0);

  XCPT_TRY_START {
    throws_exception(aTHX_ throw_e);
  } XCPT_TRY_END

  XCPT_CATCH
  {
    sv_setiv(caught, 1);
    XCPT_RETHROW;
  }

  sv_setiv(caught, 0);

  return 42;
}

