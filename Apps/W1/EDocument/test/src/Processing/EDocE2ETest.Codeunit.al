codeunit 139624 "E-Doc E2E Test"
{
    Subtype = Test;
    TestType = Uncategorized;
    EventSubscriberInstance = Manual;

    var
        Customer: Record Customer;
        EDocumentService: Record "E-Document Service";
        Assert: Codeunit Assert;
        LibraryVariableStorage: Codeunit "Library - Variable Storage";
        LibraryEDoc: Codeunit "Library - E-Document";
        LibraryWorkflow: codeunit "Library - Workflow";
        LibraryJobQueue: Codeunit "Library - Job Queue";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryInventory: Codeunit "Library - Inventory";
        EDocImplState: Codeunit "E-Doc. Impl. State";
        LibraryLowerPermission: Codeunit "Library - Lower Permissions";
        IsInitialized: Boolean;
        IncorrectValueErr: Label 'Incorrect value found';
        DocumentSendingProfileWithWorkflowErr: Label 'Workflow %1 defined for %2 in Document Sending Profile %3 is not found.', Comment = '%1 - The workflow code, %2 - Enum value set in Electronic Document, %3 - Document Sending Profile Code';
        FailedToGetBlobErr: Label 'Failed to get exported blob from EDocument %1', Comment = '%1 - E-Document No.';
        SendingErrStateErr: Label 'E-document is Pending response and can not be sent in this state.';
        DeleteProcessedNotAllowedErr: Label 'The E-Document has already been processed and cannot be deleted.';

    [Test]
    procedure CreateEDocumentBeforeAfterEventsSuccessful()
    var
        SalesInvHeader: Record "Sales Invoice Header";
        EDocument: Record "E-Document";
        Variant: Variant;
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Check OnBeforeCreatedEDocument and OnAfterCreatedEDocument called successful

        // [GIVEN] SETUP
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        LibraryVariableStorage.AssertEmpty();
        EDocImplState.SetVariableStorage(LibraryVariableStorage);

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        SalesInvHeader := LibraryEDoc.PostInvoice(Customer);

        // [THEN] OnBeforeCreatedEDocument is fired and edocument is empty
        EDocImplState.GetVariableStorage(LibraryVariableStorage);
        Assert.AreEqual(2, LibraryVariableStorage.Length(), IncorrectValueErr);
        LibraryVariableStorage.Dequeue(Variant);
        EDocument := Variant;
        Assert.AreEqual('', EDocument."Document No.", 'OnBeforeCreatedEDocument should give empty edocument');

        // [THEN] OnAfterCreatedEDocument event is fired and edocument is populated
        LibraryVariableStorage.Dequeue(Variant);
        EDocument := Variant;
        Assert.AreEqual(SalesInvHeader."No.", EDocument."Document No.", IncorrectValueErr);
        Assert.AreEqual(SalesInvHeader.RecordId, EDocument."Document Record ID", IncorrectValueErr);
        Assert.AreEqual(SalesInvHeader."Posting Date", EDocument."Posting Date", IncorrectValueErr);
        Assert.AreEqual(SalesInvHeader."Document Date", EDocument."Document Date", IncorrectValueErr);
        Assert.AreEqual(EDocument."Source Type"::Customer, EDocument."Source Type", IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::"In Progress", EDocument.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure CheckEDocumentUnitSucccess()
    var
        SalesHeader, SalesHeader2 : Record "Sales Header";
        EDocService: Record "E-Document Service";
        EDocExport: Codeunit "E-Doc. Export";
        RecordRef: RecordRef;
        EDocProcessingPhase: Enum "E-Document Processing Phase";
        EDocProcessingPhaseInt: Integer;
        Variant: Variant;
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Check that CheckEDocument is successfull

        // [GIVEN] Creating a document and posting it with simple flow setup
        Initialize(Enum::"Service Integration"::"Mock");
        EDocImplState.EnableOnCheckEvent();
        BindSubscription(EDocImplState);
        LibraryVariableStorage.AssertEmpty();
        EDocImplState.SetVariableStorage(LibraryVariableStorage);

        // [WHEN] Team member create invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.CreateSalesHeaderWithItem(Customer, SalesHeader, Enum::"Sales Document Type"::Invoice);
        RecordRef.GetTable(SalesHeader);

        // [WEHN] Check E-Document is called
        EDocExport.CheckEDocument(RecordRef, Enum::"E-Document Processing Phase"::Create);

        EDocImplState.GetVariableStorage(LibraryVariableStorage);
        Assert.AreEqual(3, LibraryVariableStorage.Length(), IncorrectValueErr);

        LibraryVariableStorage.Dequeue(Variant);
        SalesHeader2 := Variant;
        LibraryVariableStorage.Dequeue(Variant);
        EDocService := Variant;
        LibraryVariableStorage.Dequeue(Variant);
        EDocProcessingPhaseInt := Variant;
        EDocProcessingPhase := EDocProcessingPhaseInt;

        // [THEN] EDocService that was created by test for flow, is the one that is provided by event

        Assert.AreEqual(EDocService.Code, EDocumentService.Code, IncorrectValueErr);

        // [THEN] Sales Header that we created is the one that is provided by event
        Assert.AreEqual(SalesHeader."No.", SalesHeader2."No.", IncorrectValueErr);

        // [THEN] "E-Document Processing Phase" is provided by event
        Assert.AreEqual(Enum::"E-Document Processing Phase"::Create, EDocProcessingPhase, IncorrectValueErr);
        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure CheckEDocumentMultiServiceUnitSucccess()
    var
        SalesHeader: Record "Sales Header";
        EDocService: Record "E-Document Service";
        DocumentSendingProfile: Record "Document Sending Profile";
        EDocExport: Codeunit "E-Doc. Export";
        RecordRef: RecordRef;
        Variant: Variant;
        EDocServiceA, EDocServiceB, WorkflowCode : Code[20];
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Check that CheckEDocument is successfull for multiple services

        // [GIVEN] Creating a document and posting it with multi service flow setup
        Initialize(Enum::"Service Integration"::"Mock");
        LibraryWorkflow.DisableAllWorkflows();
        EDocServiceA := LibraryEDoc.CreateService(Enum::"Service Integration"::"Mock");
        EDocServiceB := LibraryEDoc.CreateService(Enum::"Service Integration"::"Mock");
        LibraryEDoc.CreateDocSendingProfile(DocumentSendingProfile);
        WorkflowCode := LibraryEDoc.CreateFlowWithServices(DocumentSendingProfile.Code, EDocServiceA, EDocServiceB);
        DocumentSendingProfile."Electronic Document" := DocumentSendingProfile."Electronic Document"::"Extended E-Document Service Flow";
        DocumentSendingProfile."Electronic Service Flow" := WorkflowCode;
        DocumentSendingProfile.Modify();
        Customer."Document Sending Profile" := DocumentSendingProfile.Code;
        Customer.Modify();

        EDocImplState.EnableOnCheckEvent();
        BindSubscription(EDocImplState);
        LibraryVariableStorage.AssertEmpty();
        EDocImplState.SetVariableStorage(LibraryVariableStorage);

        // [WHEN] Team member create invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.CreateSalesHeaderWithItem(Customer, SalesHeader, Enum::"Sales Document Type"::Invoice);
        RecordRef.GetTable(SalesHeader);

        // [WEHN] Check E-Document is called
        EDocExport.CheckEDocument(RecordRef, Enum::"E-Document Processing Phase"::Create);

        EDocImplState.GetVariableStorage(LibraryVariableStorage);
        Assert.AreEqual(6, LibraryVariableStorage.Length(), IncorrectValueErr);

        // [THEN] EDocServices that was created by test for flow, is the one that is provided in event
        LibraryVariableStorage.Peek(Variant, 2);
        EDocService := Variant;
        Assert.AreEqual(EDocService.Code, EDocServiceA, IncorrectValueErr);

        LibraryVariableStorage.Peek(Variant, 5);
        EDocService := Variant;
        Assert.AreEqual(EDocService.Code, EDocServiceB, IncorrectValueErr);
        UnbindSubscription(EDocImplState);

        LibraryLowerPermission.SetOutsideO365Scope();
        LibraryWorkflow.DisableAllWorkflows();
        LibraryWorkflow.DeleteAllExistingWorkflows();
        EDocService.SetFilter(Code, '%1|%2', EDocServiceA, EDocServiceB);
        EDocService.DeleteAll();
        IsInitialized := false;
    end;

    [Test]
    procedure CreateEDocumentFailureNoWorkflow()
    var
        DocumentSendingProfile: Record "Document Sending Profile";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Check that error is thrown if Document sending profile is defined without Workflow Code

        // [GIVEN] E document is created when posting document with incorrectly setup document sending profile
        Initialize(Enum::"Service Integration"::"Mock");
        LibraryEDoc.CreateDocSendingProfile(DocumentSendingProfile);
        DocumentSendingProfile."Electronic Document" := DocumentSendingProfile."Electronic Document"::"Extended E-Document Service Flow";
        DocumentSendingProfile."Electronic Service Flow" := 'NON-WORKFLOW';
        DocumentSendingProfile.Modify();
        Customer."Document Sending Profile" := DocumentSendingProfile.Code;
        Customer.Modify();

        LibraryLowerPermission.SetTeamMember();
        asserterror LibraryEDoc.PostInvoice(Customer);
        // [THEN] Error is thrown when posting
        //asserterror LibraryEDoc.CreateEDocumentFromSales(EDocument, Customer."No.");
        Assert.AreEqual(StrSubstNo(DocumentSendingProfileWithWorkflowErr, 'NON-WORKFLOW', Format(DocumentSendingProfile."Electronic Document"::"Extended E-Document Service Flow"), DocumentSendingProfile.Code), GetLastErrorText(), IncorrectValueErr);
        IsInitialized := false;
    end;

    [Test]
    procedure InterfaceCheckErrorE2ESuccess()
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] If an error is logged with Error Message in Check implementation, this will block posting

        // [GIVEN] That we log error in Check implementation
        Initialize(Enum::"Service Integration"::"Mock");
        EDocImplState.EnableOnCheckEvent();
        EDocImplState.SetThrowLoggedError();
        BindSubscription(EDocImplState);
        LibraryLowerPermission.SetTeamMember();

        // [THEN] Error is thrown and posting will be stopped.
        asserterror LibraryEDoc.PostInvoice(Customer);
        Assert.ExpectedError('TEST');

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceCheckRuntimeErrorE2ESuccess()
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] If an runtime error happens in Check implementation, this will block posting

        // [GIVEN] That we throw runtime error in Check implementation
        Initialize(Enum::"Service Integration"::"Mock");
        EDocImplState.EnableOnCheckEvent();
        EDocImplState.SetThrowRuntimeError();
        BindSubscription(EDocImplState);
        LibraryLowerPermission.SetTeamMember();

        // [THEN] Error is thrown and posting will be stopped.
        asserterror LibraryEDoc.PostInvoice(Customer);
        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceCreateErrorE2ESuccess()
    var
        EDocument: Record "E-Document";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] If an error is logged with Error Message in Create implementation, this will NOT block posting

        // [GIVEN] That we log error in Create implementation
        Initialize(Enum::"Service Integration"::"Mock");
        EDocImplState.SetThrowLoggedError();
        BindSubscription(EDocImplState);

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        // [WHEN] Posting document is not going to succeed
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        // [THEN] E-Document has correct error status
        Assert.AreEqual(Format(EDocument.Status::Error), EDocumentPage."Electronic Document Status".Value(), IncorrectValueErr);
        Assert.AreEqual(Format(EDocument.Direction::Outgoing), EDocumentPage.Direction.Value(), IncorrectValueErr);
        Assert.AreEqual(EDocument."Document No.", EDocumentPage."Document No.".Value(), IncorrectValueErr);

        // [THEN] E-Document Service Status has correct error status
        VerifyOutboundFactboxValuesForSingleService(EDocument, Enum::"E-Document Service Status"::"Export Error", 1);

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('Error', EDocumentPage.ErrorMessagesPart."Message Type".Value(), IncorrectValueErr);
        Assert.AreEqual('TEST', EDocumentPage.ErrorMessagesPart.Description.Value(), IncorrectValueErr);

        EDocument.Reset();
        EDocument.SetFilter("Entry No", '>=%1', EDocument."Entry No");
        Assert.AreEqual(1, EDocument.Count(), IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    local procedure VerifyOutboundFactboxValuesForSingleService(EDocument: Record "E-Document"; Status: Enum "E-Document Service Status"; Logs: Integer);
    var
        EDocumentServiceStatus: Record "E-Document Service Status";
        Factbox: TestPage "Outbound E-Doc. Factbox";
    begin
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindSet();
        // This function is for single service, so we expect only one record
        Assert.RecordCount(EDocumentServiceStatus, 1);

        Factbox.OpenView();
        Factbox.GoToRecord(EDocumentServiceStatus);

        Assert.AreEqual(EDocumentService.Code, Factbox."E-Document Service".Value(), IncorrectValueErr);
        Assert.AreEqual(Format(Status), Factbox.SingleStatus.Value(), IncorrectValueErr);
        Assert.AreEqual(Format(Logs), Factbox.Log.Value(), IncorrectValueErr);
    end;

    [Test]
    procedure InterfaceCreateRuntimeErrorE2ESuccess()
    var
        EDocument: Record "E-Document";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] If an error is thrown in Create implementation, this will NOT block posting

        // [GIVEN] That we log error in Create implementation
        Initialize(Enum::"Service Integration"::"Mock");
        EDocImplState.SetThrowRuntimeError();
        BindSubscription(EDocImplState);

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        EDocumentPage.OpenView();
        EDocumentPage.Last();

        // [THEN] E-Document has correct error status
        Assert.AreEqual(Format(EDocument.Status::Error), EDocumentPage."Electronic Document Status".Value(), IncorrectValueErr);
        Assert.AreEqual(Format(EDocument.Direction::Outgoing), EDocumentPage.Direction.Value(), IncorrectValueErr);
        Assert.AreEqual(EDocument."Document No.", EDocumentPage."Document No.".Value(), IncorrectValueErr);

        // [THEN] E-Document Service Status has correct error status
        VerifyOutboundFactboxValuesForSingleService(EDocument, Enum::"E-Document Service Status"::"Export Error", 1);

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('Error', EDocumentPage.ErrorMessagesPart."Message Type".Value(), IncorrectValueErr);
        Assert.AreEqual('TEST', EDocumentPage.ErrorMessagesPart.Description.Value(), IncorrectValueErr);

        EDocument.Reset();
        EDocument.SetFilter("Entry No", '>=%1', EDocument."Entry No");
        Assert.AreEqual(1, EDocument.Count(), IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceCreateWithEmptyBlobE2ESuccess()
    var
        EDocument: Record "E-Document";
        EDocLog: Record "E-Document Log";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Empty blob from creation will cause error when attempting to send

        // [GIVEN] That we log error in Create implementation
        Initialize(Enum::"Service Integration"::"Mock");
        EDocImplState.SetDisableOnCreateOutput();
        BindSubscription(EDocImplState);

        if EDocument.FindLast() then
            EDocument.SetFilter("Entry No", '>%1', EDocument."Entry No");

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        EDocumentPage.OpenView();
        EDocumentPage.Last();

        // [THEN] E-Document has correct error status
        Assert.AreEqual(Format(EDocument.Status::Error), EDocumentPage."Electronic Document Status".Value(), IncorrectValueErr);
        Assert.AreEqual(Format(EDocument.Direction::Outgoing), EDocumentPage.Direction.Value(), IncorrectValueErr);
        Assert.AreEqual(EDocument."Document No.", EDocumentPage."Document No.".Value(), IncorrectValueErr);

        // [THEN] E-Document Service Status has correct error status
        VerifyOutboundFactboxValuesForSingleService(EDocument, Enum::"E-Document Service Status"::"Sending Error", 2);

        // [THEN] Logs are also correct
        EDocLog.SetRange("E-Doc. Entry No", EDocument."Entry No");
        EDocLog.SetRange("Service Code", EDocumentService.Code);
        EDocLog.FindSet();
        Assert.AreEqual(Enum::"E-Document Service Status"::Exported, EDocLog.Status, IncorrectValueErr);
        EDocLog.Next();
        Assert.AreEqual(Enum::"E-Document Service Status"::"Sending Error", EDocLog.Status, IncorrectValueErr);

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('Error', EDocumentPage.ErrorMessagesPart."Message Type".Value(), IncorrectValueErr);
        Assert.AreEqual(StrSubstNo(FailedToGetBlobErr, EDocument."Entry No"), EDocumentPage.ErrorMessagesPart.Description.Value(), IncorrectValueErr);

        Assert.AreEqual(1, EDocument.Count(), IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceCreateBatchErrorE2ESuccess()
    var
        EDocument: Record "E-Document";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] If an error is logged with Error Message in CreateBatch implementation, this will NOT block posting

        // [GIVEN] That we log error in Create implementation
        Initialize(Enum::"Service Integration"::"Mock");
        EDocImplState.SetThrowLoggedError();
        BindSubscription(EDocImplState);

        EDocumentService."Batch Mode" := EDocumentService."Batch Mode"::Threshold;
        EDocumentService."Batch Threshold" := 1;
        EDocumentService.Validate("Use Batch Processing", true);
        EDocumentService.Modify();

        if EDocument.FindLast() then
            EDocument.SetFilter("Entry No", '>%1', EDocument."Entry No");

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        EDocumentPage.OpenView();
        EDocumentPage.Last();

        // [THEN] E-Document has correct error status
        Assert.AreEqual(Format(EDocument.Status::Error), EDocumentPage."Electronic Document Status".Value(), IncorrectValueErr);
        Assert.AreEqual(Format(EDocument.Direction::Outgoing), EDocumentPage.Direction.Value(), IncorrectValueErr);
        Assert.AreEqual(EDocument."Document No.", EDocumentPage."Document No.".Value(), IncorrectValueErr);

        // [THEN] E-Document Service Status has correct error status
        VerifyOutboundFactboxValuesForSingleService(EDocument, Enum::"E-Document Service Status"::"Export Error", 2);

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('Error', EDocumentPage.ErrorMessagesPart."Message Type".Value(), IncorrectValueErr);
        Assert.AreEqual('TEST', EDocumentPage.ErrorMessagesPart.Description.Value(), IncorrectValueErr);

        Assert.AreEqual(1, EDocument.Count(), IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceCreateBatchRuntimeErrorE2ESuccess()
    var
        EDocument: Record "E-Document";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] If an error is logged with Error Message in CreateBatch implementation, this will NOT block posting

        // [GIVEN] That we log error in Create implementation
        Initialize(Enum::"Service Integration"::"Mock");
        EDocImplState.SetThrowRuntimeError();
        BindSubscription(EDocImplState);

        EDocumentService."Batch Mode" := EDocumentService."Batch Mode"::Threshold;
        EDocumentService."Batch Threshold" := 1;
        EDocumentService.Validate("Use Batch Processing", true);
        EDocumentService.Modify();

        if EDocument.FindLast() then
            EDocument.SetFilter("Entry No", '>%1', EDocument."Entry No");

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        EDocumentPage.OpenView();
        EDocumentPage.Last();

        // [THEN] E-Document has correct error status
        Assert.AreEqual(Format(EDocument.Status::Error), EDocumentPage."Electronic Document Status".Value(), IncorrectValueErr);
        Assert.AreEqual(Format(EDocument.Direction::Outgoing), EDocumentPage.Direction.Value(), IncorrectValueErr);
        Assert.AreEqual(EDocument."Document No.", EDocumentPage."Document No.".Value(), IncorrectValueErr);

        // [THEN] E-Document Service Status has correct error status
        VerifyOutboundFactboxValuesForSingleService(EDocument, Enum::"E-Document Service Status"::"Export Error", 2);

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('Error', EDocumentPage.ErrorMessagesPart."Message Type".Value(), IncorrectValueErr);
        Assert.AreEqual('TEST', EDocumentPage.ErrorMessagesPart.Description.Value(), IncorrectValueErr);

        Assert.AreEqual(1, EDocument.Count(), IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceCreateBatchE2ESuccess()
    var
        EDocument: Record "E-Document";
        EDocumentPage: TestPage "E-Document";
        DocNoA: Code[20];
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post two documents for activating batch. Validate first edocument, before second is posted, then validate both.

        // [GIVEN] Edocument service using 'Threshold' batch mode
        IsInitialized := false;
        Initialize(Enum::"Service Integration"::"Mock Sync");
        BindSubscription(EDocImplState);

        EDocumentService."Batch Mode" := EDocumentService."Batch Mode"::Threshold;
        EDocumentService."Batch Threshold" := 2;
        EDocumentService.Validate("Use Batch Processing", true);
        EDocumentService.Modify();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);

        // [THEN] E-Document has correct status
        Assert.AreEqual(Format(EDocument.Status::"In Progress"), EDocumentPage."Electronic Document Status".Value(), IncorrectValueErr);
        Assert.AreEqual(Format(EDocument.Direction::Outgoing), EDocumentPage.Direction.Value(), IncorrectValueErr);
        Assert.AreEqual(EDocument."Document No.", EDocumentPage."Document No.".Value(), IncorrectValueErr);

        // [THEN] E-Document Service Status has correct error status
        VerifyOutboundFactboxValuesForSingleService(EDocument, Enum::"E-Document Service Status"::"Pending Batch", 1);

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart."Message Type".Value(), IncorrectValueErr);
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart.Description.Value(), IncorrectValueErr);

        DocNoA := EDocument."Document No.";
        EDocument.SetFilter("Entry No", '>=%1', EDocument."Entry No");
        Assert.AreEqual(1, EDocument.Count(), IncorrectValueErr);
        EDocumentPage.Close();

        // [WHEN] Second document is posted
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        EDocumentPage.OpenView();
        EDocumentPage.Last();

        // [THEN] E-Document has correct status
        Assert.AreEqual(Format(EDocument.Status::Processed), EDocumentPage."Electronic Document Status".Value(), IncorrectValueErr);
        Assert.AreEqual(Format(EDocument.Direction::Outgoing), EDocumentPage.Direction.Value(), IncorrectValueErr);
        Assert.AreEqual(EDocument."Document No.", EDocumentPage."Document No.".Value(), IncorrectValueErr);

        // [THEN] E-Document Service Status has correct error status
        VerifyOutboundFactboxValuesForSingleService(EDocument, Enum::"E-Document Service Status"::Sent, 3);

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart."Message Type".Value(), IncorrectValueErr);
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart.Description.Value(), IncorrectValueErr);

        // [THEN] First edocument was also updated
        EDocumentPage.Filter.SetFilter("Document No.", DocNoA);
        EDocumentPage.First();
        Assert.AreEqual(Format(EDocument.Status::Processed), EDocumentPage."Electronic Document Status".Value(), IncorrectValueErr);
        Assert.AreEqual(Format(EDocument.Direction::Outgoing), EDocumentPage.Direction.Value(), IncorrectValueErr);
        Assert.AreEqual(DocNoA, EDocumentPage."Document No.".Value(), IncorrectValueErr);

        // [THEN] E-Document Service Status has correct error status
        VerifyOutboundFactboxValuesForSingleService(EDocument, Enum::"E-Document Service Status"::Sent, 3);

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart."Message Type".Value(), IncorrectValueErr);
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart.Description.Value(), IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceCreateBatchRecurrentE2ESuccess()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        EDocumentServicePage: TestPage "E-Document Service";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post two documents for activating batch. Validate first edocument, before second is posted, then validate both.

        // [GIVEN] Edocument service using 'Threshold' batch mode
        Initialize(Enum::"Service Integration"::"Mock Sync");
        BindSubscription(EDocImplState);

        EDocumentService."Batch Mode" := EDocumentService."Batch Mode"::Recurrent;
        EDocumentService.Validate("Use Batch Processing", true);
        EDocumentService.Modify();

        EDocumentServicePage.OpenView();
        EDocumentServicePage.Filter.SetFilter(Code, EDocumentService.Code);
        EDocumentServicePage.Close();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.FindLast();

        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Pending Batch", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::"In Progress", EDocument.Status, IncorrectValueErr);

        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentService.RecordId);

        EDocument.FindLast();
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();

        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::Sent, EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Processed, EDocument.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;


    [Test]
    procedure InterfaceCreateBatchRecurrentE2EFailure()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        EDocumentServicePage: TestPage "E-Document Service";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document. Nothhing is exported to temp blob so sending fails

        // [GIVEN] Edocument service using 'Recurrent' batch mode
        Initialize(Enum::"Service Integration"::"Mock Sync");
        BindSubscription(EDocImplState);
        EDocImplState.SetDisableOnCreateBatchOutput();

        EDocumentService.SetRecFilter();
        EDocumentService.FindFirst();
        EDocumentService."Batch Mode" := EDocumentService."Batch Mode"::Recurrent;
        EDocumentService.Validate("Use Batch Processing", true);
        EDocumentService.Modify();

        EDocumentServicePage.OpenView();
        EDocumentServicePage.Filter.SetFilter(Code, EDocumentService.Code);
        EDocumentServicePage.Close();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.FindLast();

        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Pending Batch", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::"In Progress", EDocument.Status, IncorrectValueErr);

        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentService.RecordId);

        EDocument.FindLast();
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();

        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Sending Error", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Error, EDocument.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);

        LibraryLowerPermission.SetOutsideO365Scope();
        EDocumentService.FindFirst();
        EDocumentService.Validate("Use Batch Processing", false);
        EDocumentService.Modify();
        Clear(EDocumentService);

        IsInitialized := false;
    end;

    [Test]
    procedure InterfaceAsyncSendingSuccess()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Send and GetResponse has been executed.
        // Check that document is pending response after posting and after get response job is run it is sent

        // [GIVEN] Edocument service using 'Recurrent' batch mode
        IsInitialized := false;
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();

        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Pending Response", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::"In Progress", EDocument.Status, IncorrectValueErr);

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Sent on service, and document is processed
        EDocument.FindLast();
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::Sent, EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Processed, EDocument.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;



    [Test]
    procedure InterfaceSyncSendingSuccess()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Interface on-send synchronization success scenario

        // [GIVEN] Edocument service using 'Recurrent' batch mode
        IsInitialized := false;
        Initialize(Enum::"Service Integration"::"Mock Sync");
        BindSubscription(EDocImplState);

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();
        EDocument.Get(EDocument."Entry No"); // Get after job queue run

        // [THEN] Verify that document was sent
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::Sent, EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Processed, EDocument.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceOnSendSyncRuntimeFailure()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Verifies the system's response to a runtime error within the code implementing an interface for E-Document processing

        // [GIVEN] That we throw runtime error inside code that implements interface
        Initialize(Enum::"Service Integration"::"Mock Sync");
        BindSubscription(EDocImplState);
        EDocImplState.SetThrowIntegrationLoggedError();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();
        EDocument.Get(EDocument."Entry No"); // Get after job queue run

        // [THEN] Verify that document is in error state
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Sending Error", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Error, EDocument.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceOnSendSyncLoggedErrorFailure()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Log error in send and check logs is correct

        // [GIVEN] That we log an error inside code that implements interface
        Initialize(Enum::"Service Integration"::"Mock Sync");
        BindSubscription(EDocImplState);
        EDocImplState.SetThrowIntegrationLoggedError();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        // [THEN] Status is Error on service, and document is error state
        EDocument.FindLast();
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Sending Error", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Error, EDocument.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceOnSendAsyncRuntimeFailure()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Runtime failure in Send when send is async and check that Get Response is not invoked

        // [GIVEN] That we throw runtime error inside code that implements interface
        IsInitialized := false;
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetThrowIntegrationRuntimeError();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocument.FindLast(); // Get after job queue run
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();

        // [THEN] Verify that document is in error state
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Sending Error", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Error, EDocument.Status, IncorrectValueErr);

        // [WHEN] Get Response job queue is not run
        Assert.IsFalse(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceOnSendAsyncLoggedErrorFailure()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Logged error in Send when send is async and check that Get Response is not invoked

        // [GIVEN] That we log error inside code that implements interface
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetThrowIntegrationLoggedError();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        // [THEN] Verify that document is in error state
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"Error", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Sending Error");

        // [WHEN] Get Response job queue is not run
        Assert.IsFalse(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceOnGetResponseLoggedErrorFailure()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        EDocumentLog: Record "E-Document Log";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Get Response implementation logs an error

        // [GIVEN] Setup
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.FindLast();
        EDocumentService.FindLast();
        EDocument.Get(EDocument."Entry No"); // Get after job queue run

        // [WHEN] error is logged inside get response
        EDocImplState.SetThrowIntegrationLoggedError();
        EDocImplState.SetOnGetResponseSuccess();
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);
        UnbindSubscription(EDocImplState);

        EDocumentServiceStatus.FindLast();
        EDocumentService.FindLast();
        EDocument.FindLast();

        // [THEN] Document status is error
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Sending Error", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Error, EDocument.Status, IncorrectValueErr);

        // [THEN] There are x logs
        EDocumentLog.SetRange("E-Doc. Entry No", EDocument."Entry No");
        EDocumentLog.SetRange("Service Code", EDocumentService.Code);

        // Exported -> Pending Response -> Get Response -> Sending Error
        EDocumentLog.FindSet();
        Assert.AreEqual(Enum::"E-Document Service Status"::Exported, EDocumentLog.Status, IncorrectValueErr);
        EDocumentLog.Next();
        Assert.AreEqual(Enum::"E-Document Service Status"::"Pending Response", EDocumentLog.Status, IncorrectValueErr);
        EDocumentLog.Next();
        Assert.AreEqual(Enum::"E-Document Service Status"::"Sending Error", EDocumentLog.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceOnGetResponseThrowErrorFailure()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        EDocumentLog: Record "E-Document Log";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Get Response implementation throws a runtime error

        // [GIVEN] Setup
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.FindLast();
        EDocumentService.FindLast();
        EDocument.Get(EDocument."Entry No"); // Get after job queue run

        // [WHEN] error is logged inside get response
        EDocImplState.SetThrowIntegrationRuntimeError();
        EDocImplState.SetOnGetResponseSuccess();
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);
        UnbindSubscription(EDocImplState);

        EDocumentServiceStatus.FindLast();
        EDocumentService.FindLast();
        EDocument.FindLast();

        // [THEN] Document status is error
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Sending Error", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Error, EDocument.Status, IncorrectValueErr);

        // [THEN] There are x logs
        EDocumentLog.SetRange("E-Doc. Entry No", EDocument."Entry No");
        EDocumentLog.SetRange("Service Code", EDocumentService.Code);

        // Exported -> Pending Response -> Get Response -> Sending Error
        EDocumentLog.FindSet();
        Assert.AreEqual(Enum::"E-Document Service Status"::Exported, EDocumentLog.Status, IncorrectValueErr);
        EDocumentLog.Next();
        Assert.AreEqual(Enum::"E-Document Service Status"::"Pending Response", EDocumentLog.Status, IncorrectValueErr);
        EDocumentLog.Next();
        Assert.AreEqual(Enum::"E-Document Service Status"::"Sending Error", EDocumentLog.Status, IncorrectValueErr);
    end;

    [Test]
    procedure InterfaceOnGetResponseReturnFalseThenTrueSuccess()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Send and GetResponse has been executed.
        // We return false from GetReponse, meaning that we did not get response yet, hence we should continue to have job queue to get response later
        // Finally we return true and document is marked Sent

        // [GIVEN] That IsASync is true, and OnGetReponse return false, then later true
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        Assert.IsTrue(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Pending Response on service, and document is in progress
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        Assert.IsTrue(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Pending Response on service, and document is in progress
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        EDocImplState.SetOnGetResponseSuccess();

        // [WHEN] Executing Get Response succesfully
        Assert.IsTrue(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure InterfaceOnGetResponseReturnTrueSuccess()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Send and GetResponse has been executed.
        // We return true from GetReponse, meaning that we did get response yet, hence we should mark document as sent

        // [GIVEN] That IsASync is true, and OnGetReponse return true
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Sent");

        // [THEN] We get reponse job queue has been removed
        Assert.IsFalse(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);
        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    procedure InterfaceOnGetApprovalReturnFalseSuccess()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Get Approval has been executed.

        // [GIVEN] That IsASync is true, and OnGetReponse return true and GetApproval returns Rejected
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();
        EDocImplState.SetActionHasUpdate(true);
        EDocImplState.SetActionReturnStatus(Enum::"E-Document Service Status"::Rejected);

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click get approval
        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.GetApproval.Invoke();

        // Impl by EDocServicesPageHandler

        // [THEN] Status is Pending Response on service, and document is in progress
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Rejected);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    procedure InterfaceOnGetApprovalReturnTrueSuccess()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Get Approval has been executed.
        // Get approval returns Approved

        // [GIVEN] That IsASync is true, and OnGetReponse and GetApproval returns true
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();
        EDocImplState.SetActionHasUpdate(true);
        EDocImplState.SetActionReturnStatus(Enum::"E-Document Service Status"::Approved);

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click get approval
        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.GetApproval.Invoke();

        // Impl by EDocServicesPageHandler

        // [THEN] Status is Processed on service, and document is in Approved
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Approved);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    procedure InterfaceOnGetApprovalNoUpdateSuccess()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Get Approval has been executed when approval returned false, aka no update was done

        // [GIVEN] That IsASync is true, and OnGetReponse and GetApproval returns true
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();
        EDocImplState.SetActionHasUpdate(false);
        EDocImplState.SetActionReturnStatus(Enum::"E-Document Service Status"::Approved);

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click get approval
        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.GetApproval.Invoke();

        // Impl by EDocServicesPageHandler

        // [THEN] Status is Processed on service, and document is in Approved
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    procedure InterfaceOnGetApprovalThrowErrorFailure()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Get Approval has been executed when a runtime error occured inside
        // Inside GetApproval an runtime error has been thrown by implementation

        // [GIVEN] That IsASync is true, and OnGetReponse and GetApproval returns true
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();


        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click get approval
        EDocImplState.SetThrowIntegrationLoggedError();
        EDocImplState.SetActionHasUpdate(true);
        EDocImplState.SetActionReturnStatus(Enum::"E-Document Service Status"::Approved);

        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.GetApproval.Invoke();

        // Impl by EDocServicesPageHandler

        // [THEN] Status is Processed on service, and document is in Approved
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Error, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Approval Error");

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    procedure InterfaceOnGetApprovalLoggedErrorFailure()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Get Approval has been executed.
        // Inside GetApproval an error has been logged by implementation

        // [GIVEN] That IsASync is true, and OnGetReponse and GetApproval returns true
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click approval
        EDocImplState.SetThrowIntegrationLoggedError();
        EDocImplState.SetActionHasUpdate(true);
        EDocImplState.SetActionReturnStatus(Enum::"E-Document Service Status"::Approved);

        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.GetApproval.Invoke();

        // Impl by EDocServicesPageHandler

        // [THEN] Status is Processed on service, and document is in Approved
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Error, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Approval Error");

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    internal procedure InterfaceOnGetCancelReturnCanceled()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Cancel action has been executed.

        // [GIVEN] That IsASync is true, and OnGetReponse return true and Cancel returns Canceled
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();
        EDocImplState.SetActionHasUpdate(true);
        EDocImplState.SetActionReturnStatus(Enum::"E-Document Service Status"::Canceled);

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click cancel
        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.Cancel.Invoke();

        // Impl by EDocServicesPageHandler

        // [THEN] Status is Canceled on service, and document is processed
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Canceled);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    internal procedure InterfaceOnGetCancelNoUpdate()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
        Logs: List of [Enum "E-Document Service Status"];
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Cancel action has been executed.

        // [GIVEN] That IsASync is true, and OnGetReponse return true and Cancel returns Canceled
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();
        EDocImplState.SetActionHasUpdate(false);

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click cancel
        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.Cancel.Invoke();

        // Impl by EDocServicesPageHandler

        // [THEN] Status is Canceled on service, and document is processed
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        Logs.Add(Enum::"E-Document Service Status"::Exported);
        Logs.Add(Enum::"E-Document Service Status"::"Pending Response");
        Logs.Add(Enum::"E-Document Service Status"::Sent);
        VerifyLogs(EDocument, EDocumentService, Logs);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    procedure InterfaceOnCancelThrowErrorFailure()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Get Approval has been executed when a runtime error occured inside
        // Inside GetApproval an runtime error has been thrown by implementation

        // [GIVEN] That IsASync is true, and OnGetReponse and GetApproval returns true
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();


        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click cancel
        EDocImplState.SetThrowIntegrationLoggedError();
        EDocImplState.SetActionHasUpdate(true);
        EDocImplState.SetActionReturnStatus(Enum::"E-Document Service Status"::Canceled);

        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.Cancel.Invoke();

        // Impl by EDocServicesPageHandler

        // [THEN] Status is Processed on service, and document is in Approved
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Error, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Cancel Error");

        UnbindSubscription(EDocImplState);
    end;

    // UI Tests

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    procedure UIClickSendInWhenPendingResponseSuccess()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Clicking Send on E-Document should only be allowed on "Sending Error" And "Exported".

        // [GIVEN]
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        asserterror EDocumentPage.Send.Invoke();
        Assert.ExpectedError(SendingErrStateErr);

        // Clean up
        LibraryLowerPermission.SetOutsideO365Scope();
        EDocumentServiceStatus.DeleteAll();

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    procedure GeneratePDFEmbedToXMLSuccess()
    var
        EDocument: Record "E-Document";
        DocumentBlob: Codeunit "Temp Blob";
        EDocumentLog: Codeunit "E-Document Log";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO]
        Initialize(Enum::"Service Integration"::"Mock");
        BindSubscription(this.EDocImplState);

        // [GIVEN] EDocument Service is set to embed PDF to XML
        this.EDocumentService."Embed PDF in export" := true;
        this.EDocumentService."Document Format" := Enum::"E-Document Format"::"PEPPOL BIS 3.0";
        this.EDocumentService.Modify(false);

        // [GIVEN] Posted Invoice by a Team Member
        this.LibraryLowerPermission.SetTeamMember();
        this.LibraryEDoc.PostInvoice(this.Customer);

        // [WHEN] Export EDocument
        EDocument.FindLast();
        this.LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentLog.GetDocumentBlobFromLog(EDocument, this.EDocumentService, DocumentBlob, Enum::"E-Document Service Status"::Exported);

        // [THEN] PDF is embedded in the XML
        CheckPDFEmbedToXML(DocumentBlob);
    end;

    [Test]
    internal procedure CreateEDocumentShipmentSuccessful()
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
        EDocument: Record "E-Document";
    begin
        IsInitialized := false;
        // [FEATURE] [E-Document] [Processing] 
        // [SCENARIO] Check that E-Document is created when posting sales shipment
        this.Initialize(Enum::"Service Integration"::"Mock");
        this.LibraryEDoc.AddEDocServiceSupportedType(this.EDocumentService, Enum::"E-Document Type"::"Sales Shipment");

        // [GIVEN] Setup E-Document service for sending shipment
        this.EDocumentService."Document Format" := Enum::"E-Document Format"::"PEPPOL BIS 3.0";
        this.EDocumentService.Modify(false);

        // [WHEN] Create sales order and post shipment for it
        SalesShipmentHeader := this.LibraryEDoc.PostSalesShipment(this.Customer);

        // [THEN] Check that E-Document is created for posted shipment
        EDocument.FindLast();
        this.Assert.AreEqual(SalesShipmentHeader."No.", EDocument."Document No.", this.IncorrectValueErr);

        // [WHEN] Export E-Document 
        this.LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        // [THEN] Check that xml file was created
        this.CheckXmlCreated(EDocument);
    end;

    [Test]
    procedure CreateEDocumentTransferShipmentSuccess()
    var
        TransferHeader: Record "Transfer Header";
        Item: Record Item;
        FromLocation: Record Location;
        ToLocation: Record Location;
        InTransitLocation: Record Location;
        DocumentSendingProfile: Record "Document Sending Profile";
        InventoryPostingGroup: Record "Inventory Posting Group";
    begin
        // [FEATURE] [E-Document] [Processing] 
        // [SCENARIO] Check that E-Document is created when posting transfer shipment
        IsInitialized := false;
        this.Initialize(Enum::"Service Integration"::"Mock");
        DocumentSendingProfile.FindLast();
        this.LibraryEDoc.AddEDocServiceSupportedType(this.EDocumentService, Enum::"E-Document Type"::"Transfer Shipment");

        // [GIVEN] E-Document service with format peppol
        this.EDocumentService."Document Format" := Enum::"E-Document Format"::"PEPPOL BIS 3.0";
        this.EDocumentService.Modify(false);

        // [GIVEN] Transfer locations with posting setup
        LibraryEDoc.CreateLocationsWithPostingSetups(FromLocation, ToLocation, InTransitLocation, InventoryPostingGroup);
        // [GIVEN] Item with inventory stock in from location
        LibraryEDoc.CreateItemWIthInventoryStock(Item, FromLocation, InventoryPostingGroup);
        // [GIVEN] Transfer-to location with Document Sending Profile set
        ToLocation."Transfer Doc. Sending Profile" := DocumentSendingProfile.Code;
        ToLocation.Modify(false);

        // [WHEN] Create transfer shipment
        LibraryInventory.CreateAndPostTransferOrder(
            TransferHeader,
            Item,
            FromLocation,
            ToLocation,
            InTransitLocation,
            '',
            1,
            Workdate(),
            Workdate(),
            true,
            false);

        // [THEN] Check that E-Document is created
        VerifyIfEDocumentIsCreatedForTransferOrder(TransferHeader);
    end;

    [Test]
    procedure PostDocumentNoDefaultOrElectronicProfile()
    var
        DocumentSendingProfile: Record "Document Sending Profile";
        EDocument: Record "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document without having default or Electronic sending profile
        IsInitialized := false;
        Initialize(Enum::"Service Integration"::"Mock");

        if EDocument.FindLast() then
            EDocument.SetFilter("Entry No", '>%1', EDocument."Entry No");

        // [GIVEN] No default document sending profile
        DocumentSendingProfile.Reset();
        DocumentSendingProfile.DeleteAll();

        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);

        // [THEN] No e-Document is created
        asserterror EDocument.FindLast();

        // [GIVEN] Default document sending profile is not electronic
        DocumentSendingProfile.GetDefault(DocumentSendingProfile);
        DocumentSendingProfile."Electronic Service Flow" := 'NON-WORKFLOW';
        DocumentSendingProfile.Modify();

        // [THEN] No e-Document is created
        LibraryEDoc.PostInvoice(Customer);
        asserterror EDocument.FindLast();
    end;

    [Test]
    [HandlerFunctions('DeleteDocumentOk')]
    procedure DeleteLinkedPurchaseHeaderNoAllowedSuccess()
    var
        EDocument: Record "E-Document";
        PurchaseHeader: Record "Purchase Header";
        EDocImportParams: Record "E-Doc. Import Parameters";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO]
        Initialize(Enum::"Service Integration"::"Mock");
        EDocumentService."Read into Draft Impl." := "E-Doc. Read into Draft"::PEPPOL;
        EDocumentService."Import Process" := Enum::"E-Document Import Process"::"Version 2.0";
        EDocumentService.Modify();

        // [GIVEN] An inbound e-document is received and fully processed
        EDocImportParams."Step to Run" := "Import E-Document Steps"::"Finish draft";
        Assert.IsTrue(LibraryEDoc.CreateInboundPEPPOLDocumentToState(EDocument, EDocumentService, 'peppol/peppol-invoice-0.xml', EDocImportParams), 'The e-document should be processed');
        EDocument.SetRecFilter();
        EDocument.FindLast();
        Assert.AreEqual(Enum::"E-Document Status"::Processed, EDocument.Status, 'E-Document should be in Processed status.');

        // [THEN] Delete
        PurchaseHeader.Get(EDocument."Document Record ID");
        if PurchaseHeader.Delete(true) then;

        EDocument.SetRecFilter();
        EDocument.FindLast();
        Assert.AreEqual(Enum::"E-Document Status"::"In Progress", EDocument.Status, 'E-Document should be in In Progress status.');
    end;

    local procedure CheckPDFEmbedToXML(TempBlob: Codeunit "Temp Blob")
    var
        TempXMLBuffer: Record "XML Buffer" temporary;
        InStream: InStream;
    begin
        TempBlob.CreateInStream(InStream);

        TempXMLBuffer.LoadFromStream(InStream);

        TempXMLBuffer.SetRange(Path, '/Invoice/cac:AdditionalDocumentReference/cac:Attachment/cbc:EmbeddedDocumentBinaryObject');
        Assert.RecordIsNotEmpty(TempXMLBuffer, '');
    end;

    [Test]
    internal procedure DeleteDuplicateEDocumentSuccess()
    var
        EDocument: Record "E-Document";
        VendorNo: Code[20];
    begin
        // [FEATURE] [E-Document] [Deleting]
        // [SCENARIO]
        Initialize(Enum::"Service Integration"::"Mock");

        // [GIVEN] Create duplicate e-document
        VendorNo := this.LibraryPurchase.CreateVendorNo();
        CreateIncomingEDocument(VendorNo, Enum::"E-Document Status"::"In Progress");
        CreateIncomingEDocument(VendorNo, Enum::"E-Document Status"::"In Progress");

        // [GIVEN] Get last E-Document
        EDocument.FindLast();

        // [WHEN] Delete ok
        EDocument.Delete(true);

        // [THEN] Check that E-Document no longer exists
        CheckEDocumentDeleted(EDocument."Entry No");
    end;

    [Test]
    [HandlerFunctions('ConfirmHandlerYes')]
    internal procedure DeleteNonDuplicateEDocumentAllowedIfConfirming()
    var
        EDocument: Record "E-Document";
        VendorNo: Code[20];
    begin
        // [FEATURE] [E-Document] [Deleting]
        // [SCENARIO]
        Initialize(Enum::"Service Integration"::"Mock");

        // [GIVEN] Create single e-document
        VendorNo := this.LibraryPurchase.CreateVendorNo();
        CreateIncomingEDocument(VendorNo, Enum::"E-Document Status"::"In Progress");

        // [GIVEN] Get last E-Document
        EDocument.FindLast();

        // [WHEN] Delete allowed if confirming
        EDocument.Delete(true);

        // [THEN] Check that E-Document no longer exists
        CheckEDocumentDeleted(EDocument."Entry No");
    end;

    [Test]
    [HandlerFunctions('ConfirmHandlerNo')]
    internal procedure DeleteNonDuplicateEDocumentNotAllowedIfDenying()
    var
        EDocument: Record "E-Document";
        VendorNo: Code[20];
    begin
        // [FEATURE] [E-Document] [Deleting]
        // [SCENARIO]
        Initialize(Enum::"Service Integration"::"Mock");

        // [GIVEN] Create single e-document
        VendorNo := this.LibraryPurchase.CreateVendorNo();
        CreateIncomingEDocument(VendorNo, Enum::"E-Document Status"::"In Progress");

        // [GIVEN] Get last E-Document
        EDocument.FindLast();

        // [WHEN] Delete not allowed if denying
        asserterror EDocument.Delete(true);
    end;

    [Test]
    internal procedure DeleteProcessedEDocumentNotAllowed()
    var
        EDocument: Record "E-Document";
        VendorNo: Code[20];
    begin
        // [FEATURE] [E-Document] [Deleting]
        // [SCENARIO]
        Initialize(Enum::"Service Integration"::"Mock");

        // [GIVEN] Create duplicate e-document and set to processed
        VendorNo := this.LibraryPurchase.CreateVendorNo();
        CreateIncomingEDocument(VendorNo, Enum::"E-Document Status"::"In Progress");
        CreateIncomingEDocument(VendorNo, Enum::"E-Document Status"::Processed);

        // [GIVEN] Get last E-Document
        EDocument.FindLast();

        // [WHEN] Delete not allowed
        asserterror EDocument.Delete(true);

        // [THEN] Check error message
        Assert.ExpectedError(this.DeleteProcessedNotAllowedErr);
    end;

    [Test]
    internal procedure PurchaseDocumentsCreatedFromEDocumentsUseDocumentTotalsValidation()
    var
        EDocument: Record "E-Document";
        EDocImportParameters: Record "E-Doc. Import Parameters";
        PurchaseHeader: Record "Purchase Header";
        PurchasesPayablesSetup: Record "Purchases & Payables Setup";
        EDocImport: Codeunit "E-Doc. Import";
    begin
        // [SCENARIO 566852] Purchase documents created from E-Documents use Document Totals validation, even if the feature is not configured in the Purchase & Payables Setup page.
        Initialize(Enum::"Service Integration"::"Mock");
        PurchasesPayablesSetup.GetRecordOnce();
        PurchasesPayablesSetup."Check Doc. Total Amounts" := false;
        PurchasesPayablesSetup.Modify();
        SetV2EDocService();

        // [GIVEN] An E-Document v2 with lines and totals
        LibraryEDoc.CreateInboundEDocument(EDocument, EDocumentService);
        LibraryEDoc.MockPurchaseDraftPrepared(EDocument);
        // [WHEN] Processing into a purchase invoice
        EDocImportParameters."Step to Run" := "Import E-Document Steps"::"Finish draft";
        EDocImport.ProcessIncomingEDocument(EDocument, EDocImportParameters);
        // [THEN] The purchase invoice should have the totals from the E-Document
        PurchaseHeader.SetRange("E-Document Link", EDocument.SystemId);
        PurchaseHeader.FindFirst();
        Assert.AreNotEqual(0, PurchaseHeader."Doc. Amount VAT", 'Document Totals should be set correctly.');
        Assert.AreNotEqual(0, PurchaseHeader."Doc. Amount Incl. VAT", 'Document Totals should be set correctly.');

        SetV1EDocService();
    end;

    [Test]
    internal procedure PurchaseDocumentsCreatedFromStructuredEDocumentCantEditTotals()
    var
        EDocument: Record "E-Document";
        EDocImportParameters: Record "E-Doc. Import Parameters";
        PurchaseHeader: Record "Purchase Header";
        EDocImport: Codeunit "E-Doc. Import";
        PurchaseInvoice: TestPage "Purchase Invoice";
    begin
        // [SCENARIO 566862] Purchase documents created from E-Documents coming from an structured format (e.g. XML) should not allow editing of the totals in the purchase invoice.
        Initialize(Enum::"Service Integration"::"Mock");
        SetV2EDocService();
        // [GIVEN] An E-Document v2 with lines and totals
        LibraryEDoc.CreateInboundEDocument(EDocument, EDocumentService);
        LibraryEDoc.MockPurchaseDraftPrepared(EDocument);
        // [WHEN] Processing into a purchase invoice
        EDocImportParameters."Step to Run" := "Import E-Document Steps"::"Finish draft";
        EDocImport.ProcessIncomingEDocument(EDocument, EDocImportParameters);
        PurchaseHeader.SetRange("E-Document Link", EDocument.SystemId);
        PurchaseHeader.FindFirst();
        // [THEN] The purchase invoice page should not allow editing of the totals
        PurchaseInvoice.Trap();
        Page.Run(Page::"Purchase Invoice", PurchaseHeader);
        Assert.IsFalse(PurchaseInvoice.DocAmount.Editable(), 'The totals should not be editable in the purchase invoice.');

        SetV1EDocService();
    end;

    [Test]
    procedure CreateEDocumentReminderSuccessful()
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        IssuedReminderHeader: Record "Issued Reminder Header";
        EDocument: Record "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing] 
        // [SCENARIO] Check that E-Document is created when issuing reminder

        // [GIVEN] Setup E-Document service for exporting reminder
        IsInitialized := false;
        this.Initialize(Enum::"Service Integration"::Mock);

        GeneralLedgerSetup.Get();
        GeneralLedgerSetup."Journal Templ. Name Mandatory" := false;
        GeneralLedgerSetup.Modify();

        this.LibraryEDoc.SetupReminderNoSeries();
        this.EDocumentService."Document Format" := Enum::"E-Document Format"::"PEPPOL BIS 3.0";
        this.EDocumentService.Modify(false);

        // [WHEN] Issue reminder
        IssuedReminderHeader := this.LibraryEDoc.IssueReminder(this.Customer);

        // [THEN] Check that E-Document is created and status is "In Progress"
#pragma warning disable AA0210
        EDocument.SetRange("Document No.", IssuedReminderHeader."No.");
#pragma warning restore AA0210
        EDocument.FindLast();
        this.Assert.AreEqual(Enum::"E-Document Status"::"In Progress", EDocument.Status, this.IncorrectValueErr);
        // [THEN] Check that xml file was created
        this.LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        this.CheckXmlCreated(EDocument);
    end;

    [Test]
    procedure CreateEDocumentFinChargeMemoSuccessful()
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        IssuedFinChargeMemoHeader: Record "Issued Fin. Charge Memo Header";
        EDocument: Record "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing] 
        // [SCENARIO] Check that E-Document is created when issuing finance charge memo

        // [GIVEN] Setup E-Document service for exporting finance charge memo 
        IsInitialized := false;
        this.Initialize(Enum::"Service Integration"::"Mock");

        GeneralLedgerSetup.Get();
        GeneralLedgerSetup."Journal Templ. Name Mandatory" := false;
        GeneralLedgerSetup.Modify();

        this.LibraryEDoc.SetupFinChargeMemoNoSeries();
        this.EDocumentService."Document Format" := Enum::"E-Document Format"::"PEPPOL BIS 3.0";
        this.EDocumentService.Modify(false);

        // [WHEN] Issue finance charge memo
        IssuedFinChargeMemoHeader := this.LibraryEDoc.IssueFinChargeMemo(this.Customer);

        // [THEN] Check that E-Document is created and status is "In Progress"
#pragma warning disable AA0210
        EDocument.SetRange("Document No.", IssuedFinChargeMemoHeader."No.");
#pragma warning restore AA0210
        EDocument.FindLast();
        this.Assert.AreEqual(Enum::"E-Document Status"::"In Progress", EDocument.Status, this.IncorrectValueErr);
        // [THEN] Check that xml file was created
        this.LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        this.CheckXmlCreated(EDocument);
    end;

    local procedure CreateIncomingEDocument(VendorNo: Code[20]; Status: Enum "E-Document Status")
    var
        EDocument: Record "E-Document";
    begin
        EDocument.Init();
        EDocument."Document Type" := "E-Document Type"::"Purchase Invoice";
        EDocument.Direction := Enum::"E-Document Direction"::Incoming;
        EDocument."Document Date" := WorkDate();
        EDocument."Incoming E-Document No." := 'TEST';
        EDocument."Bill-to/Pay-to No." := VendorNo;
        EDocument.Status := Status;
        EDocument.Insert(false);
    end;

    local procedure SetV2EDocService()
    var
        PreviousEDocService: Record "E-Document Service";
    begin
        PreviousEDocService.CopyFilters(EDocumentService);
        EDocumentService.SetRecFilter();
        EDocumentService.FindFirst();
        EDocumentService."Import Process" := "E-Document Import Process"::"Version 2.0";
        EDocumentService.Modify();
        EDocumentService.CopyFilters(PreviousEDocService);
    end;

    local procedure SetV1EDocService()
    var
        PreviousEDocService: Record "E-Document Service";
    begin
        PreviousEDocService.CopyFilters(EDocumentService);
        EDocumentService.SetRecFilter();
        EDocumentService.FindFirst();
        EDocumentService."Import Process" := "E-Document Import Process"::"Version 1.0";
        EDocumentService.Modify();
        EDocumentService.CopyFilters(PreviousEDocService);
    end;

    [ModalPageHandler]
    internal procedure EDocServicesPageHandler(var EDocServicesPage: TestPage "E-Document Services")
    var
        EDocumentService2: Record "E-Document Service";
        Variant: Variant;
    begin
        LibraryVariableStorage.Dequeue(Variant);
        EDocumentService2 := Variant;
        EDocServicesPage.GoToRecord(EDocumentService2);
        EDocServicesPage.OK().Invoke();
    end;

    [ConfirmHandler]
    internal procedure DeleteDocumentOk(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;

    local procedure Initialize(Integration: Enum "Service Integration")
    var
        TransformationRule: Record "Transformation Rule";
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        EDocumentSetup: Record "E-Documents Setup";
        Vendor: Record Vendor;
        Currency: Record Currency;
        LibraryERM: Codeunit "Library - ERM";
        Date: Date;
    begin
        LibraryLowerPermission.SetOutsideO365Scope();
        LibraryVariableStorage.Clear();
        Clear(EDocImplState);

        if IsInitialized then
            exit;

        EDocument.DeleteAll();
        EDocumentServiceStatus.DeleteAll();
        EDocumentService.DeleteAll();

        LibraryEDoc.SetupStandardVAT();
        LibraryEDoc.SetupStandardSalesScenario(Customer, EDocumentService, Enum::"E-Document Format"::Mock, Integration);
        LibraryEDoc.SetupStandardPurchaseScenario(Vendor, EDocumentService, Enum::"E-Document Format"::Mock, Integration);
        EDocumentService.Modify();
        EDocumentSetup.InsertNewExperienceSetup();

        // Set a currency that can be used across all localizations
        Currency.Init();
        Currency.Validate(Code, 'XYZ');
        if Currency.Insert(true) then begin
            Date := DWY2Date(1, 1, 2025); // Ensure date is before any documents that are loaded in the tests.
            LibraryERM.CreateExchangeRate(Currency.Code, Date, 1.0, 1.0);
        end;

        TransformationRule.DeleteAll();
        TransformationRule.CreateDefaultTransformations();

        IsInitialized := true;
    end;

    [ConfirmHandler]
    procedure ConfirmHandlerYes(Message: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;

    [ConfirmHandler]
    procedure ConfirmHandlerNo(Message: Text[1024]; var Reply: Boolean)
    begin
        Reply := false;
    end;


    local procedure VerifyLogs(EDocument: Record "E-Document"; EDocumentService2: Record "E-Document Service"; Logs: List of [Enum "E-Document Service Status"])
    var
        EDocumentLog: Record "E-Document Log";
        Count: Integer;
    begin
        EDocumentLog.SetRange("E-Doc. Entry No", EDocument."Entry No");
        EDocumentLog.SetRange("Service Code", EDocumentService2.Code);

        Count := 1;
        Assert.AreEqual(Logs.Count(), EDocumentLog.Count(), IncorrectValueErr);
        if EDocumentLog.FindSet() then
            repeat
                Assert.AreEqual(Logs.Get(Count), EDocumentLog.Status, IncorrectValueErr);
                Count := Count + 1;
            until EDocumentLog.Next() = 0;
    end;

#if not CLEAN26
#pragma warning disable AL0432
    local procedure Initialize(Integration: Enum "E-Document Integration")
    var
        TransformationRule: Record "Transformation Rule";
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
    begin
        LibraryLowerPermission.SetOutsideO365Scope();
        LibraryVariableStorage.Clear();
        Clear(EDocImplState);

        if IsInitialized then
            exit;

        EDocument.DeleteAll();
        EDocumentServiceStatus.DeleteAll();
        EDocumentService.DeleteAll();

        LibraryEDoc.SetupStandardVAT();
        LibraryEDoc.SetupStandardSalesScenario(Customer, EDocumentService, Enum::"E-Document Format"::Mock, Integration);

        TransformationRule.DeleteAll();
        TransformationRule.CreateDefaultTransformations();

        IsInitialized := true;
    end;
#pragma warning restore AL0432
#endif

    local procedure VerifyStatusOnDocumentAndService(EDocument: Record "E-Document"; EDocStatus: Enum "E-Document Status"; EDocService: Record "E-Document Service"; EDocumentServiceStatus: Record "E-Document Service Status"; EDocServiceStatus: Enum "E-Document Service Status")
    begin
        EDocumentServiceStatus.FindLast();
        EDocService.FindLast();
        EDocument.FindLast();
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocServiceStatus, EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocStatus, EDocument.Status, IncorrectValueErr);
    end;

    local procedure CheckEDocumentDeleted(EDocNo: Integer)
    var
        EDocument: Record "E-Document";
    begin
        EDocument.SetRange("Entry No", EDocNo);
        this.Assert.RecordIsEmpty(EDocument);
    end;

    local procedure CheckXmlCreated(EDocument: Record "E-Document")
    var
        EDocumentLog: Codeunit "E-Document Log";
        TempBlob: Codeunit "Temp Blob";
    begin
        EDocumentLog.GetDocumentBlobFromLog(EDocument, this.EDocumentService, TempBlob, "E-Document Service Status"::Exported);
        Assert.IsTrue(TempBlob.HasValue(), 'XML not created.');
    end;

    local procedure VerifyIfEDocumentIsCreatedForTransferOrder(var TransferHeader: Record "Transfer Header")
    var
        TransferShipmentHeader: Record "Transfer Shipment Header";
        EDocument: Record "E-Document";
    begin
#pragma warning disable AA0210
        TransferShipmentHeader.SetRange("Transfer Order No.", TransferHeader."No.");
#pragma warning restore AA0210
        TransferShipmentHeader.FindFirst();
        EDocument.SetRange("Document Record ID", TransferShipmentHeader.RecordId);
        Assert.IsFalse(EDocument.IsEmpty(), 'E-Document not created for Transfer Shipment Header');
    end;

#if not CLEAN26
#pragma warning disable AL0432
    [Test]
    internal procedure InterfaceAsyncSendingSuccess26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Send and GetResponse has been executed.
        // Check that document is pending response after posting and after get response job is run it is sent

        // [GIVEN] Edocument service using 'Recurrent' batch mode
        IsInitialized := false;
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();

        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Pending Response", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::"In Progress", EDocument.Status, IncorrectValueErr);

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Sent on service, and document is processed
        EDocument.FindLast();
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::Sent, EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Processed, EDocument.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    internal procedure InterfaceSyncSendingSuccess26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Interface on-send synchronization success scenario

        // [GIVEN] Edocument service using 'Recurrent' batch mode
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();
        EDocument.Get(EDocument."Entry No"); // Get after job queue run

        // [THEN] Verify that document was sent
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::Sent, EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Processed, EDocument.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    internal procedure InterfaceOnSendSyncRuntimeFailure26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Verifies the system's response to a runtime error within the code implementing an interface for E-Document processing

        // [GIVEN] That we throw runtime error inside code that implements interface
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetThrowIntegrationLoggedError();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();
        EDocument.Get(EDocument."Entry No"); // Get after job queue run

        // [THEN] Verify that document is in error state
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Sending Error", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Error, EDocument.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    internal procedure InterfaceOnSendSyncLoggedErrorFailure26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Log error in send and check logs is correct

        // [GIVEN] That we log an error inside code that implements interface
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetThrowIntegrationLoggedError();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        // [THEN] Status is Error on service, and document is error state
        EDocument.FindLast();
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Sending Error", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Error, EDocument.Status, IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    internal procedure InterfaceOnSendAsyncRuntimeFailure26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Runtime failure in Send when send is async and check that Get Response is not invoked

        // [GIVEN] That we throw runtime error inside code that implements interface
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetThrowIntegrationRuntimeError();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocument.FindLast(); // Get after job queue run
        EDocumentServiceStatus.SetRange("E-Document Entry No", EDocument."Entry No");
        EDocumentServiceStatus.FindLast();

        // [THEN] Verify that document is in error state
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Sending Error", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Error, EDocument.Status, IncorrectValueErr);

        // [WHEN] Get Response job queue is not run
        Assert.IsFalse(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    internal procedure InterfaceOnSendAsyncLoggedErrorFailure26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Logged error in Send when send is async and check that Get Response is not invoked

        // [GIVEN] That we log error inside code that implements interface
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetThrowIntegrationLoggedError();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        // [THEN] Verify that document is in error state
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"Error", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Sending Error");

        // [WHEN] Get Response job queue is not run
        Assert.IsFalse(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);

        // Clean up
        LibraryLowerPermission.SetOutsideO365Scope();
        EDocumentServiceStatus.DeleteAll();

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    internal procedure InterfaceOnGetResponseLoggedErrorFailure26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        EDocumentLog: Record "E-Document Log";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Get Response implementation logs an error

        // [GIVEN] Setup
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.FindLast();
        EDocumentService.FindLast();
        EDocument.Get(EDocument."Entry No"); // Get after job queue run

        // [WHEN] error is logged inside get response
        EDocImplState.SetThrowIntegrationLoggedError();
        EDocImplState.SetOnGetResponseSuccess();
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);
        UnbindSubscription(EDocImplState);

        EDocumentServiceStatus.FindLast();
        EDocumentService.FindLast();
        EDocument.FindLast();

        // [THEN] Document status is error
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Sending Error", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Error, EDocument.Status, IncorrectValueErr);

        // [THEN] There are x logs
        EDocumentLog.SetRange("E-Doc. Entry No", EDocument."Entry No");
        EDocumentLog.SetRange("Service Code", EDocumentService.Code);

        // Exported -> Pending Response -> Get Response -> Sending Error
        EDocumentLog.FindSet();
        Assert.AreEqual(Enum::"E-Document Service Status"::Exported, EDocumentLog.Status, IncorrectValueErr);
        EDocumentLog.Next();
        Assert.AreEqual(Enum::"E-Document Service Status"::"Pending Response", EDocumentLog.Status, IncorrectValueErr);
        EDocumentLog.Next();
        Assert.AreEqual(Enum::"E-Document Service Status"::"Sending Error", EDocumentLog.Status, IncorrectValueErr);

        // Clean up
        LibraryLowerPermission.SetOutsideO365Scope();
        EDocumentServiceStatus.DeleteAll();

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    internal procedure InterfaceOnGetResponseThrowErrorFailure26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        EDocumentLog: Record "E-Document Log";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Get Response implementation throws a runtime error

        // [GIVEN] Setup
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        EDocumentServiceStatus.FindLast();
        EDocumentService.FindLast();
        EDocument.Get(EDocument."Entry No"); // Get after job queue run

        // [WHEN] error is logged inside get response
        EDocImplState.SetThrowIntegrationRuntimeError();
        EDocImplState.SetOnGetResponseSuccess();
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);
        UnbindSubscription(EDocImplState);

        EDocumentServiceStatus.FindLast();
        EDocumentService.FindLast();
        EDocument.FindLast();

        // [THEN] Document status is error
        Assert.AreEqual(EDocument."Entry No", EDocumentServiceStatus."E-Document Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocumentServiceStatus."E-Document Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocumentServiceStatus.Status::"Sending Error", EDocumentServiceStatus.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::Error, EDocument.Status, IncorrectValueErr);

        // [THEN] There are x logs
        EDocumentLog.SetRange("E-Doc. Entry No", EDocument."Entry No");
        EDocumentLog.SetRange("Service Code", EDocumentService.Code);

        // Exported -> Pending Response -> Get Response -> Sending Error
        EDocumentLog.FindSet();
        Assert.AreEqual(Enum::"E-Document Service Status"::Exported, EDocumentLog.Status, IncorrectValueErr);
        EDocumentLog.Next();
        Assert.AreEqual(Enum::"E-Document Service Status"::"Pending Response", EDocumentLog.Status, IncorrectValueErr);
        EDocumentLog.Next();
        Assert.AreEqual(Enum::"E-Document Service Status"::"Sending Error", EDocumentLog.Status, IncorrectValueErr);

        // Clean up
        LibraryLowerPermission.SetOutsideO365Scope();
        EDocumentServiceStatus.DeleteAll();
    end;

    [Test]
    internal procedure InterfaceOnGetResponseReturnFalseThenTrueSuccess26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Send and GetResponse has been executed.
        // We return false from GetReponse, meaning that we did not get response yet, hence we should continue to have job queue to get response later
        // Finally we return true and document is marked Sent

        // [GIVEN] That IsASync is true, and OnGetReponse return false, then later true
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        Assert.IsTrue(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Pending Response on service, and document is in progress
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        Assert.IsTrue(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Pending Response on service, and document is in progress
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        EDocImplState.SetOnGetResponseSuccess();

        // [WHEN] Executing Get Response succesfully
        Assert.IsTrue(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    internal procedure InterfaceOnGetResponseReturnTrueSuccess26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Send and GetResponse has been executed.
        // We return true from GetReponse, meaning that we did get response yet, hence we should mark document as sent

        // [GIVEN] That IsASync is true, and OnGetReponse return true
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Sent");

        // [THEN] We get reponse job queue has been removed
        Assert.IsFalse(JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response"), IncorrectValueErr);
        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    internal procedure InterfaceOnGetApprovalReturnFalseSuccess26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Get Approval has been executed.

        // [GIVEN] That IsASync is true, and OnGetReponse return true and GetApproval returns false
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click get approval
        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.GetApproval.Invoke();

        // Impl by EDocServicesPageHandler

        // Currently not checked as fix is needed on get approval when returning false
        // [THEN] Status is Pending Response on service, and document is in progress
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Rejected);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    internal procedure InterfaceOnGetApprovalReturnTrueSuccess26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Get Approval has been executed.
        // Get approval returns true. This means that document was approved

        // [GIVEN] That IsASync is true, and OnGetReponse and GetApproval returns true
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();
        EDocImplState.SetOnGetApprovalSuccess();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click get approval
        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.GetApproval.Invoke();

        // Impl by EDocServicesPageHandler

        // [THEN] Status is Processed on service, and document is in Approved
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Approved);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    internal procedure InterfaceOnGetApprovalThrowErrorFailure26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Get Approval has been executed when a runtime error occured inside
        // Inside GetApproval an runtime error has been thrown by implementation
        // TODO: We fix that erros should do something

        // [GIVEN] That IsASync is true, and OnGetReponse and GetApproval returns true
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();
        EDocImplState.SetOnGetApprovalSuccess();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click get approval
        EDocImplState.SetThrowIntegrationLoggedError();
        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.GetApproval.Invoke();

        // Impl by EDocServicesPageHandler

        // [THEN] Status is Processed on service, and document is in Approved
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Approved);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    internal procedure InterfaceOnGetApprovalLoggedErrorFailure26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        JobQueueEntry: Record "Job Queue Entry";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document to async service. Test state after Get Approval has been executed.
        // Inside GetApproval an error has been logged by implementation
        // TODO: We fix that erros should do something

        // [GIVEN] That IsASync is true, and OnGetReponse and GetApproval returns true
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();
        EDocImplState.SetOnGetApprovalSuccess();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        // [WHEN] Executing Get Response succesfully
        JobQueueEntry.FindJobQueueEntry(JobQueueEntry."Object Type to Run"::Codeunit, Codeunit::"E-Document Get Response");
        LibraryJobQueue.RunJobQueueDispatcher(JobQueueEntry);

        // [THEN] Status is Processed on service, and document is in sent
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Sent);

        // [THEN] User click get approval
        EDocImplState.SetThrowIntegrationLoggedError();
        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        EDocumentPage.GetApproval.Invoke();

        // Impl by EDocServicesPageHandler

        // [THEN] Status is Processed on service, and document is in Approved
        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::Processed, EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::Approved);

        UnbindSubscription(EDocImplState);
    end;

    // UI Tests

    [Test]
    [HandlerFunctions('EDocServicesPageHandler')]
    internal procedure UIClickSendInWhenPendingResponseSuccess26()
    var
        EDocument: Record "E-Document";
        EDocumentServiceStatus: Record "E-Document Service Status";
        EDocumentPage: TestPage "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Clicking Send on E-Document should only be allowed on "Sending Error" And "Exported".

        // [GIVEN]
        Initialize(Enum::"E-Document Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetIsAsync();
        EDocImplState.SetOnGetResponseSuccess();

        // [WHEN] Team member post invoice
        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocument.RecordId);

        VerifyStatusOnDocumentAndService(EDocument, Enum::"E-Document Status"::"In Progress", EDocumentService, EDocumentServiceStatus, Enum::"E-Document Service Status"::"Pending Response");

        EDocumentService.FindLast();
        LibraryVariableStorage.Enqueue(EDocumentService);
        EDocumentPage.OpenView();
        EDocumentPage.GoToRecord(EDocument);
        asserterror EDocumentPage.Send.Invoke();
        Assert.ExpectedError(SendingErrStateErr);

        UnbindSubscription(EDocImplState);
    end;

    [Test]
    internal procedure PostDocumentNoDefaultOrElectronicProfile26()
    var
        DocumentSendingProfile: Record "Document Sending Profile";
        EDocument: Record "E-Document";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO] Post document without having default or Electronic sending profile
        Initialize(Enum::"E-Document Integration"::"Mock");

        if EDocument.FindLast() then
            EDocument.SetFilter("Entry No", '>%1', EDocument."Entry No");

        // [GIVEN] No default document sending profile
        DocumentSendingProfile.Reset();
        DocumentSendingProfile.DeleteAll();

        LibraryLowerPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);

        // [THEN] No e-Document is created
        asserterror EDocument.FindLast();
        Assert.AssertNothingInsideFilter();

        // [GIVEN] Default document sending profile is not electronic
        DocumentSendingProfile.GetDefault(DocumentSendingProfile);
        DocumentSendingProfile."Electronic Service Flow" := 'NON-WORKFLOW';
        DocumentSendingProfile.Modify();

        // [THEN] No e-Document is created
        LibraryEDoc.PostInvoice(Customer);
        asserterror EDocument.FindLast();
        Assert.AssertNothingInsideFilter();
    end;

    [Test]
    [HandlerFunctions('DeleteDocumentOk')]
    internal procedure DeleteLinkedPurchaseHeaderNoAllowedSuccess26()
    var
        EDocument: Record "E-Document";
        PurchaseHeader: Record "Purchase Header";
        EDocImportParams: Record "E-Doc. Import Parameters";
    begin
        // [FEATURE] [E-Document] [Processing]
        // [SCENARIO]
        Initialize(Enum::"Service Integration"::"Mock");
        EDocumentService."Read into Draft Impl." := "E-Doc. Read into Draft"::PEPPOL;
        EDocumentService."Import Process" := Enum::"E-Document Import Process"::"Version 2.0";
        EDocumentService.Modify();

        // [GIVEN] An inbound e-document is received and fully processed
        EDocImportParams."Step to Run" := "Import E-Document Steps"::"Finish draft";
        Assert.IsTrue(LibraryEDoc.CreateInboundPEPPOLDocumentToState(EDocument, EDocumentService, 'peppol/peppol-invoice-0.xml', EDocImportParams), 'The e-document should be processed');
        EDocument.SetRecFilter();
        EDocument.FindLast();
        Assert.AreEqual(Enum::"E-Document Status"::Processed, EDocument.Status, 'E-Document should be in Processed status.');

        // [THEN] Delete
        PurchaseHeader.Get(EDocument."Document Record ID");
        if PurchaseHeader.Delete(true) then;

        EDocument.SetRecFilter();
        EDocument.FindLast();
        Assert.AreEqual(Enum::"E-Document Status"::"In Progress", EDocument.Status, 'E-Document should be in In Progress status.');
    end;
#pragma warning restore AL0432
#endif
}
