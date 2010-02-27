#!./perl -w
# Test -DEBUGGING things (in dump.c)

BEGIN 
    unshift: $^INCLUDE_PATH, 't'
    
    # skip all tests unless perl was compiled with -DDEBUGGING
    require Config
    if ((Config::config_value: 'ccflags') !~ m/-DDEBUGGING /)
        print: $^STDOUT, "1..0 # Skip -- Perl built w/o -DEBUGGING\n"
        exit 0
    
# require 'test.pl'; # now done by OptreeCheck


print: $^STDOUT, "1..0 # Skip -- TODO for kurila\n"
exit 0

use OptreeCheck

plan: tests => 3

checkOptree:  name      => '-Dx -e print 42'
              Dx        => 'print 42'
              noanchors => 1 # unanchored match
              expect    => << 'EO_THR', expect_nt => << 'EO_NOTHR'
{
1   TYPE = leave  ===> DONE
    TARG = 1
    FLAGS = (VOID,KIDS,PARENS)
    PRIVATE = (REFCOUNTED)
    REFCNT = 1
    {
2       TYPE = enter  ===> 3
    }
    {
3       TYPE = nextstate  ===> 4
        FLAGS = (VOID)
        LINE = 1
        PACKAGE = "main"
    }
    {
6       TYPE = print  ===> 1
        FLAGS = (VOID,KIDS)
        {
4           TYPE = pushmark  ===> 5
            FLAGS = (SCALAR)
        }
        {
5           TYPE = const  ===> 6
            TARG = 1
            FLAGS = (SCALAR)
        }
    }
}
EO_THR
# {
# 1   TYPE = leave  ===> DONE
#     TARG = 1
#     FLAGS = (VOID,KIDS,PARENS)
#     PRIVATE = (REFCOUNTED)
#     REFCNT = 1
#     {
# 2       TYPE = enter  ===> 3
#     }
#     {
# 3       TYPE = nextstate  ===> 4
#         FLAGS = (VOID)
#         LINE = 1
#         PACKAGE = "main"
#     }
#     {
# 8       TYPE = print  ===> 1
#         FLAGS = (VOID,KIDS)
#         {
# 4           TYPE = pushmark  ===> 5
#             FLAGS = (SCALAR)
#         }
#         {
# 7           TYPE = add  ===> 8
#             TARG = 1
#             FLAGS = (SCALAR,KIDS)
#             {
#                 TYPE = null  ===> (6)
#                   (was rv2sv)
#                 FLAGS = (SCALAR,KIDS)
#                 {
# 5                   TYPE = gvsv  ===> 6
#                     FLAGS = (SCALAR)
#                 }
#             }
#             {
# 6               TYPE = const  ===> 7
#                 FLAGS = (SCALAR)
#                 SV = IV(42)
#             }
#         }
#     }
# }
EO_NOTHR

checkOptree:  name      => '-Dx -e print $a+42'
              Dx        => 'print $a+42'
              errs      => 'Name "main::a" used only once: possible typo at -e line 1.'
              noanchors => 1 # unanchored match
              expect    => << 'EO_THR', expect_nt => << 'EO_NOTHR'
# {
# 1   TYPE = leave  ===> DONE
#     TARG = 1
#     FLAGS = (VOID,KIDS,PARENS)
#     PRIVATE = (REFCOUNTED)
#     REFCNT = 1
#     {
# 2       TYPE = enter  ===> 3
#     }
#     {
# 3       TYPE = nextstate  ===> 4
#         FLAGS = (VOID)
#         LINE = 1
#         PACKAGE = "main"
#     }
#     {
# 8       TYPE = print  ===> 1
#         FLAGS = (VOID,KIDS)
#         {
# 4           TYPE = pushmark  ===> 5
#             FLAGS = (SCALAR)
#         }
#         {
# 7           TYPE = add  ===> 8
#             TARG = 2
#             FLAGS = (SCALAR,KIDS)
#             {
#                 TYPE = null  ===> (6)
#                   (was rv2sv)
#                 FLAGS = (SCALAR,KIDS)
#                 {
# 5                   TYPE = gvsv  ===> 6
#                     FLAGS = (SCALAR)
#                     PADIX = 1
#                 }
#             }
#             {
# 6               TYPE = const  ===> 7
#                 TARG = 3
#                 FLAGS = (SCALAR)
#             }
#         }
#     }
# }
EO_THR
# {
# 1   TYPE = leave  ===> DONE
#     TARG = 1
#     FLAGS = (VOID,KIDS,PARENS)
#     PRIVATE = (REFCOUNTED)
#     REFCNT = 1
#     {
# 2       TYPE = enter  ===> 3
#     }
#     {
# 3       TYPE = nextstate  ===> 4
#         FLAGS = (VOID)
#         LINE = 1
#         PACKAGE = "main"
#     }
#     {
# 9       TYPE = print  ===> 1
#         FLAGS = (VOID,KIDS)
#         {
# 4           TYPE = pushmark  ===> 5
#             FLAGS = (SCALAR)
#         }
#         {
# 8           TYPE = sort  ===> 9
#             FLAGS = (LIST,KIDS)
#             {
# 5               TYPE = pushmark  ===> 6
#                 FLAGS = (SCALAR)
#             }
#             {
# 7               TYPE = rv2av  ===> 8
#                 TARG = 2
#                 FLAGS = (LIST,KIDS)
#                 PRIVATE = (OUR_INTRO)
#                 {
# 6                   TYPE = gv  ===> 7
#                     FLAGS = (SCALAR)
#                 }
#             }
#         }
#     }
# }
EO_NOTHR

checkOptree:  name      => '-Dx -e print sort our @a'
              Dx        => 'print sort our @a'
              errs      => 'Name "main::a" used only once: possible typo at -e line 1.'
              noanchors => 1 # unanchored match
              expect    => << 'EO_THR', expect_nt => << 'EO_NOTHR'
{
1   TYPE = leave  ===> DONE
    TARG = 1
    FLAGS = (VOID,KIDS,PARENS)
    PRIVATE = (REFCOUNTED)
    REFCNT = 1
    {
2       TYPE = enter  ===> 3
    }
    {
3       TYPE = nextstate  ===> 4
        FLAGS = (VOID)
        LINE = 1
        PACKAGE = "main"
    }
    {
9       TYPE = print  ===> 1
        FLAGS = (VOID,KIDS)
        {
4           TYPE = pushmark  ===> 5
            FLAGS = (SCALAR)
        }
        {
8           TYPE = sort  ===> 9
            FLAGS = (LIST,KIDS)
            {
5               TYPE = pushmark  ===> 6
                FLAGS = (SCALAR)
            }
            {
7               TYPE = rv2av  ===> 8
                TARG = 2
                FLAGS = (LIST,KIDS)
                {
6                   TYPE = gv  ===> 7
                    FLAGS = (SCALAR)
                    PADIX = 1
                }
            }
        }
    }
}
EO_THR
{
1   TYPE = leave  ===> DONE
    TARG = 1
    FLAGS = (VOID,KIDS,PARENS)
    PRIVATE = (REFCOUNTED)
    REFCNT = 1
    {
2       TYPE = enter  ===> 3
    }
    {
3       TYPE = nextstate  ===> 4
        FLAGS = (VOID)
        LINE = 1
        PACKAGE = "main"
    }
    {
6       TYPE = print  ===> 1
        FLAGS = (VOID,KIDS)
        {
4           TYPE = pushmark  ===> 5
            FLAGS = (SCALAR)
        }
        {
            TYPE = null  ===> (6)
              (was rv2sv)
            FLAGS = (SCALAR,KIDS)
            {
5               TYPE = gvsv  ===> 6
                FLAGS = (SCALAR)
            }
        }
    }
}
EO_NOTHR
