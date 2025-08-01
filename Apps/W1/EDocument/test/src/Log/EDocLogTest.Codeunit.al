codeunit 139616 "E-Doc Log Test"
{
    Subtype = Test;
    TestType = Uncategorized;
    EventSubscriberInstance = Manual;

    trigger OnRun()
    begin
        // [FEATURE] [E-Document]
        IsInitialized := false;
    end;

    var

        Customer: Record Customer;
        EDocumentService: Record "E-Document Service";
        Assert: Codeunit Assert;
        LibraryVariableStorage: Codeunit "Library - Variable Storage";
        LibraryEDoc: Codeunit "Library - E-Document";
        LibraryJobQueue: Codeunit "Library - Job Queue";
        LibraryPermission: Codeunit "Library - Lower Permissions";
        IsInitialized: Boolean;
        IncorrectValueErr: Label 'Incorrect value found';
        FailLastEntryInBatch, ErrorInExport : Boolean;

    [Test]
    procedure CreateEDocumentSuccess()
    var
        SalesInvHeader: Record "Sales Invoice Header";
        EDocument: Record "E-Document";
        EDocLog: Record "E-Document Log";
        EDocMappingLogs: Record "E-Doc. Mapping Log";
    begin
        // [FEATURE] [E-Document] [Log]
        // [SCENARIO] EDocument Log on EDocument creation - No run of job queue to trigger export and send

        // [GIVEN] Creating a EDocument from Sales Invoice
        Initialize(Enum::"Service Integration"::"Mock Sync");

        // [Given] Team member that post invoice and EDocument is created
        LibraryPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);

        // [Then] Get last records from database
        EDocument.FindLast();
        EDocLog.FindLast();
        SalesInvHeader.SetRange("No.", EDocument."Document No.");


        // [THEN] Fields on document log is correctly
        Assert.AreEqual(EDocument."Entry No", EDocLog."E-Doc. Entry No", IncorrectValueErr);
        Assert.RecordCount(SalesInvHeader, 1);
        Assert.AreEqual(EDocLog."Document Type"::"Sales Invoice", EDocLog."Document Type", IncorrectValueErr);
        Assert.AreEqual(0, EDocLog."E-Doc. Data Storage Entry No.", IncorrectValueErr);
        Assert.AreEqual(0, EDocLog."E-Doc. Data Storage Size", IncorrectValueErr);
        Assert.AreEqual('', EDocLog."Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocLog.Status::Created, EDocLog.Status, IncorrectValueErr);
        Assert.AreEqual(EDocument.Status::"In Progress", EDocument.Status, IncorrectValueErr);

        // [THEN] No mapping logs are not created
        asserterror EDocMappingLogs.Get(EDocLog."Entry No.");
        Assert.AssertRecordNotFound();
    end;

    [Test]
    procedure ExportEDocNoMappingSuccess()
    var
        SalesInvHeader: Record "Sales Invoice Header";
        EDocument: Record "E-Document";
        EDocLog: Record "E-Document Log";
        EDocMappingLog: Record "E-Doc. Mapping Log";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocExportMgt: Codeunit "E-Doc. Export";
        EDocLogTest: Codeunit "E-Doc Log Test";
    begin
        // [FEATURE] [E-Document] [Log]
        // [SCENARIO] EDocument Log on EDocument export without mapping
        // Expected Outcomes:
        // 1. An E-Document is successfully exported without mapping.
        // 2. Document log fields are correctly populated.
        // 3. E-Document Service Status is updated to "Exported."
        // 4. No mapping logs are created in this scenario.

        // [GIVEN] Creating a EDocument from Sales Invoice is exported
        Initialize(Enum::"Service Integration"::"Mock Sync");

        // [Given] Team member that post invoice and EDocument is created
        LibraryPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();

        // [THEN] Export EDocument
        BindSubscription(EDocLogTest);
        EDocExportMgt.ExportEDocument(EDocument, EDocumentService);
        UnbindSubscription(EDocLogTest);

        EDocLog.FindLast();
        EDocument.FindLast();
        SalesInvHeader.SetRange("No.", EDocument."Document No.");

        // [THEN] Fields on document log is correctly
        Assert.AreEqual(EDocument."Entry No", EDocLog."E-Doc. Entry No", IncorrectValueErr);
        Assert.RecordCount(SalesInvHeader, 1);
        Assert.AreEqual(EDocLog."Document Type"::"Sales Invoice", EDocLog."Document Type", IncorrectValueErr);
        Assert.AreNotEqual(0, EDocLog."E-Doc. Data Storage Entry No.", IncorrectValueErr);
        Assert.AreEqual(0, EDocLog."E-Doc. Data Storage Size", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocLog."Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocLog.Status::Exported, EDocLog.Status, IncorrectValueErr);

        // [THEN] EDoc Service Status is updated
        EDocServiceStatus.Get(EDocLog."E-Doc. Entry No", EDocLog."Service Code");
        Assert.AreEqual(EDocLog.Status, EDocServiceStatus.Status, IncorrectValueErr);

        // [THEN] No mapping logs are not created
        asserterror EDocMappingLog.Get(EDocLog."Entry No.");
        Assert.AssertRecordNotFound();
    end;

    [Test]
    procedure ExportEDocWithMappingSuccess()
    var
        SalesInvHeader: Record "Sales Invoice Header";
        EDocMapping: Record "E-Doc. Mapping";
        TransformationRule: Record "Transformation Rule";
        EDocument: Record "E-Document";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocLog: Record "E-Document Log";
        EDocMappingLog: Record "E-Doc. Mapping Log";
        EDocExportMgt: Codeunit "E-Doc. Export";
        EDocLogTest: Codeunit "E-Doc Log Test";
    begin
        // [FEATURE] [E-Document] [Log]
        // [SCENARIO] EDocument Log on EDocument export with mapping
        // ---------------------------------------------------------------------------
        // [Expected Outcome]
        // [1] An E-Document is exported successfully with mapping.
        // [2] Document log fields are correctly populated.
        // [3] E-Document Service Status is updated to "Exported."
        // [4] A mapping log is correctly created.

        // [GIVEN] Exporting E-Document for service with mapping
        Initialize(Enum::"Service Integration"::"Mock Sync");
        LibraryEDoc.CreateServiceMapping(EDocumentService);

        // [Given] Team member that post invoice and EDocument is created
        LibraryPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocument.FindLast();

        // [Given] We export and get last data
        BindSubscription(EDocLogTest);
        EDocExportMgt.ExportEDocument(EDocument, EDocumentService);
        UnBindSubscription(EDocLogTest);
        EDocLog.FindLast();
        EDocument.FindLast();
        SalesInvHeader.SetRange("No.", EDocument."Document No.");

        // [THEN] Fields on document log is correctly
        Assert.AreEqual(EDocument."Entry No", EDocLog."E-Doc. Entry No", IncorrectValueErr);
        Assert.RecordCount(SalesInvHeader, 1);
        Assert.AreEqual(EDocLog."Document Type"::"Sales Invoice", EDocLog."Document Type", IncorrectValueErr);
        Assert.AreNotEqual(0, EDocLog."E-Doc. Data Storage Entry No.", IncorrectValueErr);
        Assert.AreEqual(0, EDocLog."E-Doc. Data Storage Size", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocLog."Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocLog.Status::Exported, EDocLog.Status, IncorrectValueErr);

        // [THEN] EDoc Service Status is updated
        EDocServiceStatus.Get(EDocLog."E-Doc. Entry No", EDocLog."Service Code");
        Assert.AreEqual(EDocLog.Status, EDocServiceStatus.Status, IncorrectValueErr);

        // [THEN] Mapping log is correctly created and logs contain correct values
        EDocMappingLog.SetRange("E-Doc Log Entry No.", EDocLog."Entry No.");
        Assert.RecordCount(EDocMappingLog, 2);

        EDocMappingLog.FindSet();
        EDocMapping.FindSet();
        TransformationRule.Get(TransformationRule.GetLowercaseCode());
        SalesInvHeader.FindFirst();

        Assert.AreEqual(EDocMapping."Table ID", EDocMappingLog."Table ID", IncorrectValueErr);
        Assert.AreEqual(EDocMapping."Field ID", EDocMappingLog."Field ID", IncorrectValueErr);
        Assert.AreEqual(SalesInvHeader."Bill-to Name", EDocMappingLog."Find Value", IncorrectValueErr);
        Assert.AreEqual(TransformationRule.TransformText(SalesInvHeader."Bill-to Name"), EDocMappingLog."Replace Value", IncorrectValueErr);

        EDocMappingLog.Next();
        EDocMapping.Next();

        Assert.AreEqual(EDocMapping."Table ID", EDocMappingLog."Table ID", IncorrectValueErr);
        Assert.AreEqual(EDocMapping."Field ID", EDocMappingLog."Field ID", IncorrectValueErr);
        Assert.AreEqual(SalesInvHeader."Bill-to Address", EDocMappingLog."Find Value", IncorrectValueErr);
        Assert.AreEqual(TransformationRule.TransformText(SalesInvHeader."Bill-to Address"), EDocMappingLog."Replace Value", IncorrectValueErr);

        // Tear down
        LibraryPermission.SetOutsideO365Scope();
        LibraryEDoc.DeleteServiceMapping(EDocumentService);
    end;

    [Test]
    procedure ExportEDocFailure()
    var
        SalesInvHeader: Record "Sales Invoice Header";
        EDocMapping: Record "E-Doc. Mapping";
        TransformationRule: Record "Transformation Rule";
        EDocumentA: Record "E-Document";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocLog: Record "E-Document Log";
        EDocMappingLog: Record "E-Doc. Mapping Log";
        //EDocDataStorage: Record "E-Doc. Data Storage";
        EDocLogTest: Codeunit "E-Doc Log Test";
    begin
        // [FEATURE] [E-Document] [Log]
        // [SCENARIO] EDocument Log on EDocument export when Create interface has errors
        // ---------------------------------------------------------------------------
        // [Expected Outcomes]
        // [1] Two logs should be created: one for document creation and another for the export error.
        // [2] Data storage log entries should be generated.
        // [3] The document log fields should be accurately populated, indicating "Export Failed" status.
        // [4] The E-Doc Service Status should reflect the error status.
        // [5] Mapping logs should be generated as part of this scenario.

        // [GIVEN] Exporting E-Document with errors on edocument
        Initialize(Enum::"Service Integration"::"Mock Sync");
        LibraryEDoc.CreateServiceMapping(EDocumentService);
        BindSubscription(EDocLogTest);
        EDocLogTest.SetExportError();
        EDocLog.SetAutoCalcFields("E-Doc. Data Storage Size");

        // [Given] Team member that post invoice and EDocument is created with error in exporting
        LibraryPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocumentA.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentA.RecordId());

        // [THEN] Two logs are created and one data storage log is saved
        EDocLog.SetRange("E-Doc. Entry No", EDocumentA."Entry No");
        Assert.AreEqual(2, EDocLog.Count(), IncorrectValueErr); // ( Created + Export Error )

        EDocLog.FindLast();
        SalesInvHeader.Get(EDocumentA."Document No.");

        // [THEN] Fields on document log is set correctly with 'Export Failed'
        Assert.AreEqual(EDocumentA."Entry No", EDocLog."E-Doc. Entry No", IncorrectValueErr);
        Assert.AreEqual(SalesInvHeader."No.", EDocLog."Document No.", IncorrectValueErr);
        Assert.AreEqual(EDocLog."Document Type"::"Sales Invoice", EDocLog."Document Type", IncorrectValueErr);
        Assert.AreNotEqual(0, EDocLog."E-Doc. Data Storage Entry No.", IncorrectValueErr);
        Assert.AreNotEqual(0, EDocLog."E-Doc. Data Storage Size", IncorrectValueErr);
        Assert.AreEqual(EDocumentService.Code, EDocLog."Service Code", IncorrectValueErr);
        Assert.AreEqual(EDocLog.Status::"Export Error", EDocLog.Status, IncorrectValueErr);

        // [THEN] EDoc Service Status is updated
        EDocServiceStatus.Get(EDocLog."E-Doc. Entry No", EDocLog."Service Code");
        Assert.AreEqual(EDocLog.Status, EDocServiceStatus.Status, IncorrectValueErr);

        // [THEN] Verify logs: Mapping log is correctly created and logs contain correct values
        EDocMappingLog.SetRange("E-Doc Log Entry No.", EDocLog."Entry No.");
        Assert.RecordCount(EDocMappingLog, 2);

        EDocMappingLog.FindSet();
        EDocMapping.FindSet();
        TransformationRule.Get(TransformationRule.GetLowercaseCode());

        Assert.AreEqual(EDocMapping."Table ID", EDocMappingLog."Table ID", IncorrectValueErr);
        Assert.AreEqual(EDocMapping."Field ID", EDocMappingLog."Field ID", IncorrectValueErr);
        Assert.AreEqual(SalesInvHeader."Bill-to Name", EDocMappingLog."Find Value", IncorrectValueErr);
        Assert.AreEqual(TransformationRule.TransformText(SalesInvHeader."Bill-to Name"), EDocMappingLog."Replace Value", IncorrectValueErr);

        EDocMappingLog.Next();
        EDocMapping.Next();

        Assert.AreEqual(EDocMapping."Table ID", EDocMappingLog."Table ID", IncorrectValueErr);
        Assert.AreEqual(EDocMapping."Field ID", EDocMappingLog."Field ID", IncorrectValueErr);
        Assert.AreEqual(SalesInvHeader."Bill-to Address", EDocMappingLog."Find Value", IncorrectValueErr);
        Assert.AreEqual(TransformationRule.TransformText(SalesInvHeader."Bill-to Address"), EDocMappingLog."Replace Value", IncorrectValueErr);

        // Tear down
        LibraryPermission.SetOutsideO365Scope();
        LibraryEDoc.DeleteServiceMapping(EDocumentService);
    end;

    [Test]
    procedure ExportEDocBatchThresholdSuccess()
    var
        SalesInvHeader: Record "Sales Invoice Header";
        EDocMapping: Record "E-Doc. Mapping";
        TransformationRule: Record "Transformation Rule";
        EDocumentA, EDocumentB : Record "E-Document";
        EDocLog: Record "E-Document Log";
        EDocMappingLog: Record "E-Doc. Mapping Log";
        EDocDataStorage: Record "E-Doc. Data Storage";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocLogTest: Codeunit "E-Doc Log Test";
        EntryNo, EntryNoEdoc : Integer;
    begin
        // [FEATURE] [E-Document] [Log]
        // [SCENARIO] EDocument Log on EDocument batch export with mapping
        // ---------------------------------------------------------------------------
        // [Expected Outcomes]
        // [1] 8 logs are created: one for each of the two posted documents.
        // [2] One data storage log entry is saved for each document, totaling two.
        // [3] Each log entry contains the correct information related to the document.
        // [4] The E-Doc Service Status is updated to "Sent" for each exported document.
        // [5] Mapping logs are correctly created, capturing mapping details.

        // [GIVEN] Exporting E-Documents for service with mapping
        Initialize(Enum::"Service Integration"::"Mock Sync");
        LibraryEDoc.CreateServiceMapping(EDocumentService);
        EDocumentService."Batch Mode" := enum::"E-Document Batch Mode"::Threshold;
        EDocumentService."Batch Threshold" := 2;
        EDocumentService.Validate("Use Batch Processing", true);
        EDocumentService.Modify();
        BindSubscription(EDocLogTest);
        EDocLog.SetAutoCalcFields("E-Doc. Data Storage Size");
        if EDocDataStorage.FindLast() then
            EntryNo := EDocDataStorage."Entry No.";
        if EDocumentA.FindLast() then
            EntryNoEdoc := EDocumentA."Entry No";

        // [Given] Team member that post two invoices and EDocuments is created with batch mode for service
        LibraryPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocumentA.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentA.RecordId());

        LibraryEDoc.PostInvoice(Customer);
        EDocumentB.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentB.RecordId());

        // [THEN] 8 logs are created and one data storage log is saved
        // ( Created + Pending + Exported + Sent ) * 2
        EDocumentA.SetFilter("Entry No", '>%1', EntryNoEdoc);
        Assert.RecordCount(EDocumentA, 2);
        EDocLog.SetFilter("E-Doc. Entry No", '%1|%2', EDocumentA."Entry No", EDocumentB."Entry No");
        Assert.AreEqual(8, EDocLog.Count(), IncorrectValueErr);

        EDocDataStorage.SetFilter("Entry No.", '>%1', EntryNo);
        Assert.RecordCount(EDocDataStorage, 1);
        EDocDataStorage.FindFirst();
        Assert.AreEqual(4, EDocDataStorage."Data Storage Size", IncorrectValueErr);

        // [THEN] Each log contains correct information
        repeat
            EDocLog.SetRange("E-Doc. Entry No", EDocumentA."Entry No");
            EDocLog.SetRange(Status, EDocLog.Status::Exported);
            EDocLog.FindFirst();
            SalesInvHeader.Get(EDocumentA."Document No.");

            // [THEN] Fields on document log is correctly
            Assert.AreEqual(EDocumentA."Entry No", EDocLog."E-Doc. Entry No", IncorrectValueErr);
            Assert.AreEqual(SalesInvHeader."No.", EDocLog."Document No.", IncorrectValueErr);
            Assert.AreEqual(EDocLog."Document Type"::"Sales Invoice", EDocLog."Document Type", IncorrectValueErr);
            Assert.AreNotEqual(0, EDocLog."E-Doc. Data Storage Entry No.", IncorrectValueErr);
            Assert.AreEqual(4, EDocLog."E-Doc. Data Storage Size", IncorrectValueErr);
            Assert.AreEqual(EDocumentService.Code, EDocLog."Service Code", IncorrectValueErr);
            Assert.AreEqual(EDocLog.Status::Exported, EDocLog.Status, IncorrectValueErr);

            // [THEN] EDoc Service Status is updated
            EDocServiceStatus.Get(EDocLog."E-Doc. Entry No", EDocLog."Service Code");
            Assert.AreEqual(EDocServiceStatus.Status::Sent, EDocServiceStatus.Status, IncorrectValueErr);

            // [THEN] Mapping log is correctly created
            EDocMappingLog.SetRange("E-Doc Log Entry No.", EDocLog."Entry No.");
            Assert.RecordCount(EDocMappingLog, 2);

            EDocMappingLog.FindSet();
            EDocMapping.FindSet();
            TransformationRule.Get(TransformationRule.GetLowercaseCode());

            Assert.AreEqual(EDocMapping."Table ID", EDocMappingLog."Table ID", IncorrectValueErr);
            Assert.AreEqual(EDocMapping."Field ID", EDocMappingLog."Field ID", IncorrectValueErr);
            Assert.AreEqual(SalesInvHeader."Bill-to Name", EDocMappingLog."Find Value", IncorrectValueErr);
            Assert.AreEqual(TransformationRule.TransformText(SalesInvHeader."Bill-to Name"), EDocMappingLog."Replace Value", IncorrectValueErr);

            EDocMappingLog.Next();
            EDocMapping.Next();

            Assert.AreEqual(EDocMapping."Table ID", EDocMappingLog."Table ID", IncorrectValueErr);
            Assert.AreEqual(EDocMapping."Field ID", EDocMappingLog."Field ID", IncorrectValueErr);
            Assert.AreEqual(SalesInvHeader."Bill-to Address", EDocMappingLog."Find Value", IncorrectValueErr);
            Assert.AreEqual(TransformationRule.TransformText(SalesInvHeader."Bill-to Address"), EDocMappingLog."Replace Value", IncorrectValueErr);

        until EdocumentA.Next() = 0;

        // Tear down
        LibraryPermission.SetOutsideO365Scope();
        LibraryEDoc.DeleteServiceMapping(EDocumentService);
    end;

    [Test]
    procedure ExportEDocBatchThresholdFailure()
    var
        EDocumentA, EDocumentB : Record "E-Document";
        EDocumentService2: Record "E-Document Service";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocDataStorage: Record "E-Doc. Data Storage";
        EDocLog: Record "E-Document Log";
        EDocMappingLog: Record "E-Doc. Mapping Log";
        EDocLogTest: Codeunit "E-Doc Log Test";
    begin
        // [FEATURE] [E-Document] [Log]
        // [SCENARIO] EDocument Log on EDocument threshold batch export when there is errors during export
        // ---------------------------------------------------------------------------
        // [Expected Outcomes]
        // [1] Initialize the test environment.
        // [2] Simulate an error in batch export by setting the last entry to error.
        // [3] Create E-Documents and a service with batch export settings (threshold: 2).
        // [4] Post two sales documents, both marked as export errors.
        // [5] Validate the state of Document A and B, including its logs and service status.
        // [6] Ensure no mapping logs or data storage is created for either document.

        // [GIVEN] A flow to send to service with threshold batch
        Initialize(Enum::"Service Integration"::"Mock Sync");
        LibraryEDoc.CreateServiceMapping(EDocumentService);
        EDocumentService."Batch Mode" := enum::"E-Document Batch Mode"::Threshold;
        EDocumentService."Batch Threshold" := 2;
        EDocumentService.Validate("Use Batch Processing", true);
        EDocumentService.Modify();
        BindSubscription(EDocLogTest); // Bind subscription to get events to insert into blobs
        EDocLogTest.SetLastEntryInBatchToError(); // Make sure last entry in create batch fails

        // [Given] Team member that post two invoices and EDocuments is created with batch mode for service
        LibraryPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocumentA.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentA.RecordId());

        // [Then] First documents is pending batch for the service
        EDocServiceStatus.SetRange("E-Document Entry No", EDocumentA."Entry No");
        EDocServiceStatus.SetRange("E-Document Service Code", EDocumentService.Code);
        EDocServiceStatus.SetRange(Status, EDocServiceStatus.Status::"Pending Batch");
        Assert.RecordCount(EDocServiceStatus, 1);

        LibraryEDoc.PostInvoice(Customer);
        EDocumentB.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentB.RecordId());

        // [THEN] All documents are marked as export error
        EDocServiceStatus.SetFilter("E-Document Entry No", '%1|%2', EDocumentA."Entry No", EDocumentB."Entry No");
        EDocServiceStatus.SetRange("E-Document Service Code", EDocumentService.Code);
        EDocServiceStatus.SetRange(Status, EDocServiceStatus.Status::"Export Error");
        Assert.RecordCount(EDocServiceStatus, 2);

        // CHECKS FOR DOCUMENT A (Export error)
        EDocumentA.Get(EDocumentA."Entry No");
        Assert.AreEqual(Enum::"E-Document Status"::Error, EDocumentA.Status, IncorrectValueErr);

        // [THEN] There are 3 logs for document that was successfully sent
        EDocLog.SetRange("E-Doc. Entry No", EDocumentA."Entry No");
        Assert.RecordCount(EDocLog, 3);

        AssertEDocLogState(EDocumentA, EDocLog, EDocumentService2, Enum::"E-Document Service Status"::Created);
        AssertEDocLogState(EDocumentA, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Pending Batch");
        AssertEDocLogState(EDocumentA, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Export Error");

        // [THEN] Mapping log is not created
        EDocMappingLog.SetRange("E-Doc Log Entry No.", EDocLog."Entry No.");
        asserterror EDocMappingLog.FindSet();
        Assert.AssertNothingInsideFilter();

        // [THEN] No Data Storage created
        asserterror EDocDataStorage.Get(EDocLog."E-Doc. Data Storage Entry No.");

        // CHECKS FOR DOCUMENT B (EXPORT ERROR)
        EDocumentB.Get(EDocumentB."Entry No");
        Assert.AreEqual(Enum::"E-Document Status"::Error, EDocumentB.Status, IncorrectValueErr);

        // [THEN] There are 3 logs for document that failed during export
        EDocLog.SetRange("E-Doc. Entry No", EDocumentB."Entry No");
        EDocLog.SetRange(Status);
        Assert.RecordCount(EDocLog, 3);

        AssertEDocLogState(EDocumentB, EDocLog, EDocumentService2, Enum::"E-Document Service Status"::Created);
        AssertEDocLogState(EDocumentB, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Pending Batch");
        AssertEDocLogState(EDocumentB, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Export Error");

        // [THEN] Mapping log is not created
        EDocMappingLog.SetRange("E-Doc Log Entry No.", EDocLog."Entry No.");
        Assert.RecordIsEmpty(EDocMappingLog);

        // [THEN] No Data Storage created
        asserterror EDocDataStorage.Get(EDocLog."E-Doc. Data Storage Entry No.");

        // Tear down
        LibraryPermission.SetOutsideO365Scope();
        LibraryEDoc.DeleteServiceMapping(EDocumentService);
    end;

    [Test]
    procedure ExportEDocBatchtRecurrentSuccess()
    var
        EDocumentA, EDocumentB : Record "E-Document";
        EDocumentService2: Record "E-Document Service";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocDataStorage: Record "E-Doc. Data Storage";
        EDocLog: Record "E-Document Log";
        EDocMappingLog: Record "E-Doc. Mapping Log";
        EDocLogTest: Codeunit "E-Doc Log Test";
        EDocumentBackgroundJobs: Codeunit "E-Document Background Jobs";
    //ServiceCode: Code[20];
    begin
        // [FEATURE] [E-Document] [Log]
        // [SCENARIO] EDocument Log on EDocument when send in recurrent batch.
        // There are no errors during export for documents
        // ---------------------------------------------------------------------------
        // [Expected Outcomes]
        // [1] Initialize the test environment.
        // [2] Create E-Documents and a service with recurrent batch settings.
        // [3] Post two sales documents
        // [4] Validate the state of Document A, including logs and service status, after a successful export.
        // [5] Validate logs, data storage, and fields for Document A's successful export.
        // [6] Validate the state of Document A, including logs and service status, after a successful export.
        // [7] Validate logs, data storage, and fields for Document B's successful export.
        // [8] Ensure mapping logs are created.

        // [GIVEN] A flow to send to service with recurrent batch
        Initialize(Enum::"Service Integration"::"Mock Sync");
        LibraryEDoc.CreateServiceMapping(EDocumentService);
        EDocumentService."Batch Mode" := EDocumentService."Batch Mode"::Recurrent;
        EDocumentService."Batch Minutes between runs" := 1;
        EDocumentService."Batch Start Time" := Time();
        EDocumentService.Validate("Use Batch Processing", true);
        EDocumentService.Modify();
        BindSubscription(EDocLogTest); // Bind subscription to get events to insert into blobs

        // [Given] Team member that post two invoices and EDocuments is created with batch mode for service
        LibraryPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocumentA.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentA.RecordId());

        LibraryEDoc.PostInvoice(Customer);
        EDocumentB.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentB.RecordId());

        // [THEN] Two documents are pending batch for the service
        EDocServiceStatus.SetFilter("E-Document Entry No", '%1|%2', EDocumentA."Entry No", EDocumentB."Entry No");
        EDocServiceStatus.SetRange("E-Document Service Code", EDocumentService.Code);
        EDocServiceStatus.SetRange(Status, EDocServiceStatus.Status::"Pending Batch");
        Assert.RecordCount(EDocServiceStatus, 2);

        // [Given] Run recurrent batch job
        EDocumentBackgroundJobs.HandleRecurrentBatchJob(EDocumentService);
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentService.RecordId());

        // Document A is successfully processed
        EDocumentA.Get(EDocumentA."Entry No");
        Assert.AreEqual(Enum::"E-Document Status"::Processed, EDocumentA.Status, IncorrectValueErr);

        // [THEN] EDocServiceStatus is set to Sent for Document A
        EDocServiceStatus.SetRange("E-Document Entry No", EDocumentA."Entry No");
        EDocServiceStatus.SetRange(Status);
        EDocServiceStatus.FindFirst();
        Assert.AreEqual(Enum::"E-Document Service Status"::Sent, EDocServiceStatus.Status, IncorrectValueErr);

        // [THEN] There are four logs for Document A that was successfully sent
        EDocLog.SetRange("E-Doc. Entry No", EDocumentA."Entry No");
        Assert.RecordCount(EDocLog, 4);

        AssertEDocLogState(EDocumentA, EDocLog, EDocumentService2, Enum::"E-Document Service Status"::Created);
        AssertEDocLogState(EDocumentA, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Pending Batch");
        AssertEDocLogState(EDocumentA, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Exported");

        // [THEN] Mapping log exists for Exported log
        EDocMappingLog.SetRange("E-Doc Log Entry No.", EDocLog."Entry No.");
        EDocMappingLog.FindSet();

        // [THEN] Data storage is created for the exported document, and for temp blob at send
        // [THEN] Exported Blob has size 4
        EDocDataStorage.SetRange("Entry No.", EDocLog."E-Doc. Data Storage Entry No.");
        Assert.RecordCount(EDocDataStorage, 1);
        EDocDataStorage.Get(EDocLog."E-Doc. Data Storage Entry No.");
        Assert.AreEqual(4, EDocDataStorage."Data Storage Size", IncorrectValueErr);

        // [THEN] Fields on document log is correctly for Sent log
        AssertEDocLogState(EDocumentA, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Sent");
        EDocLog.SetRange(Status);

        // Document B is processed
        EDocumentB.Get(EDocumentB."Entry No");
        Assert.AreEqual(Enum::"E-Document Status"::Processed, EDocumentB.Status, IncorrectValueErr);

        // [THEN] EDocServiceStatus is set to sent for Document B
        EDocServiceStatus.SetRange("E-Document Entry No", EDocumentB."Entry No");
        EDocServiceStatus.FindFirst();
        Assert.AreEqual(Enum::"E-Document Service Status"::"Sent", EDocServiceStatus.Status, IncorrectValueErr);

        // [THEN] There are 3 logs for document B
        EDocLog.SetRange("E-Doc. Entry No", EDocumentB."Entry No");
        Assert.RecordCount(EDocLog, 4);

        AssertEDocLogState(EDocumentB, EDocLog, EDocumentService2, Enum::"E-Document Service Status"::Created);
        AssertEDocLogState(EDocumentB, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Pending Batch");
        AssertEDocLogState(EDocumentB, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Exported");

        // [THEN] Mapping log exists for Exported log
        EDocMappingLog.SetRange("E-Doc Log Entry No.", EDocLog."Entry No.");
        Assert.RecordIsNotEmpty(EDocMappingLog);

        // [THEN] Data storage is created for document B, and for temp blob at send
        // [THEN] Exported Blob has size 4
        EDocDataStorage.FindSet();
        Assert.AreEqual(1, EDocDataStorage.Count(), IncorrectValueErr);
        EDocDataStorage.Get(EDocLog."E-Doc. Data Storage Entry No.");
        Assert.AreEqual(4, EDocDataStorage."Data Storage Size", IncorrectValueErr);

        // [THEN] Fields on document B log is correctly for Sent log
        AssertEDocLogState(EDocumentB, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Sent");
        EDocLog.SetRange(Status);

        // Tear down
        LibraryPermission.SetOutsideO365Scope();
        LibraryEDoc.DeleteServiceMapping(EDocumentService);
    end;

    [Test]
    procedure ExportEDocBatchtRecurrentFailure()
    var
        EDocumentA, EDocumentB : Record "E-Document";
        EDocumentService2: Record "E-Document Service";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocDataStorage: Record "E-Doc. Data Storage";
        EDocLog: Record "E-Document Log";
        EDocMappingLog: Record "E-Doc. Mapping Log";
        EDocLogTest: Codeunit "E-Doc Log Test";
        EDocumentBackgroundJobs: Codeunit "E-Document Background Jobs";
    begin
        // [FEATURE] [E-Document] [Log]
        // [SCENARIO] EDocument Log on EDocument recurrent batch when there is errors during export for a document
        // ---------------------------------------------------------------------------
        // [Expected Outcomes]
        // [1] Initialize the test environment.
        // [2] Simulate an error in batch export by setting the last entry to error.
        // [3] Create E-Documents and a service with recurrent batch settings.
        // [4] Post two sales documents, one successfully processed and one marked as an export error.
        // [5] Validate the state of Document A, including logs and service status, after a successful export.
        // [6] Validate logs, data storage, and fields for Document A's successful export.
        // [7] Validate the state of Document B, marked as an export error.
        // [8] Validate logs, data storage, and fields for Document B's export error.
        // [9] Ensure no mapping logs are created.

        // [GIVEN] A flow to send to service with recurrent batch
        Initialize(Enum::"Service Integration"::"Mock Sync");
        LibraryEDoc.CreateServiceMapping(EDocumentService);
        EDocumentService.Get(EDocumentService.Code);
        EDocumentService."Batch Mode" := EDocumentService."Batch Mode"::Recurrent;
        EDocumentService."Batch Minutes between runs" := 1;
        EDocumentService."Batch Start Time" := Time();
        EDocumentService.Validate("Use Batch Processing", true);
        EDocumentService.Modify();

        BindSubscription(EDocLogTest); // Bind subscription to get events to insert into blobs
        EDocLogTest.SetLastEntryInBatchToError(); // Make sure last entry in create batch fails

        // [Given] Team member that post two invoices and EDocuments is created with batch mode for service
        LibraryPermission.SetTeamMember();
        LibraryEDoc.PostInvoice(Customer);
        EDocumentA.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentA.RecordId());

        LibraryEDoc.PostInvoice(Customer);
        EDocumentB.FindLast();
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentB.RecordId());

        // [THEN] Two documents are pending batch for the service
        EDocServiceStatus.SetFilter("E-Document Entry No", '%1|%2', EDocumentA."Entry No", EDocumentB."Entry No");
        EDocServiceStatus.SetRange("E-Document Service Code", EDocumentService.Code);
        EDocServiceStatus.SetRange(Status, EDocServiceStatus.Status::"Pending Batch");
        Assert.RecordCount(EDocServiceStatus, 2);

        // [Given] Run recurrent batch job
        EDocumentBackgroundJobs.HandleRecurrentBatchJob(EDocumentService);
        LibraryJobQueue.FindAndRunJobQueueEntryByRecordId(EDocumentService.RecordId());

        // Document A is successfully processed
        EDocumentA.Get(EDocumentA."Entry No");
        Assert.AreEqual(Enum::"E-Document Status"::Processed, EDocumentA.Status, IncorrectValueErr);

        // [THEN] EDocServiceStatus is set to Sent for Document A
        EDocServiceStatus.SetRange("E-Document Entry No", EDocumentA."Entry No");
        EDocServiceStatus.SetRange(Status);
        EDocServiceStatus.FindFirst();
        Assert.AreEqual(Enum::"E-Document Service Status"::Sent, EDocServiceStatus.Status, IncorrectValueErr);

        // [THEN] There are four logs for Document A that was successfully sent
        EDocLog.SetRange("E-Doc. Entry No", EDocumentA."Entry No");
        Assert.RecordCount(EDocLog, 4);

        AssertEDocLogState(EDocumentA, EDocLog, EDocumentService2, Enum::"E-Document Service Status"::Created);
        AssertEDocLogState(EDocumentA, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Pending Batch");
        AssertEDocLogState(EDocumentA, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Exported");

        // [THEN] Mapping log is correctly created for Exported log
        EDocMappingLog.SetRange("E-Doc Log Entry No.", EDocLog."Entry No.");
        EDocMappingLog.FindSet();

        // [THEN] Data storage is created for the exported document, and for temp blob at send
        // [THEN] Exported Blob has size 4
        EDocDataStorage.SetRange("Entry No.", EDocLog."E-Doc. Data Storage Entry No.");
        Assert.RecordCount(EDocDataStorage, 1);
        EDocDataStorage.Get(EDocLog."E-Doc. Data Storage Entry No.");
        Assert.AreEqual(4, EDocDataStorage."Data Storage Size", IncorrectValueErr);

        // [THEN] Fields on document log is correctly for Sent log
        AssertEDocLogState(EDocumentA, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Sent");

        // Document B has gotten an error
        EDocumentB.Get(EDocumentB."Entry No");
        Assert.AreEqual(Enum::"E-Document Status"::Error, EDocumentB.Status, IncorrectValueErr);

        // [THEN] EDocServiceStatus is set to Export Error for Document B
        EDocServiceStatus.SetRange("E-Document Entry No", EDocumentB."Entry No");
        EDocServiceStatus.FindFirst();
        Assert.AreEqual(Enum::"E-Document Service Status"::"Export Error", EDocServiceStatus.Status, IncorrectValueErr);

        // [THEN] There are 3 logs for document that failed during export
        EDocLog.SetRange("E-Doc. Entry No", EDocumentB."Entry No");
        EDocLog.SetRange(Status);
        Assert.RecordCount(EDocLog, 3);

        AssertEDocLogState(EDocumentB, EDocLog, EDocumentService2, Enum::"E-Document Service Status"::Created);
        AssertEDocLogState(EDocumentB, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Pending Batch");
        AssertEDocLogState(EDocumentB, EDocLog, EDocumentService, Enum::"E-Document Service Status"::"Export Error");

        // [THEN] Mapping log is not created
        EDocMappingLog.SetRange("E-Doc Log Entry No.", EDocLog."Entry No.");
        Assert.RecordIsNotEmpty(EDocMappingLog);

        // Tear down
        LibraryPermission.SetOutsideO365Scope();
        LibraryEDoc.DeleteServiceMapping(EDocumentService);
    end;

    [Test]
    procedure IntegrationLogs()
    var
        EDocument: Record "E-Document";
        EDocumentService2: Record "E-Document Service";
        EDocumentLogRec: Record "E-Document Log";
        EDocumentIntegrationLog: Record "E-Document Integration Log";
        EDocumentServiceStatus: Record "E-Document Service Status";
        EDocumentLog: Codeunit "E-Document Log";
        TempBlob: Codeunit "Temp Blob";
        HttpRequest: HttpRequestMessage;
        HttpResponse: HttpResponseMessage;
    begin
        // [FEATURE] [E-Document] [Log]
        // [SCENARIO] EDocument Log on EDocument recurrent batch when there is errors during export for a document
        // [GIVEN]
        InitIntegrationData(EDocument, EDocumentService2, EDocumentServiceStatus, HttpRequest, HttpResponse);

        // [WHEN] Inserting integration logs
        EDocumentLog.InsertLog(EDocument, EDocumentServiceStatus.Status);
        EDocumentLog.InsertIntegrationLog(EDocument, EDocumentService2, HttpRequest, HttpResponse);

        // [THEN] It should insert EDocumentLog and EDocument integration log.
        Assert.RecordIsNotEmpty(EDocumentLogRec);
        Assert.RecordIsNotEmpty(EDocumentIntegrationLog);
        EDocumentIntegrationLog.FindLast();
        Assert.AreEqual(EDocumentIntegrationLog."E-Doc. Entry No", EDocument."Entry No", 'EDocument integration log should be linked to edocument');
        Assert.AreEqual(HttpRequest.Method(), EDocumentIntegrationLog.Method, 'Integration log should contain method type from request message');
        Assert.AreEqual(HttpRequest.GetRequestUri(), EDocumentIntegrationLog."Request URL", 'Integration log should contain url from request message');

        EDocumentIntegrationLog.CalcFields("Request Blob");
        EDocumentIntegrationLog.CalcFields("Response Blob");

        TempBlob.FromRecord(EDocumentIntegrationLog, EDocumentIntegrationLog.FieldNo(EDocumentIntegrationLog."Request Blob"));
        Assert.AreEqual('Test request', LibraryEDoc.TempBlobToTxt(TempBlob), 'Integration log request blob is not correct');

        Clear(TempBlob);
        TempBlob.FromRecord(EDocumentIntegrationLog, EDocumentIntegrationLog.FieldNo(EDocumentIntegrationLog."Response Blob"));
        Assert.AreEqual('Test response', LibraryEDoc.TempBlobToTxt(TempBlob), 'Integration log response blob is not correct');
    end;

    local procedure InitIntegrationData(var EDocument: Record "E-Document"; var EDocumentService2: Record "E-Document Service"; var EDocumentServiceStatus: Record "E-Document Service Status"; HttpRequest: HttpRequestMessage; HttpResponse: HttpResponseMessage)
    var
        EDocumentIntegrationLog: Record "E-Document Integration Log";
    begin
        LibraryPermission.SetOutsideO365Scope();
        EDocument.DeleteAll();
        EDocumentService2.DeleteAll();
        EDocumentIntegrationLog.DeleteAll();
        HttpRequest.SetRequestUri('http://cronus.test');
        HttpRequest.Method := 'POST';

        HttpRequest.Content.WriteFrom('Test request');
        HttpResponse.Content.WriteFrom('Test response');
        HttpResponse.Headers.Add('Accept', '*');

        EDocument.Insert();
        EDocumentService2.Code := 'Test Service 1';
        EDocumentService2."Service Integration V2" := EDocumentService2."Service Integration V2"::"Mock";
        EDocumentService2.Insert();

        EDocumentServiceStatus."E-Document Entry No" := EDocument."Entry No";
        EDocumentServiceStatus."E-Document Service Code" := EDocumentService2.Code;
        EDocumentServiceStatus.Insert();
    end;

    local procedure AssertEDocLogState(var EDocument: Record "E-Document"; var EDocLog: Record "E-Document Log"; var EDocumentService2: Record "E-Document Service"; Status: Enum "E-Document Service Status")
    begin
        EDocLog.SetRange(Status, Status);
        Assert.RecordCount(EDocLog, 1);
        EDocLog.FindFirst();
        AssertLogValues(EDocument, EDocLog, EDocumentService2, Status);
    end;

    local procedure AssertLogValues(var EDocument: Record "E-Document"; var EDocLog: Record "E-Document Log"; var EDocumentService2: Record "E-Document Service"; Status: Enum "E-Document Service Status")
    begin
        Assert.AreEqual(EDocument."Entry No", EDocLog."E-Doc. Entry No", IncorrectValueErr);
        Assert.AreEqual(EDocLog."Document Type"::"Sales Invoice", EDocLog."Document Type", IncorrectValueErr);
        Assert.AreEqual(EDocumentService2.Code, EDocLog."Service Code", IncorrectValueErr);
#if not CLEAN26
#pragma warning disable AL0432
        Assert.AreEqual(EDocumentService2."Service Integration", EDocLog."Service Integration", IncorrectValueErr);
#pragma warning restore AL0432
#endif
        Assert.AreEqual(Status, EDocLog.Status, IncorrectValueErr);
    end;

    local procedure Initialize(Integration: Enum "Service Integration")
    var
        TransformationRule: Record "Transformation Rule";
    begin
        LibraryPermission.SetOutsideO365Scope();
        if IsInitialized then
            exit;

        LibraryEDoc.SetupStandardVAT();
        LibraryEDoc.SetupStandardSalesScenario(Customer, EDocumentService, Enum::"E-Document Format"::Mock, Integration);
        ErrorInExport := false;
        FailLastEntryInBatch := false;

        LibraryVariableStorage.Clear();
        TransformationRule.DeleteAll();
        TransformationRule.CreateDefaultTransformations();

        IsInitialized := true;
    end;

    procedure SetVariableStorage(var NewLibraryVariableStorage: Codeunit "Library - Variable Storage")
    begin
        LibraryVariableStorage := NewLibraryVariableStorage;
    end;

    procedure GetVariableStorage(var NewLibraryVariableStorage: Codeunit "Library - Variable Storage")
    begin
        NewLibraryVariableStorage := LibraryVariableStorage;
    end;

    procedure SetLastEntryInBatchToError()
    begin
        FailLastEntryInBatch := true;
    end;

    procedure SetExportError()
    begin
        ErrorInExport := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Export", 'OnAfterCreateEDocument', '', false, false)]
    local procedure OnAfterCreateEDocument(var EDocument: Record "E-Document")
    begin
        LibraryVariableStorage.Enqueue(EDocument);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Export", 'OnBeforeCreateEDocument', '', false, false)]
    local procedure OnBeforeCreatedEDocument(var EDocument: Record "E-Document")
    begin
        LibraryVariableStorage.Enqueue(EDocument);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Format Mock", 'OnCheck', '', false, false)]
    local procedure OnCheck(var SourceDocumentHeader: RecordRef; EDocService: Record "E-Document Service"; EDocumentProcessingPhase: enum "E-Document Processing Phase")
    begin
        LibraryVariableStorage.Enqueue(SourceDocumentHeader);
        LibraryVariableStorage.Enqueue(EDocService);
        LibraryVariableStorage.Enqueue(EDocumentProcessingPhase);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Format Mock", 'OnCreate', '', false, false)]
    local procedure OnCreate(EDocService: Record "E-Document Service"; var EDocument: Record "E-Document"; var SourceDocumentHeader: RecordRef; var SourceDocumentLines: RecordRef; var TempBlob: codeunit "Temp Blob")
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
        OutStream: OutStream;
    begin
        TempBlob.CreateOutStream(OutStream);
        OutStream.WriteText('TEST');
        LibraryVariableStorage.Enqueue(TempBlob.Length());

        if ErrorInExport then
            EDocErrorHelper.LogSimpleErrorMessage(EDocument, 'ERROR');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Format Mock", 'OnCreateBatch', '', false, false)]
    local procedure OnCreateBatch(EDocService: Record "E-Document Service"; var EDocuments: Record "E-Document"; var SourceDocumentHeaders: RecordRef; var SourceDocumentsLines: RecordRef; var TempBlob: codeunit "Temp Blob");
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
        OutStream: OutStream;
    begin
        TempBlob.CreateOutStream(OutStream);
        OutStream.WriteText('TEST');
        LibraryVariableStorage.Enqueue(TempBlob.Length());

        if FailLastEntryInBatch then begin
            EDocuments.FindLast();
            EDocErrorHelper.LogSimpleErrorMessage(EDocuments, 'ERROR');
        end;
    end;

}
