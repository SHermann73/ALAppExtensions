namespace Microsoft.PowerBIReports;

using System.Integration.PowerBI;

page 37022 "Inventory Overview"
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    PageType = UserControlHost;
    Caption = 'Inventory Overview';
    AboutTitle = 'About Inventory Overview';
    AboutText = 'The Inventory Overview report offers a dashboard view of inventory, featuring key elements such as inventory by location, a comparison of inventory balance versus projected available balance, and key metrics like scheduled receipt quantities and gross requirements.';

    layout
    {
        area(Content)
        {
            usercontrol(PowerBIAddin; PowerBIManagement)
            {
                ApplicationArea = All;

                trigger ControlAddInReady()
                begin
                    SetupHelper.InitializeEmbeddedAddin(CurrPage.PowerBIAddin, ReportId, ReportPageLbl);
                end;

                trigger ReportLoaded(ReportFilters: Text; ActivePageName: Text; ActivePageFilters: Text; CorrelationId: Text)
                begin
                    SetupHelper.LogReportLoaded(CorrelationId);
                end;

                trigger ErrorOccurred(Operation: Text; ErrorText: Text)
                begin
                    SetupHelper.LogError(Operation, ErrorText);
                    SetupHelper.ShowPowerBIErrorNotification(Operation, ErrorText);
                end;
            }
        }
    }

    var
        SetupHelper: Codeunit "Setup Helper";
        ReportId: Guid;
#pragma warning disable AA0240
        ReportPageLbl: Label 'ReportSectione24db7517a44af92f122', Locked = true;
#pragma warning restore AA0240

    trigger OnOpenPage()
    var
        PowerBIReportsSetup: Record "PowerBI Reports Setup";
    begin
        SetupHelper.EnsureUserAcceptedPowerBITerms();
        ReportId := SetupHelper.GetReportIdAndEnsureSetup(CurrPage.Caption(), PowerBIReportsSetup.FieldNo("Inventory Report Id"));
    end;
}

