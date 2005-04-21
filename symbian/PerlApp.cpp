/* Copyright (c) 2004-2005 Nokia. All rights reserved. */

/* The PerlApp application is licensed under the same terms as Perl itself. */

#include "PerlApp.h"

#include <avkon.hrh>
#include <aknnotewrappers.h> 
#include <apparc.h>
#include <e32base.h>
#include <e32cons.h>
#include <eikenv.h>
#include <bautils.h>
#include <eikappui.h>
#include <utf.h>
#include <f32file.h>

#include <AknCommonDialogs.h>

#ifndef __SERIES60_1X__
#include <CAknFileSelectionDialog.h>
#endif

#include <coemain.h>

#include "PerlApp.hrh"
#include "PerlApp.rsg"

#include "patchlevel.h"
#include "PerlBase.h"

const TUid KPerlAppUid = { 0x102015F6 };

// This is like the Symbian _LIT() but without the embedded L prefix,
// which enables using #defined constants (which need to carry their
// own L prefix).
#ifndef _LIT_NO_L
#define _LIT_NO_L(n, s) static const TLitC<sizeof(s)/2> n={sizeof(s)/2-1,s}
#endif // #ifndef _LIT_NO_L

_LIT(KAppName, "PerlApp");
_LIT_NO_L(KFlavor, PERL_SYMBIANSDK_FLAVOR);
_LIT(KAboutFormat,
     "Perl %d.%d.%d, Symbian port %d.%d.%d, built for %S SDK %d.%d");
_LIT(KCopyrightFormat,
     "Copyright 1987-2005 Larry Wall and others, Symbian port Copyright Nokia 2004-2005");
_LIT(KInboxPrefix, "\\System\\Mail\\");
_LIT(KScriptPrefix, "\\Perl\\");

_LIT8(KModulePrefix, SITELIB); // SITELIB from Perl config.h

typedef TBuf<256>  TMessageBuffer;
typedef TBuf8<256> TPeekBuffer;
typedef TBuf8<256> TFileName8;

// Usage: DEBUG_PRINTF((_L("%S"), &aStr))
#if 1
#define DEBUG_PRINTF(s) {TMessageBuffer message; message.Format s; YesNoDialogL(message);}
#endif

TUid CPerlAppApplication::AppDllUid() const
{
    return KPerlAppUid;
}

enum TPerlAppPanic 
{
    EPerlAppCommandUnknown = 1
};

void Panic(TPerlAppPanic aReason)
{
    User::Panic(KAppName, aReason);
}

void CPerlAppUi::ConstructL()
{
    BaseConstructL();
    iAppView = CPerlAppView::NewL(ClientRect());
    AddToStackL(iAppView);
    iFs = NULL;
    CEikonEnv::Static()->DisableExitChecks(ETrue); // Symbian FAQ-0577.
}

CPerlAppUi::~CPerlAppUi()
{
    if (iAppView) {
        iEikonEnv->RemoveFromStack(iAppView);
        delete iAppView;
        iAppView = NULL;
    }
    if (iFs) {
        delete iFs;
        iFs = NULL;
    }
    if (iDoorObserver) // Otherwise the embedding application waits forever.
        iDoorObserver->NotifyExit(MApaEmbeddedDocObserver::EEmpty);
}

static TBool DlgOk(CAknNoteDialog* dlg)
{
    return dlg && dlg->RunDlgLD() == EAknSoftkeyOk;
}

static TBool OkCancelDialogL(TDesC& aMessage)
{
    CAknNoteDialog* dlg =
        new (ELeave) CAknNoteDialog(CAknNoteDialog::EConfirmationTone);
    dlg->PrepareLC(R_OK_CANCEL_DIALOG);
    dlg->SetTextL(aMessage);
    return DlgOk(dlg);
}

static TBool YesNoDialogL(TDesC& aMessage)
{
    CAknNoteDialog* dlg =
        new (ELeave) CAknNoteDialog(CAknNoteDialog::EConfirmationTone);
    dlg->PrepareLC(R_YES_NO_DIALOG);
    dlg->SetTextL(aMessage);
    return DlgOk(dlg);
}

static TInt InformationNoteL(TDesC& aMessage)
{
    CAknInformationNote* note = new (ELeave) CAknInformationNote;
    return note->ExecuteLD(aMessage);
}

static TInt ConfirmationNoteL(TDesC& aMessage)
{
    CAknConfirmationNote* note = new (ELeave) CAknConfirmationNote;
    return note->ExecuteLD(aMessage);
}

static TInt WarningNoteL(TDesC& aMessage)
{
    CAknWarningNote* note = new (ELeave) CAknWarningNote;
    return note->ExecuteLD(aMessage);
}

static TInt TextQueryDialogL(const TDesC& aPrompt, TDes& aData, const TInt aMaxLength)
{
    CAknTextQueryDialog* dlg =
        new (ELeave) CAknTextQueryDialog(aData);
    dlg->SetPromptL(aPrompt);
    dlg->SetMaxLength(aMaxLength);
    return dlg->ExecuteLD(R_TEXT_QUERY_DIALOG);
}

// The isXXX() come from the Perl headers.
#define FILENAME_IS_ABSOLUTE(n) \
        (isALPHA(((n)[0])) && ((n)[1]) == ':' && ((n)[2]) == '\\')

static TBool IsInPerl(TFileName aFileName)
{
    TInt offset = aFileName.FindF(KScriptPrefix);
    return ((offset == 0 && // \foo
             aFileName[0] == '\\')
            ||
            (offset == 2 && // x:\foo
             FILENAME_IS_ABSOLUTE(aFileName)));
}

static TBool IsInInbox(TFileName aFileName)
{
    TInt offset = aFileName.FindF(KInboxPrefix);
    return ((offset == 0 && // \foo
             aFileName[0] == '\\')
            ||
            (offset == 2 && // x:\foo
             FILENAME_IS_ABSOLUTE(aFileName)));
}

static TBool IsPerlModule(TParsePtrC aParsed)
{
    return aParsed.Ext().CompareF(_L(".pm")) == 0; 
}

static TBool IsPerlScript(TParsePtrC aParsed)
{
    return aParsed.Ext().CompareF(_L(".pl")) == 0; 
}

static void CopyFromInboxL(RFs aFs, const TFileName& aSrc, const TFileName& aDst)
{
    TBool proceed = ETrue;
    TMessageBuffer message;

    message.Format(_L("%S is untrusted. Install only if you trust provider."), &aDst);
    if (OkCancelDialogL(message)) {
        message.Format(_L("Install as %S?"), &aDst);
        if (OkCancelDialogL(message)) {
            if (BaflUtils::FileExists(aFs, aDst)) {
                message.Format(_L("Replace old %S?"), &aDst);
                if (!OkCancelDialogL(message))
                    proceed = EFalse;
            }
            if (proceed) {
                // Create directory?
                TInt err = BaflUtils::CopyFile(aFs, aSrc, aDst);
                if (err == KErrNone) {
                    message.Format(_L("Installed %S"), &aDst);
                    ConfirmationNoteL(message);
                }
                else {
                    message.Format(_L("Failure %d installing %S"), err, &aDst);
                    WarningNoteL(message);
                }
            }
        }
    }
}

static TBool FindPerlPackageName(TPeekBuffer aPeekBuffer, TInt aOff, TFileName& aFn)
{
    aFn.SetMax();
    TInt m = aFn.MaxLength();
    TInt n = aPeekBuffer.Length();
    TInt i = 0;
    TInt j = aOff;

    aFn.SetMax();
    // The following is a little regular expression
    // engine that matches Perl package names.
    if (j < n && isSPACE(aPeekBuffer[j])) {
        while (j < n && isSPACE(aPeekBuffer[j])) j++;
        if (j < n && isALPHA(aPeekBuffer[j])) {
            while (j < n && isALNUM(aPeekBuffer[j])) {
                while (j < n &&
                       isALNUM(aPeekBuffer[j]) &&
                       i < m)
                    aFn[i++] = aPeekBuffer[j++];
                if (j + 1 < n &&
                    aPeekBuffer[j    ] == ':' &&
                    aPeekBuffer[j + 1] == ':' &&
                    i < m) {
                    aFn[i++] = '\\';
                    j += 2;
                    if (j < n &&
                        isALPHA(aPeekBuffer[j])) {
                        while (j < n &&
                               isALNUM(aPeekBuffer[j]) &&
                               i < m) 
                            aFn[i++] = aPeekBuffer[j++];
                    }
                }
            }
            while (j < n && isSPACE(aPeekBuffer[j])) j++;
            if (j < n && aPeekBuffer[j] == ';' && i + 3 < m) {
                aFn.SetLength(i);
                aFn.Append(_L(".pm"));
                return ETrue;
            }
        }
    }
    return EFalse;
}

static void GuessPerlModule(TFileName& aGuess, TPeekBuffer aPeekBuffer, TParse aDrive)
{
   TInt offset = aPeekBuffer.Find(_L8("package"));
   if (offset != KErrNotFound) {
       const TInt KPackageLen = 7;
       TFileName q;

       if (!FindPerlPackageName(aPeekBuffer, offset + KPackageLen, q))
           return;

       TFileName8 p;
       p.Copy(aDrive.Drive());
       p.Append(KModulePrefix);

       aGuess.SetMax();
       if (p.Length() + 1 + q.Length() < aGuess.MaxLength()) {
           TInt i = 0, j;

           for (j = 0; j < p.Length(); j++)
               aGuess[i++] = p[j];
           aGuess[i++] = '\\';
           for (j = 0; j < q.Length(); j++)
               aGuess[i++] = q[j];
           aGuess.SetLength(i);
       }
       else
           aGuess.SetLength(0);
   }
}

static TBool LooksLikePerlL(TPeekBuffer aPeekBuffer)
{
    return aPeekBuffer.Left(2).Compare(_L8("#!")) == 0 &&
           aPeekBuffer.Find(_L8("perl")) != KErrNotFound;
}

static TBool InstallStuffL(const TFileName &aSrc, TParse aDrive, TParse aFile, TPeekBuffer aPeekBuffer, RFs aFs)
{
    TFileName aDst;
    TPtrC drive  = aDrive.Drive();
    TPtrC namext = aFile.NameAndExt(); 

    aDst.Format(_L("%S%S%S"), &drive, &KScriptPrefix, &namext);
    if (!IsPerlScript(aDst) && !LooksLikePerlL(aPeekBuffer)) {
        aDst.SetLength(0);
        if (IsPerlModule(aDst))
            GuessPerlModule(aDst, aPeekBuffer, aDrive);
    }
    if (aDst.Length() > 0) {
        CopyFromInboxL(aFs, aSrc, aDst);
        return ETrue;
    }

    return EFalse;
}

static void DoRunScriptL(TFileName aScriptName)
{
    CPerlBase* perl = CPerlBase::NewInterpreterLC();
    TRAPD(error, perl->RunScriptL(aScriptName));
    if (error != KErrNone) {
        TMessageBuffer message;
        message.Format(_L("Error %d"), error);
        YesNoDialogL(message);
    }
    CleanupStack::PopAndDestroy(perl);
}

static TBool RunStuffL(const TFileName& aScriptName, TPeekBuffer aPeekBuffer)
{
    TBool isModule = EFalse;

    if (IsInPerl(aScriptName) &&
        (IsPerlScript(aScriptName) ||
         (isModule = IsPerlModule(aScriptName)) ||
         LooksLikePerlL(aPeekBuffer))) {
        TMessageBuffer message;

        if (isModule)
            message.Format(_L("Really run module %S?"), &aScriptName);
        else 
            message.Format(_L("Run %S?"), &aScriptName);
        if (YesNoDialogL(message))
            DoRunScriptL(aScriptName);

        return ETrue;
    }

    return EFalse;
}

void CPerlAppUi::InstallOrRunL(const TFileName& aFileName)
{
    TParse aFile;
    TParse aDrive;
    TMessageBuffer message;

    aFile.Set(aFileName, NULL, NULL);
    if (FILENAME_IS_ABSOLUTE(aFileName)) {
        aDrive.Set(aFileName, NULL, NULL);
    } else {
        TFileName appName =
          CEikonEnv::Static()->EikAppUi()->Application()->AppFullName();
        aDrive.Set(appName, NULL, NULL);
    }
    if (!iFs)
        iFs = &CEikonEnv::Static()->FsSession();
    RFile f;
    TInt err = f.Open(*iFs, aFileName, EFileRead);
    if (err == KErrNone) {
        TPeekBuffer aPeekBuffer;
        err = f.Read(aPeekBuffer);
        f.Close();  // Release quickly.
        if (err == KErrNone) {
            if (!(IsInInbox(aFileName) ?
                  InstallStuffL(aFileName, aDrive, aFile, aPeekBuffer, *iFs) :
                  RunStuffL(aFileName, aPeekBuffer))) {
                message.Format(_L("Failed for file %S"), &aFileName);
                WarningNoteL(message);
            }
        } else {
            message.Format(_L("Error %d reading %S"), err, &aFileName);
            WarningNoteL(message);
        }
    } else {
        message.Format(_L("Error %d opening %S"), err, &aFileName);
        WarningNoteL(message);
    }
    if (iDoorObserver)
        delete CEikonEnv::Static()->EikAppUi();
    else
        Exit();
}

void CPerlAppUi::OpenFileL(const TDesC& aFileName)
{
    InstallOrRunL(aFileName);
    return;
}

TBool CPerlAppUi::ProcessCommandParametersL(TApaCommand aCommand, TFileName& /* aDocumentName */, const TDesC8& /* aTail */)
{
    return aCommand == EApaCommandOpen ? ETrue : EFalse;
}

void CPerlAppUi::SetFs(const RFs& aFs)
{
    iFs = (RFs*) &aFs;
}

void CPerlAppUi::HandleCommandL(TInt aCommand)
{
    TMessageBuffer message;

    switch(aCommand)
    {
    case EEikCmdExit:
    case EAknSoftkeyExit:
        Exit();
        break;
    case EPerlAppCommandAbout:
        {
            message.Format(KAboutFormat,
                           PERL_REVISION,
                           PERL_VERSION,
                           PERL_SUBVERSION,
                           PERL_SYMBIANPORT_MAJOR,
                           PERL_SYMBIANPORT_MINOR,
                           PERL_SYMBIANPORT_PATCH,
                           &KFlavor,
                           PERL_SYMBIANSDK_MAJOR,
                           PERL_SYMBIANSDK_MINOR
                           );
            InformationNoteL(message);
        }
        break;
    case EPerlAppCommandTime:
        {
            CPerlBase* perl = CPerlBase::NewInterpreterLC();
            const char *const argv[] =
              { "perl", "-le",
                "print 'Running in ', $^O, \"\\n\", scalar localtime" };
            perl->ParseAndRun(sizeof(argv)/sizeof(char*), (char **)argv, 0);
            CleanupStack::PopAndDestroy(perl);
        }
        break;
     case EPerlAppCommandRunFile:
        {
            InformationNoteL(message);
            TFileName aScriptUtf16;
            if (AknCommonDialogs::RunSelectDlgLD(aScriptUtf16,
                                                 R_MEMORY_SELECTION_DIALOG))
                DoRunScriptL(aScriptUtf16);
        }
        break;
     case EPerlAppCommandOneLiner:
        {
            _LIT(prompt, "Oneliner:");
            if (TextQueryDialogL(prompt, iOneLiner, KPerlAppOneLinerSize)) {
                const TUint KPerlAppUtf8Multi = 3;
                TBuf8<KPerlAppUtf8Multi * KPerlAppOneLinerSize> utf8;

                CnvUtfConverter::ConvertFromUnicodeToUtf8(utf8, iOneLiner);
                CPerlBase* perl = CPerlBase::NewInterpreterLC();
                int argc = 3;
                char **argv = (char**) malloc(argc * sizeof(char *));
                User::LeaveIfNull(argv);

                TCleanupItem argvCleanupItem = TCleanupItem(free, argv);
                CleanupStack::PushL(argvCleanupItem);
                argv[0] = (char *) "perl";
                argv[1] = (char *) "-le";
                argv[2] = (char *) utf8.PtrZ();
                perl->ParseAndRun(argc, argv);
                CleanupStack::PopAndDestroy(2, perl);
            }
        }
        break;
     case EPerlAppCommandCopyright:
        {
            message.Format(KCopyrightFormat);
            InformationNoteL(message);
        }
        break;

    default:
        Panic(EPerlAppCommandUnknown);
        break;
    }
}

CPerlAppView* CPerlAppView::NewL(const TRect& aRect)
{
    CPerlAppView* self = CPerlAppView::NewLC(aRect);
    CleanupStack::Pop(self);
    return self;
}

CPerlAppView* CPerlAppView::NewLC(const TRect& aRect)
{
    CPerlAppView* self = new (ELeave) CPerlAppView;
    CleanupStack::PushL(self);
    self->ConstructL(aRect);
    return self;
}

void CPerlAppView::ConstructL(const TRect& aRect)
{
    CreateWindowL();
    SetRect(aRect);
    ActivateL();
}

void CPerlAppView::Draw(const TRect& /*aRect*/) const
{
    CWindowGc& gc = SystemGc();
    TRect rect = Rect();
    gc.Clear(rect);
}

CApaDocument* CPerlAppApplication::CreateDocumentL() 
{
    CPerlAppDocument* document = new (ELeave) CPerlAppDocument(*this);
    return document;
}

CEikAppUi* CPerlAppDocument::CreateAppUiL()
{
    CPerlAppUi* appui = new (ELeave) CPerlAppUi();
    return appui;
}

CFileStore* CPerlAppDocument::OpenFileL(TBool /* aDoOpen */, const TDesC& aFileName, RFs& aFs)
{
    CPerlAppUi* appui =
      STATIC_CAST(CPerlAppUi*, CEikonEnv::Static()->EikAppUi());
    appui->SetFs(aFs);
    appui->OpenFileL(aFileName);
    return NULL;
}

EXPORT_C CApaApplication* NewApplication() 
{
    return new CPerlAppApplication;
}

GLDEF_C TInt E32Dll(TDllReason /*aReason*/)
{
    return KErrNone;
}

