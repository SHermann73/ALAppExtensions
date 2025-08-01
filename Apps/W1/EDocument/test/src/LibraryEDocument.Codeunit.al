codeunit 139629 "Library - E-Document"
{
    EventSubscriberInstance = Manual;
    Permissions = tabledata "E-Document Service" = rimd,
                    tabledata "E-Doc. Service Supported Type" = rimd,
                    tabledata "E-Doc. Mapping" = rimd;

    var
        StandardItem: Record Item;
        VATPostingSetup: Record "VAT Posting Setup";
        Assert: Codeunit Assert;
        LibraryUtility: Codeunit "Library - Utility";
        LibraryWorkflow: Codeunit "Library - Workflow";
        LibrarySales: Codeunit "Library - Sales";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryERM: Codeunit "Library - ERM";
        LibraryRandom: Codeunit "Library - Random";
        LibraryInvt: Codeunit "Library - Inventory";
        LibraryJobQueue: Codeunit "Library - Job Queue";
        LibraryVariableStorage: Codeunit "Library - Variable Storage";
        LibraryFinChargeMemo: Codeunit "Library - Finance Charge Memo";
        LibraryInventory: Codeunit "Library - Inventory";

    procedure SetupStandardVAT()
    begin
        if (VATPostingSetup."VAT Bus. Posting Group" = '') and (VATPostingSetup."VAT Prod. Posting Group" = '') then
            LibraryERM.CreateVATPostingSetupWithAccounts(VATPostingSetup, Enum::"Tax Calculation Type"::"Normal VAT", 1);
    end;

#if not CLEAN26
#pragma warning disable AL0432
    [Obsolete('Use SetupStandardSalesScenario(var Customer: Record Customer; var EDocService: Record "E-Document Service"; EDocDocumentFormat: Enum "E-Document Format"; EDocIntegration: Enum "Service Integration") instead', '26.0')]
    procedure SetupStandardSalesScenario(var Customer: Record Customer; var EDocService: Record "E-Document Service"; EDocDocumentFormat: Enum "E-Document Format"; EDocIntegration: Enum "E-Document Integration")
    var
        ServiceCode: Code[20];
    begin
        // Create standard service and simple workflow
        ServiceCode := CreateService(EDocDocumentFormat, EDocIntegration);
        EDocService.Get(ServiceCode);
        SetupStandardSalesScenario(Customer, EDocService);
    end;
#pragma warning restore AL0432
#endif

    procedure SetupStandardSalesScenario(var Customer: Record Customer; var EDocService: Record "E-Document Service"; EDocDocumentFormat: Enum "E-Document Format"; EDocIntegration: Enum "Service Integration")
    var
        ServiceCode: Code[20];
    begin
        // Create standard service and simple workflow
        ServiceCode := CreateService(EDocDocumentFormat, EDocIntegration);
        EDocService.Get(ServiceCode);
        SetupStandardSalesScenario(Customer, EDocService);
    end;

    procedure SetupStandardSalesScenario(var Customer: Record Customer; var EDocService: Record "E-Document Service")
    var
        CountryRegion: Record "Country/Region";
        DocumentSendingProfile: Record "Document Sending Profile";
        SalesSetup: Record "Sales & Receivables Setup";
        WorkflowSetup: Codeunit "Workflow Setup";
        WorkflowCode: Code[20];
    begin
        LibraryWorkflow.DeleteAllExistingWorkflows();
        WorkflowSetup.InitWorkflow();
        SetupCompanyInfo();

        CreateDocSendingProfile(DocumentSendingProfile);
        WorkflowCode := CreateSimpleFlow(DocumentSendingProfile.Code, EDocService.Code);
        DocumentSendingProfile."Electronic Document" := DocumentSendingProfile."Electronic Document"::"Extended E-Document Service Flow";
        DocumentSendingProfile."Electronic Service Flow" := WorkflowCode;
        DocumentSendingProfile.Modify();

        // Create Customer for sales scenario
        LibrarySales.CreateCustomer(Customer);
        LibraryERM.FindCountryRegion(CountryRegion);
        Customer.Validate(Address, LibraryUtility.GenerateRandomCode(Customer.FieldNo(Address), DATABASE::Customer));
        Customer.Validate("Country/Region Code", CountryRegion.Code);
        Customer.Validate(City, LibraryUtility.GenerateRandomCode(Customer.FieldNo(City), DATABASE::Customer));
        Customer.Validate("Post Code", LibraryUtility.GenerateRandomCode(Customer.FieldNo("Post Code"), DATABASE::Customer));
        Customer.Validate("VAT Bus. Posting Group", VATPostingSetup."VAT Bus. Posting Group");
        Customer."VAT Registration No." := LibraryERM.GenerateVATRegistrationNo(CountryRegion.Code);
        Customer.Validate(GLN, '1234567890128');
        Customer."Document Sending Profile" := DocumentSendingProfile.Code;
        Customer.Modify(true);

        // Create Item
        if StandardItem."No." = '' then begin
            VATPostingSetup.TestField("VAT Prod. Posting Group");
            CreateGenericItem(StandardItem);
            StandardItem."VAT Prod. Posting Group" := VATPostingSetup."VAT Prod. Posting Group";
            StandardItem.Modify();
        end;

        SalesSetup.Get();
        SalesSetup."Invoice Rounding" := false;
        SalesSetup.Modify();
    end;

    procedure GetGenericItem(var Item: Record Item)
    begin
        if StandardItem."No." = '' then
            CreateGenericItem(StandardItem);
        Item.Get(StandardItem."No.");
    end;

#if not CLEAN26
#pragma warning disable AL0432
    [Obsolete('Use SetupStandardPurchaseScenario(var Vendor: Record Vendor; var EDocService: Record "E-Document Service"; EDocDocumentFormat: Enum "E-Document Format"; EDocIntegration: Enum "Service Integration") instead', '26.0')]
    procedure SetupStandardPurchaseScenario(var Vendor: Record Vendor; var EDocService: Record "E-Document Service"; EDocDocumentFormat: Enum "E-Document Format"; EDocIntegration: Enum "E-Document Integration")
    var
        ServiceCode: Code[20];
    begin
        // Create standard service and simple workflow
        if EDocService.Code = '' then begin
            ServiceCode := CreateService(EDocDocumentFormat, EDocIntegration);
            EDocService.Get(ServiceCode);
        end;
        SetupStandardPurchaseScenario(Vendor, EDocService);
    end;
#pragma warning restore AL0432
#endif

    procedure SetupStandardPurchaseScenario(var Vendor: Record Vendor; var EDocService: Record "E-Document Service"; EDocDocumentFormat: Enum "E-Document Format"; EDocIntegration: Enum "Service Integration")
    var
        ServiceCode: Code[20];
    begin
        // Create standard service and simple workflow
        if EDocService.Code = '' then begin
            ServiceCode := CreateService(EDocDocumentFormat, EDocIntegration);
            EDocService.Get(ServiceCode);
        end;
        SetupStandardPurchaseScenario(Vendor, EDocService);
    end;


    procedure SetupStandardPurchaseScenario(var Vendor: Record Vendor; var EDocService: Record "E-Document Service")
    var
        CountryRegion: Record "Country/Region";
        ItemReference: Record "Item Reference";
        UnitOfMeasure: Record "Unit of Measure";
        ExtraItem: Record "Item";
        WorkflowSetup: Codeunit "Workflow Setup";
        LibraryItemReference: Codeunit "Library - Item Reference";
    begin
        WorkflowSetup.InitWorkflow();
        SetupCompanyInfo();

        // Create Customer for sales scenario
        LibraryPurchase.CreateVendor(Vendor);
        LibraryERM.FindCountryRegion(CountryRegion);
        Vendor.Validate(Address, LibraryUtility.GenerateRandomCode(Vendor.FieldNo(Address), DATABASE::Vendor));
        Vendor.Validate("Country/Region Code", CountryRegion.Code);
        Vendor.Validate(City, LibraryUtility.GenerateRandomCode(Vendor.FieldNo(City), DATABASE::Vendor));
        Vendor.Validate("Post Code", LibraryUtility.GenerateRandomCode(Vendor.FieldNo("Post Code"), DATABASE::Vendor));
        Vendor.Validate("VAT Bus. Posting Group", VATPostingSetup."VAT Bus. Posting Group");
        Vendor."VAT Registration No." := LibraryERM.GenerateVATRegistrationNo(CountryRegion.Code);
        Vendor."Receive E-Document To" := Enum::"E-Document Type"::"Purchase Invoice";
        Vendor.Validate(GLN, '1234567890128');
        Vendor.Modify(true);

        // Create Item
        if StandardItem."No." = '' then begin
            VATPostingSetup.TestField("VAT Prod. Posting Group");
            CreateGenericItem(StandardItem, VATPostingSetup."VAT Prod. Posting Group");
        end;

        UnitOfMeasure.Init();
        UnitOfMeasure."International Standard Code" := 'PCS';
        UnitOfMeasure.Code := 'PCS';
        if UnitOfMeasure.Insert() then;

        CreateItemUnitOfMeasure(StandardItem."No.", UnitOfMeasure.Code);
        LibraryItemReference.CreateItemReference(ItemReference, StandardItem."No.", '', 'PCS', Enum::"Item Reference Type"::Vendor, Vendor."No.", '1000');

        CreateGenericItem(ExtraItem, VATPostingSetup."VAT Prod. Posting Group");
        CreateItemUnitOfMeasure(ExtraItem."No.", UnitOfMeasure.Code);
        LibraryItemReference.CreateItemReference(ItemReference, ExtraItem."No.", '', 'PCS', Enum::"Item Reference Type"::Vendor, Vendor."No.", '2000');
    end;

    procedure PostInvoice(var Customer: Record Customer) SalesInvHeader: Record "Sales Invoice Header";
    var
        SalesHeader: Record "Sales Header";
    begin
        LibraryJobQueue.SetDoNotHandleCodeunitJobQueueEnqueueEvent(true);
        CreateSalesHeaderWithItem(Customer, SalesHeader, Enum::"Sales Document Type"::Invoice);
        PostSalesDocument(SalesHeader, SalesInvHeader);
    end;

    procedure PostSalesDocument(var Customer: Record Customer; Ship: Boolean) SalesInvHeader: Record "Sales Invoice Header";
    var
        SalesHeader: Record "Sales Header";
    begin
        LibraryJobQueue.SetDoNotHandleCodeunitJobQueueEnqueueEvent(true);
        CreateSalesHeaderWithItem(Customer, SalesHeader, Enum::"Sales Document Type"::Invoice);
        PostSalesDocument(SalesHeader, SalesInvHeader, Ship);
    end;

    procedure PostSalesShipment(var Customer: Record Customer) SalesShipmentHeader: Record "Sales Shipment Header";
    var
        SalesHeader: Record "Sales Header";
    begin
        this.CreateSalesHeaderWithItem(Customer, SalesHeader, Enum::"Sales Document Type"::Order);
        SalesShipmentHeader.Get(this.LibrarySales.PostSalesDocument(SalesHeader, true, false));
    end;

    procedure RunEDocumentJobQueue(var EDocument: Record "E-Document")
    begin
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
    end;

    procedure RunImportJob()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Import Job");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);
    end;

    procedure CreateInboundEDocument(var EDocument: Record "E-Document"; EDocService: Record "E-Document Service")
    var
        EDocumentServiceStatus: Record "E-Document Service Status";
    begin
        EDocument.Insert();
        EDocumentServiceStatus."E-Document Entry No" := EDocument."Entry No";
        EDocumentServiceStatus."E-Document Service Code" := EDocService.Code;
        EDocumentServiceStatus.Insert();
    end;

    procedure MockPurchaseDraftPrepared(EDocument: Record "E-Document")
    var
        EDocumentPurchaseHeader: Record "E-Document Purchase Header";
        EDocumentProcessing: Codeunit "E-Document Processing";
    begin
        EDocumentPurchaseHeader.InsertForEDocument(EDocument);
        EDocumentPurchaseHeader."Sub Total" := 1000;
        EDocumentPurchaseHeader."Total VAT" := 100;
        EDocumentPurchaseHeader.Total := 1100;
        EDocumentPurchaseHeader.Modify();
        EDocumentProcessing.ModifyEDocumentProcessingStatus(EDocument, "Import E-Doc. Proc. Status"::"Draft Ready");
        EDocument."Document Type" := "E-Document Type"::"Purchase Invoice";
        EDocument.Modify();
    end;

    procedure CreateInboundPEPPOLDocumentToState(var EDocument: Record "E-Document"; EDocumentService: Record "E-Document Service"; FileName: Text; EDocImportParams: Record "E-Doc. Import Parameters"): Boolean
    var
        EDocImport: Codeunit "E-Doc. Import";
        InStream: InStream;
    begin
        NavApp.GetResource(FileName, InStream, TextEncoding::UTF8);
        EDocImport.CreateFromType(EDocument, EDocumentService, Enum::"E-Doc. File Format"::XML, 'TestFile', InStream);
        exit(EDocImport.ProcessIncomingEDocument(EDocument, EDocImportParams));
    end;

    /// <summary>
    /// Given a purchase header with purchase lines created from an e-document, it modifies the required fields to make it ready for posting.
    /// </summary>
    procedure EditPurchaseDocumentFromEDocumentForPosting(var PurchaseHeader: Record "Purchase Header"; var EDocument: Record "E-Document")
    var
        PurchaseLine: Record "Purchase Line";
        GLAccount: Record "G/L Account";
        GeneralPostingSetup: Record "General Posting Setup";
        GenBusinessPostingGroup: Record "Gen. Business Posting Group";
        GenProductPostingGroup: Record "Gen. Product Posting Group";
        VATBusinessPostingGroup: Record "VAT Business Posting Group";
        VATProductPostingGroup: Record "VAT Product Posting Group";
        LocalVATPostingSetup: Record "VAT Posting Setup";
    begin
        Assert.AreEqual(EDocument.SystemId, PurchaseHeader."E-Document Link", 'The purchase header has no link to the e-document.');
        LibraryERM.CreateGenBusPostingGroup(GenBusinessPostingGroup);
        LibraryERM.CreateGenProdPostingGroup(GenProductPostingGroup);
        LibraryERM.CreateGeneralPostingSetup(GeneralPostingSetup, GenBusinessPostingGroup.Code, GenProductPostingGroup.Code);
        LibraryERM.CreateVATBusinessPostingGroup(VATBusinessPostingGroup);
        LibraryERM.CreateVATProductPostingGroup(VATProductPostingGroup);
        LibraryERM.CreateVATPostingSetup(LocalVATPostingSetup, VATBusinessPostingGroup.Code, VATProductPostingGroup.Code);
        LibraryERM.CreateGLAccount(GLAccount);
        LocalVATPostingSetup."Purchase VAT Account" := GLAccount."No.";
        LocalVATPostingSetup.Modify();
        LibraryERM.CreateGLAccount(GLAccount);
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.FindSet();
        repeat
            PurchaseLine.Type := PurchaseLine.Type::"G/L Account";
            PurchaseLine."No." := GLAccount."No.";
            PurchaseLine."Gen. Bus. Posting Group" := GenBusinessPostingGroup.Code;
            PurchaseLine."Gen. Prod. Posting Group" := GenProductPostingGroup.Code;
            PurchaseLine."VAT Bus. Posting Group" := VATBusinessPostingGroup.Code;
            PurchaseLine."VAT Prod. Posting Group" := VATProductPostingGroup.Code;
            PurchaseLine.UpdateAmounts();
            PurchaseLine.Modify();
        until PurchaseLine.Next() = 0;
        PurchaseHeader.CalcFields("Amount Including VAT");
        EDocument."Amount Incl. VAT" := PurchaseHeader."Amount Including VAT";
        EDocument.Modify();
    end;

    procedure CreateDocSendingProfile(var DocumentSendingProfile: Record "Document Sending Profile")
    begin
        DocumentSendingProfile.Init();
        DocumentSendingProfile.Code := LibraryUtility.GenerateRandomCode(DocumentSendingProfile.FieldNo(Code), DATABASE::"Document Sending Profile");
        DocumentSendingProfile.Insert();
    end;


    procedure CreateSimpleFlow(DocSendingProfileCode: Code[20]; ServiceCode: Code[20]): Code[20]
    var
        Workflow: Record Workflow;
        WorkflowStepResponse: Record "Workflow Step";
        WorkflowStepArgument: Record "Workflow Step Argument";
        WorkflowStep: Record "Workflow Step";
        EDocWorkflowSetup: Codeunit "E-Document Workflow Setup";
        EDocCreatedEventID, SendEDocResponseEventID : Integer;
    begin
        // Create a simple workflow
        // Send to Service 'ServiceCode' when using Document Sending Profile 'DocSendingProfile'
        WorkflowStep.SetRange("Function Name", EDocWorkflowSetup.EDocCreated());
        WorkflowStep.SetRange("Entry Point", true);
        if WorkflowStep.FindSet() then
            repeat
                Workflow.Get(WorkflowStep."Workflow Code");
                if not Workflow.Template then
                    exit;
            until WorkflowStep.Next() = 0;

        LibraryWorkflow.CreateWorkflow(Workflow);
        EDocCreatedEventID := LibraryWorkflow.InsertEntryPointEventStep(Workflow, EDocWorkflowSetup.EDocCreated());
        SendEDocResponseEventID := LibraryWorkflow.InsertResponseStep(Workflow, EDocWorkflowSetup.EDocSendEDocResponseCode(), EDocCreatedEventID);

        WorkflowStepResponse.Get(Workflow.Code, SendEDocResponseEventID);
        WorkflowStepArgument.Get(WorkflowStepResponse.Argument);

        WorkflowStepArgument."E-Document Service" := ServiceCode;
        WorkflowStepArgument.Modify();

        LibraryWorkflow.EnableWorkflow(Workflow);
        exit(Workflow.Code);
    end;

    procedure CreateCustomerNoWithEDocSendingProfile(var DocumentSendingProfile: Code[20]): Code[20]
    var
        CustomerNo: Code[20];
    begin
        CustomerNo := LibrarySales.CreateCustomerNo();
        DocumentSendingProfile := CreateDocumentSendingProfileForWorkflow(CustomerNo, '');
        exit(CustomerNo);
    end;

    procedure CreateEDocumentFromSales(var EDocument: Record "E-Document")
    begin
        CreateEDocumentFromSales(EDocument, LibrarySales.CreateCustomerNo());
    end;

    procedure CreateEDocumentFromSales(var EDocument: Record "E-Document"; CustomerNo: Code[20])
    var
        SalesInvHeader: Record "Sales Invoice Header";
        SalesHeader: Record "Sales Header";
    begin
        LibrarySales.CreateSalesInvoiceForCustomerNo(SalesHeader, CustomerNo);
        SalesInvHeader.Get(LibrarySales.PostSalesDocument(SalesHeader, true, true));
        EDocument.FindLast();
    end;

    local procedure CreateGenericSalesHeader(var Cust: Record Customer; var SalesHeader: Record "Sales Header"; DocumentType: Enum "Sales Document Type")
    begin
        LibrarySales.CreateSalesHeader(SalesHeader, DocumentType, Cust."No.");
        SalesHeader.Validate("Your Reference", LibraryUtility.GenerateRandomCode(SalesHeader.FieldNo("Your Reference"), DATABASE::"Sales Header"));

        if DocumentType = SalesHeader."Document Type"::"Credit Memo" then
            SalesHeader.Validate("Shipment Date", WorkDate());

        SalesHeader.Modify(true);
    end;

    procedure CreateGenericItem(var Item: Record Item; VATProdPostingGroupCode: Code[20])
    begin
        CreateGenericItem(Item);
        Item."VAT Prod. Posting Group" := VATPostingSetup."VAT Prod. Posting Group";
        Item.Modify();
    end;

    procedure CreateGenericItem(var Item: Record Item)
    var
        UOM: Record "Unit of Measure";
        ItemUOM: Record "Item Unit of Measure";
        QtyPerUnit: Integer;
    begin
        QtyPerUnit := LibraryRandom.RandInt(10);

        LibraryInvt.CreateUnitOfMeasureCode(UOM);
        UOM.Validate("International Standard Code",
          LibraryUtility.GenerateRandomCode(UOM.FieldNo("International Standard Code"), DATABASE::"Unit of Measure"));
        UOM.Modify(true);

        CreateItemWithPrice(Item, LibraryRandom.RandInt(10));

        LibraryInvt.CreateItemUnitOfMeasure(ItemUOM, Item."No.", UOM.Code, QtyPerUnit);

        Item.Validate("Sales Unit of Measure", UOM.Code);
        Item.Modify(true);
    end;

    local procedure CreateItemWithPrice(var Item: Record Item; UnitPrice: Decimal)
    begin
        LibraryInvt.CreateItem(Item);
        Item."Unit Price" := UnitPrice;
        Item.Modify();
    end;

    procedure SetupCompanyInfo()
    var
        CompanyInfo: Record "Company Information";
        CountryRegion: Record "Country/Region";
    begin
        LibraryERM.FindCountryRegion(CountryRegion);

        CompanyInfo.Get();
        CompanyInfo.Validate(IBAN, 'GB33BUKB20201555555555');
        CompanyInfo.Validate("SWIFT Code", 'MIDLGB22Z0K');
        CompanyInfo.Validate("Bank Branch No.", '1234');
        CompanyInfo.Validate(Address, CopyStr(LibraryUtility.GenerateRandomXMLText(MaxStrLen(CompanyInfo.Address)), 1, MaxStrLen(CompanyInfo.Address)));
        CompanyInfo.Validate("Post Code", CopyStr(LibraryUtility.GenerateRandomXMLText(MaxStrLen(CompanyInfo."Post Code")), 1, MaxStrLen(CompanyInfo."Post Code")));
        CompanyInfo.Validate("City", CopyStr(LibraryUtility.GenerateRandomXMLText(MaxStrLen(CompanyInfo."City")), 1, MaxStrLen(CompanyInfo."Post Code")));
        CompanyInfo."Country/Region Code" := CountryRegion.Code;

        if CompanyInfo."VAT Registration No." = '' then
            CompanyInfo."VAT Registration No." := LibraryERM.GenerateVATRegistrationNo(CompanyInfo."Country/Region Code");

        CompanyInfo.Modify(true);
    end;

    procedure CreateSalesHeaderWithItem(Customer: Record Customer; var SalesHeader: Record "Sales Header"; DocumentType: Enum "Sales Document Type")
    var
        SalesLine: Record "Sales Line";
    begin
        CreateGenericSalesHeader(Customer, SalesHeader, DocumentType);

        if StandardItem."No." = '' then
            CreateGenericItem(StandardItem);

        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, StandardItem."No.", 1);
    end;

    procedure CreatePurchaseOrderWithLine(var Vendor: Record Vendor; var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; Quantity: Decimal)
    begin
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, Enum::"Purchase Document Type"::Order, Vendor."No.");
        if StandardItem."No." = '' then
            CreateGenericItem(StandardItem);
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, StandardItem."No.", Quantity);
    end;

    procedure PostSalesDocument(var SalesHeader: Record "Sales Header"; var SalesInvHeader: Record "Sales Invoice Header")
    begin
        SalesInvHeader.Get(LibrarySales.PostSalesDocument(SalesHeader, true, true));
    end;

    procedure PostSalesDocument(var SalesHeader: Record "Sales Header"; var SalesInvHeader: Record "Sales Invoice Header"; Ship: Boolean)
    begin
        SalesInvHeader.Get(LibrarySales.PostSalesDocument(SalesHeader, Ship, true));
    end;

    procedure CreateReminderWithLine(Customer: Record Customer; var ReminderHeader: Record "Reminder Header")
    var
        ReminderLine: Record "Reminder Line";
    begin
        LibraryERM.CreateReminderHeader(ReminderHeader);
        ReminderHeader.Validate("Customer No.", Customer."No.");
        ReminderHeader."Your Reference" := LibraryRandom.RandText(35);
        ReminderHeader.Modify(false);

        LibraryERM.CreateReminderLine(ReminderLine, ReminderHeader."No.", Enum::"Reminder Source Type"::"G/L Account");
        ReminderLine.Validate("Remaining Amount", this.LibraryRandom.RandInt(100));
        ReminderLine.Description := LibraryRandom.RandText(100);
        ReminderLine.Modify(false);
    end;

    procedure CreateFinChargeMemoWithLine(Customer: Record Customer; var FinChargeMemoHeader: Record "Finance Charge Memo Header")
    var
        FinChargeMemoLine: Record "Finance Charge Memo Line";
        FinanceChargeTerms: Record "Finance Charge Terms";
    begin
        LibraryERM.CreateFinanceChargeMemoHeader(FinChargeMemoHeader, Customer."No.");
        LibraryFinChargeMemo.CreateFinanceChargeTermAndText(FinanceChargeTerms);
        FinChargeMemoHeader.Validate("Fin. Charge Terms Code", FinanceChargeTerms.Code);
        FinChargeMemoHeader."Your Reference" := LibraryRandom.RandText(35);
        FinChargeMemoHeader.Modify(false);

        LibraryERM.CreateFinanceChargeMemoLine(FinChargeMemoLine, FinChargeMemoHeader."No.", FinChargeMemoLine.Type::"G/L Account");
        FinChargeMemoLine.Validate("Remaining Amount", this.LibraryRandom.RandInt(100));
        FinChargeMemoLine.Description := LibraryRandom.RandText(100);
        FinChargeMemoLine.Modify(false);
    end;

    procedure IssueReminder(Customer: Record Customer) IssuedReminderHeader: Record "Issued Reminder Header"
    var
        ReminderHeader: Record "Reminder Header";
        ReminderIssue: Codeunit "Reminder-Issue";
    begin
        CreateReminderWithLine(Customer, ReminderHeader);

        ReminderHeader.SetRange("No.", ReminderHeader."No.");
        ReminderIssue.Set(ReminderHeader, false, 0D);
        ReminderIssue.Run();

        ReminderIssue.GetIssuedReminder(IssuedReminderHeader);
    end;

    procedure IssueFinChargeMemo(Customer: Record Customer) IssuedFinChargeMemoHeader: Record "Issued Fin. Charge Memo Header"
    var
        FinChargeMemoHeader: Record "Finance Charge Memo Header";
        FinChargeMemoIssue: Codeunit "FinChrgMemo-Issue";
    begin
        CreateFinChargeMemoWithLine(Customer, FinChargeMemoHeader);

        FinChargeMemoHeader.SetRange("No.", FinChargeMemoHeader."No.");
        FinChargeMemoIssue.Set(FinChargeMemoHeader, false, 0D);
        FinChargeMemoIssue.Run();

        FinChargeMemoIssue.GetIssuedFinChrgMemo(IssuedFinChargeMemoHeader);
    end;

    procedure SetupReminderNoSeries()
    var
        SalesSetup: Record "Sales & Receivables Setup";
    begin
        SalesSetup.Get();
        SalesSetup.Validate("Reminder Nos.", this.LibraryERM.CreateNoSeriesCode());
        SalesSetup.Validate("Issued Reminder Nos.", this.LibraryERM.CreateNoSeriesCode());
        SalesSetup.Modify(false);
    end;

    procedure SetupFinChargeMemoNoSeries()
    var
        SalesSetup: Record "Sales & Receivables Setup";
    begin
        SalesSetup.Get();
        SalesSetup.Validate("Fin. Chrg. Memo Nos.", this.LibraryERM.CreateNoSeriesCode());
        SalesSetup.Validate("Issued Fin. Chrg. M. Nos.", this.LibraryERM.CreateNoSeriesCode());
        SalesSetup.Modify(false);
    end;

    procedure Initialize()
    var
        DocumentSendingProfile: Record "Document Sending Profile";
        EDocService: Record "E-Document Service";
        EDocMappingTestRec: Record "E-Doc. Mapping Test Rec";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocServiceSupportedType: Record "E-Doc. Service Supported Type";
        EDocMapping: Record "E-Doc. Mapping";
        EDocLogs: Record "E-Document Log";
        EDocMappingLogs: Record "E-Doc. Mapping Log";
        EDocDataStorage: Record "E-Doc. Data Storage";
        EDocument: Record "E-Document";
        WorkflowSetup: Codeunit "Workflow Setup";
    begin
        LibraryWorkflow.DeleteAllExistingWorkflows();
        WorkflowSetup.InitWorkflow();
        DocumentSendingProfile.DeleteAll();
        EDocService.DeleteAll();
        EDocServiceSupportedType.DeleteAll();
        EDocument.DeleteAll();
        EDocServiceStatus.DeleteAll();
        EDocDataStorage.DeleteAll();
        EDocMapping.DeleteAll();
        EDocLogs.DeleteAll();
        EDocMappingLogs.DeleteAll();
        EDocMappingTestRec.DeleteAll();
        Commit();
    end;

    procedure PostSalesDocument(CustomerNo: Code[20]): Code[20]
    var
        SalesInvHeader: Record "Sales Invoice Header";
        SalesHeader: Record "Sales Header";
    begin
        LibrarySales.CreateSalesInvoiceForCustomerNo(SalesHeader, CustomerNo);
        SalesInvHeader.Get(LibrarySales.PostSalesDocument(SalesHeader, true, true));
        exit(SalesInvHeader."No.");
    end;

    procedure PostSalesDocument(): Code[20]
    begin
        PostSalesDocument('');
    end;

    procedure CreateDocumentSendingProfileForWorkflow(CustomerNo: Code[20]; WorkflowCode: Code[20]): Code[20]
    var
        Customer: Record Customer;
        DocumentSendingProfile: Record "Document Sending Profile";
    begin
        DocumentSendingProfile.Init();
        DocumentSendingProfile.Code := LibraryUtility.GenerateRandomCode20(DocumentSendingProfile.FieldNo(Code), Database::"Document Sending Profile");
        DocumentSendingProfile."Electronic Document" := Enum::"Doc. Sending Profile Elec.Doc."::"Extended E-Document Service Flow";
        DocumentSendingProfile."Electronic Service Flow" := WorkflowCode;
        DocumentSendingProfile.Insert();

        Customer.Get(CustomerNo);
        Customer.Validate("Document Sending Profile", DocumentSendingProfile.Code);
        Customer.Modify();
        exit(DocumentSendingProfile.Code);
    end;

    procedure UpdateWorkflowOnDocumentSendingProfile(DocSendingProfile: Code[20]; WorkflowCode: Code[20])
    var
        DocumentSendingProfile: Record "Document Sending Profile";
    begin
        DocumentSendingProfile.Get(DocSendingProfile);
        DocumentSendingProfile.Validate("Electronic Service Flow", WorkflowCode);
        DocumentSendingProfile.Modify();
    end;

    procedure CreateFlowWithService(DocSendingProfile: Code[20]; ServiceCode: Code[20]): Code[20]
    var
        Workflow: Record Workflow;
        WorkflowStepResponse: Record "Workflow Step";
        WorkflowStepArgument: Record "Workflow Step Argument";
        EDocWorkflowSetup: Codeunit "E-Document Workflow Setup";
        EDocCreatedEventID, SendEDocResponseEventID : Integer;
        EventConditions: Text;
    begin
        LibraryWorkflow.CreateWorkflow(Workflow);
        EventConditions := CreateWorkflowEventConditionDocSendingProfileFilter(DocSendingProfile);

        EDocCreatedEventID := LibraryWorkflow.InsertEntryPointEventStep(Workflow, EDocWorkflowSetup.EDocCreated());
        LibraryWorkflow.InsertEventArgument(EDocCreatedEventID, EventConditions);
        SendEDocResponseEventID := LibraryWorkflow.InsertResponseStep(Workflow, EDocWorkflowSetup.EDocSendEDocResponseCode(), EDocCreatedEventID);

        WorkflowStepResponse.Get(Workflow.Code, SendEDocResponseEventID);
        WorkflowStepArgument.Get(WorkflowStepResponse.Argument);

        WorkflowStepArgument.Validate("E-Document Service", ServiceCode);
        WorkflowStepArgument.Modify();

        LibraryWorkflow.EnableWorkflow(Workflow);
        exit(Workflow.Code);
    end;

    procedure CreateEmptyFlow(): Code[20]
    var
        Workflow: Record Workflow;
        EDocWorkflowSetup: Codeunit "E-Document Workflow Setup";
        EDocCreatedEventID: Integer;
    begin
        LibraryWorkflow.CreateWorkflow(Workflow);
        EDocCreatedEventID := LibraryWorkflow.InsertEntryPointEventStep(Workflow, EDocWorkflowSetup.EDocCreated());
        LibraryWorkflow.InsertResponseStep(Workflow, EDocWorkflowSetup.EDocSendEDocResponseCode(), EDocCreatedEventID);

        LibraryWorkflow.EnableWorkflow(Workflow);
        exit(Workflow.Code);
    end;

    procedure CreateFlowWithServices(DocSendingProfile: Code[20]; ServiceCodeA: Code[20]; ServiceCodeB: Code[20]): Code[20]
    var
        Workflow: Record Workflow;
        WorkflowStepResponse: Record "Workflow Step";
        WorkflowStepArgument: Record "Workflow Step Argument";
        EDocWorkflowSetup: Codeunit "E-Document Workflow Setup";
        EDocCreatedEventID, SendEDocResponseEventIDA, SendEDocResponseEventIDB : Integer;
        EventConditionsDocProfile, EventConditionsService : Text;
    begin
        LibraryWorkflow.CreateWorkflow(Workflow);
        EventConditionsDocProfile := CreateWorkflowEventConditionDocSendingProfileFilter(DocSendingProfile);
        EventConditionsService := CreateWorkflowEventConditionServiceFilter(ServiceCodeA);

        EDocCreatedEventID := LibraryWorkflow.InsertEntryPointEventStep(Workflow, EDocWorkflowSetup.EDocCreated());
        LibraryWorkflow.InsertEventArgument(EDocCreatedEventID, EventConditionsDocProfile);
        SendEDocResponseEventIDA := LibraryWorkflow.InsertResponseStep(Workflow, EDocWorkflowSetup.EDocSendEDocResponseCode(), EDocCreatedEventID);
        SendEDocResponseEventIDB := LibraryWorkflow.InsertResponseStep(Workflow, EDocWorkflowSetup.EDocSendEDocResponseCode(), SendEDocResponseEventIDA);

        WorkflowStepResponse.Get(Workflow.Code, SendEDocResponseEventIDA);
        WorkflowStepArgument.Get(WorkflowStepResponse.Argument);
        WorkflowStepArgument."E-Document Service" := ServiceCodeA;
        WorkflowStepArgument.Modify();

        WorkflowStepResponse.Get(Workflow.Code, SendEDocResponseEventIDB);
        WorkflowStepArgument.Get(WorkflowStepResponse.Argument);
        WorkflowStepArgument."E-Document Service" := ServiceCodeB;
        WorkflowStepArgument.Modify();

        LibraryWorkflow.EnableWorkflow(Workflow);
        exit(Workflow.Code);
    end;

    local procedure DeleteEDocumentRelatedEntities()
    var
        DynamicRequestPageEntity: Record "Dynamic Request Page Entity";
    begin
        DynamicRequestPageEntity.SetRange("Table ID", DATABASE::"E-Document");
        DynamicRequestPageEntity.DeleteAll(true);
    end;

    local procedure CreateWorkflowEventConditionDocSendingProfileFilter(DocSendingProfile: Code[20]): Text
    var
        RequestPageParametersHelper: Codeunit "Request Page Parameters Helper";
        FilterPageBuilder: FilterPageBuilder;
        EntityName: Code[20];
    begin
        EntityName := CreateDynamicRequestPageEntity(DATABASE::"E-Document", Database::"Document Sending Profile");
        CreateEDocumentDocSendingProfileDataItem(FilterPageBuilder, DocSendingProfile);
        exit(RequestPageParametersHelper.GetViewFromDynamicRequestPage(FilterPageBuilder, EntityName, Database::"E-Document"));
    end;

    local procedure CreateWorkflowEventConditionServiceFilter(ServiceCode: Code[20]): Text
    var
        RequestPageParametersHelper: Codeunit "Request Page Parameters Helper";
        FilterPageBuilder: FilterPageBuilder;
        EntityName: Code[20];
    begin
        EntityName := CreateDynamicRequestPageEntity(DATABASE::"E-Document", Database::"E-Document Service");
        CreateEDocServiceDataItem(FilterPageBuilder, ServiceCode);
        exit(RequestPageParametersHelper.GetViewFromDynamicRequestPage(FilterPageBuilder, EntityName, Database::"E-Document Service"));
    end;

    local procedure CreateEDocumentDocSendingProfileDataItem(var FilterPageBuilder: FilterPageBuilder; DocumentSendingProfile: Code[20])
    var
        EDocument: Record "E-Document";
        EDocumentDataItem: Text;
    begin
        EDocumentDataItem := FilterPageBuilder.AddTable(EDocument.TableCaption, DATABASE::"E-Document");
        FilterPageBuilder.AddField(EDocumentDataItem, EDocument."Document Sending Profile", DocumentSendingProfile);
    end;

    local procedure CreateEDocServiceDataItem(var FilterPageBuilder: FilterPageBuilder; ServiceCode: Code[20])
    var
        EDocService: Record "E-Document Service";
        EDocumentDataItem: Text;
    begin
        EDocumentDataItem := FilterPageBuilder.AddTable(EDocService.TableCaption, DATABASE::"E-Document Service");
        FilterPageBuilder.AddField(EDocumentDataItem, EDocService.Code, ServiceCode);
    end;

    local procedure CreateDynamicRequestPageEntity(TableID: Integer; RelatedTable: Integer): Code[20]
    var
        EntityName: Code[20];
    begin
        DeleteEDocumentRelatedEntities();
        EntityName := LibraryUtility.GenerateGUID();
        LibraryWorkflow.CreateDynamicRequestPageEntity(EntityName, TableID, RelatedTable);
        exit(EntityName);
    end;

#if not CLEAN26
#pragma warning disable AL0432
    [Obsolete('Use CreateService(EDocDocumentFormat: Enum "E-Document Format"; EDocIntegration: Enum "Service Integration") instead', '26.0')]
    procedure CreateService(Integration: Enum "E-Document Integration"): Code[20]
    var
        EDocService: Record "E-Document Service";
    begin
        EDocService.Init();
        EDocService.Code := LibraryUtility.GenerateRandomCode20(EDocService.FieldNo(Code), Database::"E-Document Service");
        EDocService."Document Format" := "E-Document Format"::Mock;
        EDocService."Service Integration" := Integration;
        EDocService.Insert();

        CreateSupportedDocTypes(EDocService);

        exit(EDocService.Code);
    end;
#pragma warning restore AL0432
#endif

    procedure CreateService(Integration: Enum "Service Integration"): Code[20]
    var
        EDocService: Record "E-Document Service";
    begin
        EDocService.Init();
        EDocService.Code := LibraryUtility.GenerateRandomCode20(EDocService.FieldNo(Code), Database::"E-Document Service");
        EDocService."Document Format" := "E-Document Format"::Mock;
        EDocService."Service Integration V2" := Integration;
        EDocService.Insert();

        CreateSupportedDocTypes(EDocService);

        exit(EDocService.Code);
    end;

#if not CLEAN26
#pragma warning disable AL0432
    [Obsolete('Use CreateService(EDocDocumentFormat: Enum "E-Document Format"; EDocIntegration: Enum "Service Integration") instead', '26.0')]
    procedure CreateService(EDocDocumentFormat: Enum "E-Document Format"; EDocIntegration: Enum "E-Document Integration"): Code[20]
    var
        EDocService: Record "E-Document Service";
    begin
        EDocService.Init();
        EDocService.Code := LibraryUtility.GenerateRandomCode20(EDocService.FieldNo(Code), Database::"E-Document Service");
        EDocService."Document Format" := EDocDocumentFormat;
        EDocService."Service Integration" := EDocIntegration;
        EDocService.Insert();

        CreateSupportedDocTypes(EDocService);

        exit(EDocService.Code);
    end;
#pragma warning restore AL0432
#endif

    procedure CreateService(EDocDocumentFormat: Enum "E-Document Format"; EDocIntegration: Enum "Service Integration"): Code[20]
    var
        EDocService: Record "E-Document Service";
    begin
        EDocService.Init();
        EDocService.Code := LibraryUtility.GenerateRandomCode20(EDocService.FieldNo(Code), Database::"E-Document Service");
        EDocService."Document Format" := EDocDocumentFormat;
        EDocService."Service Integration V2" := EDocIntegration;
        EDocService.Insert();

        CreateSupportedDocTypes(EDocService);

        exit(EDocService.Code);
    end;


    procedure CreateServiceMapping(EDocService: Record "E-Document Service")
    var
        TransformationRule: Record "Transformation Rule";
        EDocMapping: Record "E-Doc. Mapping";
        SalesInvHeader: Record "Sales Invoice Header";
    begin
        TransformationRule.Get(TransformationRule.GetLowercaseCode());
        // Lower case mapping
        CreateTransformationMapping(EDocMapping, TransformationRule, EDocService.Code);
        EDocMapping."Table ID" := Database::"Sales Invoice Header";
        EDocMapping."Field ID" := SalesInvHeader.FieldNo("Bill-to Name");
        EDocMapping.Modify();
        CreateTransformationMapping(EDocMapping, TransformationRule, EDocService.Code);
        EDocMapping."Table ID" := Database::"Sales Invoice Header";
        EDocMapping."Field ID" := SalesInvHeader.FieldNo("Bill-to Address");
        EDocMapping.Modify();
    end;

    procedure DeleteServiceMapping(EDocService: Record "E-Document Service")
    var
        EDocMapping: Record "E-Doc. Mapping";
    begin
        EDocMapping.SetRange(Code, EDocService.Code);
        EDocMapping.DeleteAll();
    end;


    // procedure CreateServiceWithMapping(var EDocMapping: Record "E-Doc. Mapping"; TransformationRule: Record "Transformation Rule"; Integration: Enum "E-Document Integration"): Code[20]
    // begin
    //     exit(CreateServiceWithMapping(EDocMapping, TransformationRule, false, Integration));
    // end;

    // procedure CreateServiceWithMapping(var EDocMapping: Record "E-Doc. Mapping"; TransformationRule: Record "Transformation Rule"; UseBatching: Boolean; Integration: Enum "E-Document Integration"): Code[20]
    // var
    //     SalesInvHeader: Record "Sales Invoice Header";
    //     EDocService: Record "E-Document Service";
    // begin
    //     EDocService.Init();
    //     EDocService.Code := LibraryUtility.GenerateRandomCode20(EDocService.FieldNo(Code), Database::"E-Document Service");
    //     EDocService."Document Format" := "E-Document Format"::Mock;
    //     EDocService."Service Integration" := Integration;
    //     EDocService."Use Batch Processing" := UseBatching;
    //     EDocService.Insert();

    //     CreateSupportedDocTypes(EDocService);

    //     // Lower case mapping
    //     CreateTransformationMapping(EDocMapping, TransformationRule, EDocService.Code);
    //     EDocMapping."Table ID" := Database::"Sales Invoice Header";
    //     EDocMapping."Field ID" := SalesInvHeader.FieldNo("Bill-to Name");
    //     EDocMapping.Modify();
    //     CreateTransformationMapping(EDocMapping, TransformationRule, EDocService.Code);
    //     EDocMapping."Table ID" := Database::"Sales Invoice Header";
    //     EDocMapping."Field ID" := SalesInvHeader.FieldNo("Bill-to Address");
    //     EDocMapping.Modify();

    //     exit(EDocService.Code);
    // end;

    procedure CreateSupportedDocTypes(EDocService: Record "E-Document Service")
    var
        EDocServiceSupportedType: Record "E-Doc. Service Supported Type";
    begin
        EDocServiceSupportedType.Init();
        EDocServiceSupportedType."E-Document Service Code" := EDocService.Code;
        EDocServiceSupportedType."Source Document Type" := EDocServiceSupportedType."Source Document Type"::"Sales Invoice";
        EDocServiceSupportedType.Insert();

        EDocServiceSupportedType."Source Document Type" := EDocServiceSupportedType."Source Document Type"::"Sales Credit Memo";
        EDocServiceSupportedType.Insert();

        EDocServiceSupportedType."Source Document Type" := EDocServiceSupportedType."Source Document Type"::"Service Invoice";
        EDocServiceSupportedType.Insert();

        EDocServiceSupportedType."Source Document Type" := EDocServiceSupportedType."Source Document Type"::"Service Credit Memo";
        EDocServiceSupportedType.Insert();

        EDocServiceSupportedType."Source Document Type" := EDocServiceSupportedType."Source Document Type"::"Issued Finance Charge Memo";
        EDocServiceSupportedType.Insert();

        EDocServiceSupportedType."Source Document Type" := EDocServiceSupportedType."Source Document Type"::"Issued Reminder";
        EDocServiceSupportedType.Insert();
    end;

    procedure AddEDocServiceSupportedType(EDocService: Record "E-Document Service"; EDocumentType: Enum "E-Document Type")
    var
        EDocServiceSupportedType: Record "E-Doc. Service Supported Type";
    begin
        if not EDocService.Get(EDocService.Code) then
            exit;

        EDocServiceSupportedType.Init();
        EDocServiceSupportedType."E-Document Service Code" := EDocService.Code;
        EDocServiceSupportedType."Source Document Type" := EDocumentType;
        if EDocServiceSupportedType.Insert() then;
    end;

    procedure CreateTestReceiveServiceForEDoc(var EDocService: Record "E-Document Service"; Integration: Enum "Service Integration")
    begin
        if not EDocService.Get('TESTRECEIVE') then begin
            EDocService.Init();
            EDocService.Code := 'TESTRECEIVE';
            EDocService."Document Format" := "E-Document Format"::Mock;
            EDocService."Service Integration V2" := Integration;
            EDocService.Insert();
        end;
    end;

#if not CLEAN26
#pragma warning disable AL0432
    [Obsolete('Use CreateTestReceiveServiceForEDoc(var EDocService: Record "E-Document Service"; Integration: Enum "Service Integration") instead', '26.0')]
    procedure CreateTestReceiveServiceForEDoc(var EDocService: Record "E-Document Service"; Integration: Enum "E-Document Integration")
    begin
        if not EDocService.Get('TESTRECEIVE') then begin
            EDocService.Init();
            EDocService.Code := 'TESTRECEIVE';
            EDocService."Document Format" := "E-Document Format"::Mock;
            EDocService."Service Integration" := Integration;
            EDocService.Insert();
        end;
    end;
#pragma warning restore AL0432
#endif

    procedure CreateGetBasicInfoErrorReceiveServiceForEDoc(var EDocService: Record "E-Document Service"; Integration: Enum "Service Integration")
    begin
        if not EDocService.Get('BIERRRECEIVE') then begin
            EDocService.Init();
            EDocService.Code := 'BIERRRECEIVE';
            EDocService."Document Format" := "E-Document Format"::Mock;
            EDocService."Service Integration V2" := Integration;
            EDocService.Insert();
        end;
    end;

#if not CLEAN26
#pragma warning disable AL0432
    [Obsolete('Use CreateGetBasicInfoErrorReceiveServiceForEDoc(var EDocService: Record "E-Document Service"; Integration: Enum "Service Integration") instead', '26.0')]
    procedure CreateGetBasicInfoErrorReceiveServiceForEDoc(var EDocService: Record "E-Document Service"; Integration: Enum "E-Document Integration")
    begin
        if not EDocService.Get('BIERRRECEIVE') then begin
            EDocService.Init();
            EDocService.Code := 'BIERRRECEIVE';
            EDocService."Document Format" := "E-Document Format"::Mock;
            EDocService."Service Integration" := Integration;
            EDocService.Insert();
        end;
    end;
#pragma warning restore AL0432
#endif

    procedure CreateGetCompleteInfoErrorReceiveServiceForEDoc(var EDocService: Record "E-Document Service"; Integration: Enum "Service Integration")
    begin
        if not EDocService.Get('CIERRRECEIVE') then begin
            EDocService.Init();
            EDocService.Code := 'CIERRRECEIVE';
            EDocService."Document Format" := "E-Document Format"::Mock;
            EDocService."Service Integration V2" := Integration;
            EDocService.Insert();
        end;
    end;

#if not CLEAN26
#pragma warning disable AL0432
    [Obsolete('Use CreateGetCompleteInfoErrorReceiveServiceForEDoc(var EDocService: Record "E-Document Service"; Integration: Enum "Service Integration") instead', '26.0')]
    procedure CreateGetCompleteInfoErrorReceiveServiceForEDoc(var EDocService: Record "E-Document Service"; Integration: Enum "E-Document Integration")
    begin
        if not EDocService.Get('CIERRRECEIVE') then begin
            EDocService.Init();
            EDocService.Code := 'CIERRRECEIVE';
            EDocService."Document Format" := "E-Document Format"::Mock;
            EDocService."Service Integration" := Integration;
            EDocService.Insert();
        end;
    end;
#pragma warning restore AL0432
#endif

    procedure CreateDirectMapping(var EDocMapping: Record "E-Doc. Mapping"; EDocService: Record "E-Document Service"; FindValue: Text; ReplaceValue: Text)
    begin
        CreateDirectMapping(EDocMapping, EDocService, FindValue, ReplaceValue, 0, 0);
    end;

    procedure CreateTransformationMapping(var EDocMapping: Record "E-Doc. Mapping"; TransformationRule: Record "Transformation Rule")
    begin
        CreateTransformationMapping(EDocMapping, TransformationRule, '');
    end;

    procedure CreateTransformationMapping(var EDocMapping: Record "E-Doc. Mapping"; TransformationRule: Record "Transformation Rule"; ServiceCode: Code[20])
    begin
        EDocMapping.Init();
        EDocMapping.Code := ServiceCode;
        EDocMapping."Entry No." := 0;
        EDocMapping."Transformation Rule" := TransformationRule.Code;
        EDocMapping.Insert();
    end;

    procedure CreateDirectMapping(var EDocMapping: Record "E-Doc. Mapping"; EDocService: Record "E-Document Service"; FindValue: Text; ReplaceValue: Text; TableId: Integer; FieldId: Integer)
    begin
        EDocMapping.Init();
        EDocMapping."Entry No." := 0;
        EDocMapping.Code := EDocService.Code;
        EDocMapping."Table ID" := TableId;
        EDocMapping."Field ID" := FieldId;
        EDocMapping."Find Value" := CopyStr(FindValue, 1, LibraryUtility.GetFieldLength(DATABASE::"E-Doc. Mapping", EDocMapping.FieldNo("Find Value")));
        EDocMapping."Replace Value" := CopyStr(ReplaceValue, 1, LibraryUtility.GetFieldLength(DATABASE::"E-Doc. Mapping", EDocMapping.FieldNo("Replace Value")));
        EDocMapping.Insert();
    end;

    local procedure CreateItemUnitOfMeasure(ItemNo: Code[20]; UnitOfMeasureCode: Code[10])
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        ItemUnitOfMeasure.Init();
        ItemUnitOfMeasure.Validate("Item No.", ItemNo);
        ItemUnitOfMeasure.Validate(Code, UnitOfMeasureCode);
        ItemUnitOfMeasure."Qty. per Unit of Measure" := 1;
        if ItemUnitOfMeasure.Insert() then;
    end;

    procedure TempBlobToTxt(var TempBlob: Codeunit "Temp Blob"): Text
    var
        InStr: InStream;
        Content: Text;
    begin
        TempBlob.CreateInStream(InStr);
        InStr.Read(Content);
        exit(Content);
    end;

    internal procedure CreateLocationsWithPostingSetups(
        var FromLocation: Record Location;
        var ToLocation: Record Location;
        var InTransitLocation: Record Location;
        var InventoryPostingGroup: Record "Inventory Posting Group")
    var
        InventoryPostingSetupFromLocation: Record "Inventory Posting Setup";
        InventoryPostingSetupToLocation: Record "Inventory Posting Setup";
        InventoryPostingSetupInTransitLocation: Record "Inventory Posting Setup";
        LibraryWarehouse: Codeunit "Library - Warehouse";
    begin
        LibraryWarehouse.CreateLocation(FromLocation);
        LibraryWarehouse.CreateLocation(ToLocation);
        LibraryWarehouse.CreateInTransitLocation(InTransitLocation);

        LibraryInventory.CreateInventoryPostingGroup(InventoryPostingGroup);
        LibraryInventory.CreateInventoryPostingSetup(InventoryPostingSetupFromLocation, FromLocation.Code, InventoryPostingGroup.Code);
        LibraryInventory.UpdateInventoryPostingSetup(FromLocation, InventoryPostingGroup.Code);

        InventoryPostingSetupFromLocation.Get(FromLocation.Code, InventoryPostingGroup.Code);
        InventoryPostingSetupToLocation := InventoryPostingSetupFromLocation;
        InventoryPostingSetupToLocation."Location Code" := ToLocation.Code;
        InventoryPostingSetupToLocation.Insert(false);

        InventoryPostingSetupInTransitLocation := InventoryPostingSetupFromLocation;
        InventoryPostingSetupInTransitLocation."Location Code" := InTransitLocation.Code;
        InventoryPostingSetupInTransitLocation.Insert(false);
    end;

    internal procedure CreateItemWithInventoryPostingGroup(var Item: Record Item; InventoryPostingGroupCode: Code[20])
    begin
        LibraryInventory.CreateItem(Item);
        Item."Inventory Posting Group" := InventoryPostingGroupCode;
        Item.Modify(false);
    end;

    internal procedure CreateItemWIthInventoryStock(var Item: Record Item; var FromLocation: Record Location; var InventoryPostingGroup: Record "Inventory Posting Group")
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        CreateItemWithInventoryPostingGroup(Item, InventoryPostingGroup.Code);
        LibraryInventory.CreateItemJournalLineInItemTemplate(
          ItemJournalLine, Item."No.", FromLocation.Code, '', LibraryRandom.RandIntInRange(10, 20));
        LibraryInventory.PostItemJournalLine(
          ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");
    end;

    // Verify procedures

    procedure AssertEDocumentLogs(EDocument: Record "E-Document"; EDocumentService: Record "E-Document Service"; EDocLogList: List of [Enum "E-Document Service Status"])
    var
        EDocLog: Record "E-Document Log";
        Count: Integer;
    begin
        EDocLog.SetRange("E-Doc. Entry No", EDocument."Entry No");
        EDocLog.SetRange("Service Code", EDocumentService.Code);
        Assert.AreEqual(EDocLogList.Count(), EDocLog.Count(), 'Wrong number of logs');
        Count := 1;
        EDocLog.SetCurrentKey("Entry No.");
        EDocLog.SetAscending("Entry No.", true);
        if EDocLog.FindSet() then
            repeat
                Assert.AreEqual(EDocLogList.Get(Count), EDocLog.Status, 'Wrong status');
                Count := Count + 1;
            until EDocLog.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Export", 'OnAfterCreateEDocument', '', false, false)]
    local procedure OnAfterCreateEDocument(var EDocument: Record "E-Document")
    begin
        LibraryVariableStorage.Enqueue(EDocument);
    end;

}