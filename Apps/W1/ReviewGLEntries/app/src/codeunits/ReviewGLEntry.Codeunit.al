namespace Microsoft.Finance.GeneralLedger.Review;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Foundation.Company;
using System.Telemetry;

codeunit 22200 "Review G/L Entry" implements "G/L Entry Reviewer"
{
    Permissions = TableData "G/L Entry" = rm,
                  TableData "G/L Entry Review Setup" = ri,
#if not CLEAN27
                  TableData "G/L Entry Review Entry" = rid,
#endif
                  TableData "G/L Entry Review Log" = rid;

    var
        NoEntriesSelectedLbl: Label 'No entries were selected';
        GLAccountLbl: Label 'G/L Entries for G/L Account %1 %2 were not marked as reviewed since the G/L Account has Review Policy None', Locked = false, MaxLength = 999, Comment = '%1 is G/L Account No. and %2 is G/L Account Name';
        BalanceNotMatchingMsg: Label 'Selected G/L Entries for G/L Account %1 %2 were not marked as reviewed because credit and debit do not match and the review policy on the account enforces that', Locked = false, MaxLength = 999, Comment = '%1 is G/L Account No. and %2 is G/L Account Name';


    procedure ReviewEntries(var GLEntry: Record "G/L Entry");
    var
        GLEntryReviewLog: Record "G/L Entry Review Log";
#if not CLEAN27
        GLEntryReviewEntry: Record "G/L Entry Review Entry";
#endif
        FeatureTelemetry: Codeunit "Feature Telemetry";
        UserName: Code[50];
        Identifier: Integer;
    begin
        ValidateEntries(GLEntry);
        Identifier := GetNextIdentifier();
        UserName := CopyStr(Database.UserId(), 1, MaxStrLen(UserName));
        GLEntry.FindSet();
        repeat
            GLEntryReviewLog.Init();
            GLEntryReviewLog."G/L Entry No." := GLEntry."Entry No.";
            GLEntryReviewLog."Reviewed Identifier" := Identifier;
            GLEntryReviewLog."Reviewed By" := UserName;
            GLEntryReviewLog."Reviewed Amount" := GLEntry."Amount to Review";
            GLEntryReviewLog."G/L Account No." := GLEntry."G/L Account No.";
            GLEntryReviewLog.Insert(true);

            GLEntry."Amount to Review" := 0;
            GLEntry.Modify(true);
        until GLEntry.Next() = 0;
#if not CLEAN27
        OnAfterReviewEntries(GLEntry, GLEntryReviewEntry);
#endif

        OnAfterReviewEntriesLog(GLEntry, GLEntryReviewLog);

        FeatureTelemetry.LogUptake('0000J2W', 'Review G/L Entries', "Feature Uptake Status"::Used);
        FeatureTelemetry.LogUsage('0000KQJ', 'Review G/L Entries', 'Review G/L Entries');
    end;

    procedure UnreviewEntries(var GLEntry: Record "G/L Entry");
    var
        GLEntryReviewLog: Record "G/L Entry Review Log";
    begin
        ValidateEntries(GLEntry);
        repeat
            GLEntryReviewLog.SetRange("G/L Entry No.", GLEntry."Entry No.");
            GLEntryReviewLog.DeleteAll(true);
        until GLEntry.Next() = 0;
    end;

    procedure ValidateEntries(var GLEntry: Record "G/L Entry")
    var
        GLAccount: Record "G/L Account";
        ErrorMsg: Text;
    begin
        if GLEntry.IsEmpty() then
            Error(NoEntriesSelectedLbl);
        GLEntry.FindSet();
        GLAccount.Get(GLEntry."G/L Account No.");
        if GLAccount."Review Policy" = "G/L Account Review Policy"::None then begin
            ErrorMsg := StrSubstNo(GLAccountLbl, GLAccount."No.", GLAccount.Name);
            Error(ErrorMsg);
        end;
        if GLAccount."Review Policy" = "G/L Account Review Policy"::"Allow Review and Match Balance" then
            if not CreditDebitSumsToZero(GLEntry) then begin
                ErrorMsg := StrSubstNo(BalanceNotMatchingMsg, GLAccount."No.", GLAccount.Name);
                Error(ErrorMsg);
            end;
    end;

    local procedure CreditDebitSumsToZero(var GLEntry: Record "G/L Entry"): Boolean
    var
        Balance: Decimal;
    begin
        if not GLEntry.IsEmpty() and (GLEntry."Amount to Review" = 0) then begin
            GLEntry.CalcSums("Debit Amount", "Credit Amount");
            Balance := GLEntry."Credit Amount" - GLEntry."Debit Amount";
        end else
            repeat
                Balance := Balance + GLEntry."Amount to Review";
            until GLEntry.Next() = 0;

        exit(Balance = 0);
    end;

    local procedure GetNextIdentifier(): Integer
    var
        GLEntry: Record "G/L Entry Review Log";
    begin
        GLEntry.SetCurrentKey("Reviewed Identifier");
        GLEntry.SetAscending("Reviewed Identifier", false);
        if GLEntry.FindFirst() then
            exit(GLEntry."Reviewed Identifier" + 1);
        exit(1);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Company-Initialize", 'OnAfterInitSetupTables', '', false, false)]
    local procedure OnAfterInitSetupTables()
    var
        GLEntryReviewSetup: Record "G/L Entry Review Setup";
    begin
        if not GLEntryReviewSetup.Get() then begin
            GLEntryReviewSetup.Init();
            GLEntryReviewSetup.Insert();
        end;
    end;

#if not CLEAN27
    [Obsolete('Use the event OnAfterReviewEntriesLog instead.', '27.0')]
    [IntegrationEvent(false, false)]
    local procedure OnAfterReviewEntries(var GLEntry: Record "G/L Entry"; var GLEntryReviewEntry: Record "G/L Entry Review Entry")
    begin
    end;
#endif

    [IntegrationEvent(false, false)]
    local procedure OnAfterReviewEntriesLog(var GLEntry: Record "G/L Entry"; var GLEntryReviewLog: Record "G/L Entry Review Log")
    begin
    end;
}

