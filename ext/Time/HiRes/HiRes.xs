#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef WIN32
#include <time.h>
#else
#include <sys/time.h>
#endif
#ifdef __cplusplus
}
#endif

static IV
constant(char *name, int arg)
{
    errno = 0;
    switch (*name) {
    case 'I':
      if (strEQ(name, "ITIMER_REAL"))
#ifdef ITIMER_REAL
	return ITIMER_REAL;
#else
	goto not_there;
#endif
      if (strEQ(name, "ITIMER_REALPROF"))
#ifdef ITIMER_REALPROF
	return ITIMER_REALPROF;
#else
	goto not_there;
#endif
      if (strEQ(name, "ITIMER_VIRTUAL"))
#ifdef ITIMER_VIRTUAL
	return ITIMER_VIRTUAL;
#else
	goto not_there;
#endif
      if (strEQ(name, "ITIMER_PROF"))
#ifdef ITIMER_PROF
	return ITIMER_PROF;
#else
	goto not_there;
#endif
      break;
    }
    errno = EINVAL;
    return 0;

not_there:
    errno = ENOENT;
    return 0;
}

#if !defined(HAS_GETTIMEOFDAY) && defined(WIN32)
#define HAS_GETTIMEOFDAY

/* shows up in winsock.h?
struct timeval {
 long tv_sec;
 long tv_usec;
}
*/

typedef union {
    unsigned __int64	ft_i64;
    FILETIME		ft_val;
} FT_t;

/* Number of 100 nanosecond units from 1/1/1601 to 1/1/1970 */
#define EPOCH_BIAS  116444736000000000i64

/* NOTE: This does not compute the timezone info (doing so can be expensive,
 * and appears to be unsupported even by glibc) */
int
gettimeofday (struct timeval *tp, void *not_used)
{
    FT_t ft;

    /* this returns time in 100-nanosecond units  (i.e. tens of usecs) */
    GetSystemTimeAsFileTime(&ft.ft_val);

    /* seconds since epoch */
    tp->tv_sec = (long)((ft.ft_i64 - EPOCH_BIAS) / 10000000i64);

    /* microseconds remaining */
    tp->tv_usec = (long)((ft.ft_i64 / 10i64) % 1000000i64);

    return 0;
}
#endif

#if !defined(HAS_GETTIMEOFDAY) && defined(VMS)
#define HAS_GETTIMEOFDAY

#include <lnmdef.h>
#include <time.h> /* gettimeofday */
#include <stdlib.h> /* qdiv */
#include <starlet.h> /* sys$gettim */
#include <descrip.h>
#ifdef __VAX
#include <lib$routines.h> /* lib$ediv() */
#endif

/*
        VMS binary time is expressed in 100 nano-seconds since
        system base time which is 17-NOV-1858 00:00:00.00
*/

#define DIV_100NS_TO_SECS  10000000L
#define DIV_100NS_TO_USECS 10L

/* 
        gettimeofday is supposed to return times since the epoch
        so need to determine this in terms of VMS base time
*/
static $DESCRIPTOR(dscepoch,"01-JAN-1970 00:00:00.00");

#ifdef __VAX
static long base_adjust[2]={0L,0L};
#else
static __int64 base_adjust=0;
#endif

/* 

   If we don't have gettimeofday, then likely we are on a VMS machine that
   operates on local time rather than UTC...so we have to zone-adjust.
   This code gleefully swiped from VMS.C 

*/
/* method used to handle UTC conversions:
 *   1 == CRTL gmtime();  2 == SYS$TIMEZONE_DIFFERENTIAL;  3 == no correction
 */
static int gmtime_emulation_type;
/* number of secs to add to UTC POSIX-style time to get local time */
static long int utc_offset_secs;
static struct dsc$descriptor_s fildevdsc = 
  { 12, DSC$K_DTYPE_T, DSC$K_CLASS_S, "LNM$FILE_DEV" };
static struct dsc$descriptor_s *fildev[] = { &fildevdsc, NULL };

static time_t toutc_dst(time_t loc) {
  struct tm *rsltmp;

  if ((rsltmp = localtime(&loc)) == NULL) return -1;
  loc -= utc_offset_secs;
  if (rsltmp->tm_isdst) loc -= 3600;
  return loc;
}

static time_t toloc_dst(time_t utc) {
  struct tm *rsltmp;

  utc += utc_offset_secs;
  if ((rsltmp = localtime(&utc)) == NULL) return -1;
  if (rsltmp->tm_isdst) utc += 3600;
  return utc;
}

#define _toutc(secs)  ((secs) == (time_t) -1 ? (time_t) -1 : \
       ((gmtime_emulation_type || timezone_setup()), \
       (gmtime_emulation_type == 1 ? toutc_dst(secs) : \
       ((secs) - utc_offset_secs))))

#define _toloc(secs)  ((secs) == (time_t) -1 ? (time_t) -1 : \
       ((gmtime_emulation_type || timezone_setup()), \
       (gmtime_emulation_type == 1 ? toloc_dst(secs) : \
       ((secs) + utc_offset_secs))))

static int
timezone_setup(void) 
{
  struct tm *tm_p;

  if (gmtime_emulation_type == 0) {
    int dstnow;
    time_t base = 15 * 86400; /* 15jan71; to avoid month/year ends between    */
                              /* results of calls to gmtime() and localtime() */
                              /* for same &base */

    gmtime_emulation_type++;
    if ((tm_p = gmtime(&base)) == NULL) { /* CRTL gmtime() is a fake */
      char off[LNM$C_NAMLENGTH+1];;

      gmtime_emulation_type++;
      if (!Perl_vmstrnenv("SYS$TIMEZONE_DIFFERENTIAL",off,0,fildev,0)) {
        gmtime_emulation_type++;
        utc_offset_secs = 0;
        Perl_warn(aTHX_ "no UTC offset information; assuming local time is UTC");
      }
      else { utc_offset_secs = atol(off); }
    }
    else { /* We've got a working gmtime() */
      struct tm gmt, local;

      gmt = *tm_p;
      tm_p = localtime(&base);
      local = *tm_p;
      utc_offset_secs  = (local.tm_mday - gmt.tm_mday) * 86400;
      utc_offset_secs += (local.tm_hour - gmt.tm_hour) * 3600;
      utc_offset_secs += (local.tm_min  - gmt.tm_min)  * 60;
      utc_offset_secs += (local.tm_sec  - gmt.tm_sec);
    }
  }
  return 1;
}


int
gettimeofday (struct timeval *tp, void *tpz)
{
 long ret;
#ifdef __VAX
 long quad[2];
 long quad1[2];
 long div_100ns_to_secs;
 long div_100ns_to_usecs;
 long quo,rem;
 long quo1,rem1;
#else
 __int64 quad;
 __qdiv_t ans1,ans2;
#endif
/*
        In case of error, tv_usec = 0 and tv_sec = VMS condition code.
        The return from function is also set to -1.
        This is not exactly as per the manual page.
*/

 tp->tv_usec = 0;

#ifdef __VAX
 if (base_adjust[0]==0 && base_adjust[1]==0) {
#else
 if (base_adjust==0) { /* Need to determine epoch adjustment */
#endif
        ret=sys$bintim(&dscepoch,&base_adjust);
        if (1 != (ret &&1)) {
                tp->tv_sec = ret;
                return -1;
        }
 }

 ret=sys$gettim(&quad); /* Get VMS system time */
 if ((1 && ret) == 1) {
#ifdef __VAX
        quad[0] -= base_adjust[0]; /* convert to epoch offset */
        quad[1] -= base_adjust[1]; /* convert 2nd half of quadword */
        div_100ns_to_secs = DIV_100NS_TO_SECS;
        div_100ns_to_usecs = DIV_100NS_TO_USECS;
        lib$ediv(&div_100ns_to_secs,&quad,&quo,&rem);
        quad1[0] = rem;
        quad1[1] = 0L;
        lib$ediv(&div_100ns_to_usecs,&quad1,&quo1,&rem1);
        tp->tv_sec = quo; /* Whole seconds */
        tp->tv_usec = quo1; /* Micro-seconds */
#else
        quad -= base_adjust; /* convert to epoch offset */
        ans1=qdiv(quad,DIV_100NS_TO_SECS);
        ans2=qdiv(ans1.rem,DIV_100NS_TO_USECS);
        tp->tv_sec = ans1.quot; /* Whole seconds */
        tp->tv_usec = ans2.quot; /* Micro-seconds */
#endif
 } else {
        tp->tv_sec = ret;
        return -1;
 }
# ifdef VMSISH_TIME
# ifdef RTL_USES_UTC
  if (VMSISH_TIME) tp->tv_sec = _toloc(tp->tv_sec);
# else
  if (!VMSISH_TIME) tp->tv_sec = _toutc(tp->tv_sec);
# endif
# endif
 return 0;
}
#endif

#if !defined(HAS_USLEEP) && defined(HAS_SELECT)
#ifndef SELECT_IS_BROKEN
#define HAS_USLEEP
#define usleep hrt_usleep  /* could conflict with ncurses for static build */

void
hrt_usleep(unsigned long usec)
{
    struct timeval tv;
    tv.tv_sec = 0;
    tv.tv_usec = usec;
    select(0, (Select_fd_set_t)NULL, (Select_fd_set_t)NULL,
		(Select_fd_set_t)NULL, &tv);
}
#endif
#endif

#if !defined(HAS_USLEEP) && defined(WIN32)
#define HAS_USLEEP
#define usleep hrt_usleep  /* could conflict with ncurses for static build */

void
hrt_usleep(unsigned long usec)
{
    long msec;
    msec = usec / 1000;
    Sleep (msec);
}
#endif


#if !defined(HAS_UALARM) && defined(HAS_SETITIMER)
#define HAS_UALARM
#define ualarm hrt_ualarm  /* could conflict with ncurses for static build */

int
hrt_ualarm(int usec, int interval)
{
   struct itimerval itv;
   itv.it_value.tv_sec = usec / 1000000;
   itv.it_value.tv_usec = usec % 1000000;
   itv.it_interval.tv_sec = interval / 1000000;
   itv.it_interval.tv_usec = interval % 1000000;
   return setitimer(ITIMER_REAL, &itv, 0);
}
#endif

#ifdef HAS_GETTIMEOFDAY

static int
myU2time(UV *ret)
{
  struct timeval Tp;
  int status;
  status = gettimeofday (&Tp, NULL);
  ret[0] = Tp.tv_sec;
  ret[1] = Tp.tv_usec;
  return status;
}

static NV
myNVtime()
{
  struct timeval Tp;
  int status;
  status = gettimeofday (&Tp, NULL);
  return status == 0 ? Tp.tv_sec + (Tp.tv_usec / 1000000.) : -1.0;
}

#endif

MODULE = Time::HiRes            PACKAGE = Time::HiRes

PROTOTYPES: ENABLE

BOOT:
#ifdef HAS_GETTIMEOFDAY
{
  UV auv[2];
  hv_store(PL_modglobal, "Time::NVtime", 12, newSViv((IV) myNVtime()), 0);
  if (myU2time(auv) == 0)
    hv_store(PL_modglobal, "Time::U2time", 12, newSViv((IV) auv[0]), 0);
}
#endif

IV
constant(name, arg)
	char *		name
	int		arg

#if defined(HAS_USLEEP) && defined(HAS_GETTIMEOFDAY)

NV
usleep(useconds)
        NV useconds
	PREINIT:
	struct timeval Ta, Tb;
	CODE:
	gettimeofday(&Ta, NULL);
	if (items > 0) {
	    if (useconds > 1E6) {
		IV seconds = (IV) (useconds / 1E6);
		sleep(seconds);
		useconds -= 1E6 * seconds;
	    }
	    usleep((UV)useconds);
	} else
	    PerlProc_pause();
	gettimeofday(&Tb, NULL);
#if 0
	printf("[%ld %ld] [%ld %ld]\n", Tb.tv_sec, Tb.tv_usec, Ta.tv_sec, Ta.tv_usec);
#endif
	RETVAL = 1E6*(Tb.tv_sec-Ta.tv_sec)+(NV)((IV)Tb.tv_usec-(IV)Ta.tv_usec);

	OUTPUT:
	RETVAL

NV
sleep(...)
	PREINIT:
	struct timeval Ta, Tb;
	CODE:
	gettimeofday(&Ta, NULL);
	if (items > 0) {
	    NV seconds  = SvNV(ST(0));
	    IV useconds = 1E6 * (seconds - (IV)seconds);
	    sleep(seconds);
	    usleep(useconds);
	} else
	    PerlProc_pause();
	gettimeofday(&Tb, NULL);
#if 0
	printf("[%ld %ld] [%ld %ld]\n", Tb.tv_sec, Tb.tv_usec, Ta.tv_sec, Ta.tv_usec);
#endif
	RETVAL = (NV)(Tb.tv_sec-Ta.tv_sec)+0.000001*(NV)(Tb.tv_usec-Ta.tv_usec);

	OUTPUT:
	RETVAL

#endif

#ifdef HAS_UALARM

int
ualarm(useconds,interval=0)
	int useconds
	int interval

int
alarm(fseconds,finterval=0)
	NV fseconds
	NV finterval
	PREINIT:
	int useconds, uinterval;
	CODE:
	useconds = fseconds * 1000000;
	uinterval = finterval * 1000000;
	RETVAL = ualarm (useconds, uinterval);

	OUTPUT:
	RETVAL

#endif

#ifdef HAS_GETTIMEOFDAY
#    ifdef MACOS_TRADITIONAL	/* fix epoch TZ and use unsigned time_t */
void
gettimeofday()
        PREINIT:
        struct timeval Tp;
        struct timezone Tz;
        PPCODE:
        int status;
        status = gettimeofday (&Tp, &Tz);
        Tp.tv_sec += Tz.tz_minuteswest * 60;	/* adjust for TZ */

        if (GIMME == G_ARRAY) {
             EXTEND(sp, 2);
             /* Mac OS (Classic) has unsigned time_t */
             PUSHs(sv_2mortal(newSVuv(Tp.tv_sec)));
             PUSHs(sv_2mortal(newSViv(Tp.tv_usec)));
        } else {
             EXTEND(sp, 1);
             PUSHs(sv_2mortal(newSVnv(Tp.tv_sec + (Tp.tv_usec / 1000000.0))));
        }

NV
time()
        PREINIT:
        struct timeval Tp;
        struct timezone Tz;
        CODE:
        int status;
        status = gettimeofday (&Tp, &Tz);
        Tp.tv_sec += Tz.tz_minuteswest * 60;	/* adjust for TZ */
        RETVAL = Tp.tv_sec + (Tp.tv_usec / 1000000.0);
	OUTPUT:
	RETVAL

#    else	/* MACOS_TRADITIONAL */
void
gettimeofday()
        PREINIT:
        struct timeval Tp;
        PPCODE:
	int status;
        status = gettimeofday (&Tp, NULL);
        if (GIMME == G_ARRAY) {
	     EXTEND(sp, 2);
             PUSHs(sv_2mortal(newSViv(Tp.tv_sec)));
             PUSHs(sv_2mortal(newSViv(Tp.tv_usec)));
        } else {
             EXTEND(sp, 1);
             PUSHs(sv_2mortal(newSVnv(Tp.tv_sec + (Tp.tv_usec / 1000000.0))));
        }

NV
time()
        PREINIT:
        struct timeval Tp;
        CODE:
	int status;
        status = gettimeofday (&Tp, NULL);
        RETVAL = Tp.tv_sec + (Tp.tv_usec / 1000000.);
	OUTPUT:
	RETVAL

#    endif	/* MACOS_TRADITIONAL */
#endif

#if defined(HAS_GETITIMER) && defined(HAS_SETITIMER)

#define TV2NV(tv) ((NV)((tv).tv_sec) + 0.000001 * (NV)((tv).tv_usec))

void
setitimer(which, seconds, interval = 0)
	int which
	NV seconds
	NV interval
    PREINIT:
	struct itimerval newit;
	struct itimerval oldit;
    PPCODE:
	newit.it_value.tv_sec  = seconds;
	newit.it_value.tv_usec =
	  (seconds  - (NV)newit.it_value.tv_sec)    * 1000000.0;
	newit.it_interval.tv_sec  = interval;
	newit.it_interval.tv_usec =
	  (interval - (NV)newit.it_interval.tv_sec) * 1000000.0;
	if (setitimer(which, &newit, &oldit) == 0) {
	  EXTEND(sp, 1);
	  PUSHs(sv_2mortal(newSVnv(TV2NV(oldit.it_value))));
	  if (GIMME == G_ARRAY) {
	    EXTEND(sp, 1);
	    PUSHs(sv_2mortal(newSVnv(TV2NV(oldit.it_interval))));
	  }
	}

void
getitimer(which)
	int which
    PREINIT:
	struct itimerval nowit;
    PPCODE:
	if (getitimer(which, &nowit) == 0) {
	  EXTEND(sp, 1);
	  PUSHs(sv_2mortal(newSVnv(TV2NV(nowit.it_value))));
	  if (GIMME == G_ARRAY) {
	    EXTEND(sp, 1);
	    PUSHs(sv_2mortal(newSVnv(TV2NV(nowit.it_interval))));
	  }
	}

#endif

# $Id: HiRes.xs,v 1.11 1999/03/16 02:27:38 wegscd Exp wegscd $

# $Log: HiRes.xs,v $
# Revision 1.11  1999/03/16 02:27:38  wegscd
# Add U2time, NVtime. Fix symbols for static link.
#
# Revision 1.10  1998/09/30 02:36:25  wegscd
# Add VMS changes.
#
# Revision 1.9  1998/07/07 02:42:06  wegscd
# Win32 usleep()
#
# Revision 1.8  1998/07/02 01:47:26  wegscd
# Add Win32 code for gettimeofday.
#
# Revision 1.7  1997/11/13 02:08:12  wegscd
# Add missing EXTEND in gettimeofday() scalar code.
#
# Revision 1.6  1997/11/11 02:32:35  wegscd
# Do something useful when calling gettimeofday() in a scalar context.
# The patch is courtesy of Gisle Aas.
#
# Revision 1.5  1997/11/06 03:10:47  wegscd
# Fake ualarm() if we have setitimer.
#
# Revision 1.4  1997/11/05 05:41:23  wegscd
# Turn prototypes ON (suggested by Gisle Aas)
#
# Revision 1.3  1997/10/13 20:56:15  wegscd
# Add PROTOTYPES: DISABLE
#
# Revision 1.2  1997/05/23 01:01:38  wegscd
# Conditional compilation, depending on what the OS gives us.
#
# Revision 1.1  1996/09/03 18:26:35  wegscd
# Initial revision
#
#
