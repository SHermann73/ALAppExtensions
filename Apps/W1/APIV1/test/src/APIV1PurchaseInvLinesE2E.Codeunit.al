codeunit 139738 "APIV1 - Purchase Inv Lines E2E"
{
    // version Test,ERM,W1,All

    Subtype = Test;
    TestType = Uncategorized;
    TestPermissions = Disabled;

    trigger OnRun()
    begin
        // [FEATURE] [Graph] [Purchase] [Invoice]
    end;

    var
        Assert: Codeunit "Assert";
        SalesInvoiceAggregator: Codeunit "Sales Invoice Aggregator";
        APIV1SalesInvLinesE2E: Codeunit "APIV1 - Sales Inv. Lines E2E";
        LibraryGraphMgt: Codeunit "Library - Graph Mgt";
        LibraryUtility: Codeunit "Library - Utility";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryGraphDocumentTools: Codeunit "Library - Graph Document Tools";
        LibraryRandom: Codeunit "Library - Random";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySmallBusiness: Codeunit "Library - Small Business";
        LibraryApplicationArea: Codeunit "Library - Application Area";
        LibraryERMCountryData: Codeunit "Library - ERM Country Data";
        IsInitialized: Boolean;
        InvoiceServiceNameTxt: Label 'purchaseInvoices';
        InvoiceServiceLinesNameTxt: Label 'purchaseInvoiceLines';
        LineTypeFieldNameTxt: Label 'lineType';

    local procedure Initialize()
    begin
        IF IsInitialized THEN
            EXIT;

        LibraryApplicationArea.EnableFoundationSetup();
        LibraryERMCountryData.CreateGeneralPostingSetupData();
        LibraryERMCountryData.UpdateGeneralPostingSetup();
        IsInitialized := TRUE;
        COMMIT();
    end;

    [Test]
    procedure TestFailsOnIDAbsense()
    var
        ResponseText: Text;
        TargetURL: Text;
    begin
        // [SCENARIO] Call GET on the lines without providing a parent Invoice ID.
        // [GIVEN] the invoice API exposed
        Initialize();

        // [WHEN] we GET all the lines without an ID from the web service
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage('',
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);
        ASSERTERROR LibraryGraphMgt.GetFromWebService(ResponseText, TargetURL);

        // [THEN] the response text should be empty
        Assert.AreEqual('', ResponseText, 'Response JSON should be blank');
    end;

    [Test]
    procedure TestGetInvoiceLineDirectly()
    var
        PurchaseLine: Record "Purchase Line";
        PurchaseHeader: Record "Purchase Header";
        ResponseText: Text;
        TargetURL: Text;
        InvoiceId: Text;
        LineNo: Integer;
        IdValue: Text;
        SequenceValue: Text;
    begin
        // [SCENARIO] Call GET on the Line of a unposted Invoice
        // [GIVEN] An invoice with a line.
        Initialize();
        InvoiceId := CreatePurchaseInvoiceWithLines(PurchaseHeader);

        PurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        PurchaseLine.FINDFIRST();
        LineNo := PurchaseLine."Line No.";

        // [WHEN] we GET all the lines with the unposted invoice ID from the web service
        TargetURL := APIV1SalesInvLinesE2E.GetLinesURL(SalesInvoiceAggregator.GetIdFromDocumentIdAndSequence(InvoiceId, LineNo), PAGE::"APIV1 - Purchase Invoices", InvoiceServiceNameTxt, InvoiceServiceLinesNameTxt);
        LibraryGraphMgt.GetFromWebService(ResponseText, TargetURL);

        // [THEN] the line returned should be valid (numbers and integration id)
        Assert.AreNotEqual('', ResponseText, 'Response JSON should not be blank');
        LibraryGraphMgt.VerifyIDFieldInJson(ResponseText, 'documentId');
        LibraryGraphMgt.GetPropertyValueFromJSON(ResponseText, 'id', IdValue);
        Assert.AreEqual(IdValue, SalesInvoiceAggregator.GetIdFromDocumentIdAndSequence(InvoiceId, LineNo), 'The id value is wrong.');
        LibraryGraphMgt.GetPropertyValueFromJSON(ResponseText, 'sequence', SequenceValue);
        Assert.AreEqual(SequenceValue, FORMAT(LineNo), 'The sequence value is wrong.');
    end;

    [Test]
    procedure TestGetInvoiceLines()
    var
        PurchaseLine: Record "Purchase Line";
        PurchaseHeader: Record "Purchase Header";
        ResponseText: Text;
        TargetURL: Text;
        InvoiceId: Text;
        LineNo1: Text;
        LineNo2: Text;
    begin
        // [SCENARIO] Call GET on the Lines of a unposted Invoice
        // [GIVEN] An invoice with lines.
        Initialize();
        InvoiceId := CreatePurchaseInvoiceWithLines(PurchaseHeader);

        PurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        PurchaseLine.FINDFIRST();
        LineNo1 := FORMAT(PurchaseLine."Line No.");
        PurchaseLine.FINDLAST();
        LineNo2 := FORMAT(PurchaseLine."Line No.");

        // [WHEN] we GET all the lines with the unposted invoice ID from the web service
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);
        LibraryGraphMgt.GetFromWebService(ResponseText, TargetURL);

        // [THEN] the lines returned should be valid (numbers and integration ids)
        VerifyInvoiceLines(ResponseText, LineNo1, LineNo2);
    end;

    [Test]
    procedure TestGetInvoiceLinesDirectlyWithDocumentIdFilter()
    var
        PurchaseLine: Record "Purchase Line";
        PurchaseHeader: Record "Purchase Header";
        ResponseText: Text;
        TargetURL: Text;
        InvoiceId: Text;
        LineNo1: Text;
        LineNo2: Text;
    begin
        // [SCENARIO] Call GET on the Lines of a unposted Invoice
        // [GIVEN] An invoice with lines.
        Initialize();
        InvoiceId := CreatePurchaseInvoiceWithLines(PurchaseHeader);

        PurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        PurchaseLine.FINDFIRST();
        LineNo1 := FORMAT(PurchaseLine."Line No.");
        PurchaseLine.FINDLAST();
        LineNo2 := FORMAT(PurchaseLine."Line No.");

        // [WHEN] we GET all the lines with the unposted invoice ID from the web service
        TargetURL := APIV1SalesInvLinesE2E.GetLinesURLWithDocumentIdFilter(InvoiceId, PAGE::"APIV1 - Purchase Invoices", InvoiceServiceNameTxt, InvoiceServiceLinesNameTxt);
        LibraryGraphMgt.GetFromWebService(ResponseText, TargetURL);

        // [THEN] the lines returned should be valid (numbers and integration ids)
        VerifyInvoiceLines(ResponseText, LineNo1, LineNo2);
    end;

    [Test]
    procedure TestGetPostedInvoiceLines()
    var
        PurchInvLine: Record "Purch. Inv. Line";
        PurchInvHeader: Record "Purch. Inv. Header";
        ResponseText: Text;
        TargetURL: Text;
        PostedInvoiceId: Text;
        LineNo1: Text;
        LineNo2: Text;
    begin
        // [SCENARIO] Call GET on the Lines of a posted Invoice
        // [GIVEN] A posted invoice with lines.
        Initialize();
        PostedInvoiceId := CreatePostedPurchaseInvoiceWithLines(PurchInvHeader);

        PurchInvLine.SETRANGE("Document No.", PurchInvHeader."No.");
        PurchInvLine.FINDFIRST();
        LineNo1 := FORMAT(PurchInvLine."Line No.");
        PurchInvLine.FINDLAST();
        LineNo2 := FORMAT(PurchInvLine."Line No.");

        // [WHEN] we GET all the lines with the posted invoice ID from the web service
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            PostedInvoiceId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);
        LibraryGraphMgt.GetFromWebService(ResponseText, TargetURL);

        // [THEN] the response text should contain the invoice ID
        VerifyInvoiceLines(ResponseText, LineNo1, LineNo2);
    end;

    [Test]
    procedure TestPostInvoiceLines()
    var
        Item: Record "Item";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ResponseText: Text;
        TargetURL: Text;
        InvoiceLineJSON: Text;
        LineNoFromJSON: Text;
        InvoiceID: Text;
        LineNo: Integer;
    begin
        // [SCENARIO] POST a new line to an unposted Invoice
        // [GIVEN] An existing unposted invoice and a valid JSON describing the new invoice line
        Initialize();
        InvoiceID := CreatePurchaseInvoiceWithLines(PurchaseHeader);
        LibraryInventory.CreateItem(Item);

        InvoiceLineJSON := CreateInvoiceLineJSON(Item.SystemId, LibraryRandom.RandIntInRange(1, 100));
        COMMIT();

        // [WHEN] we POST the JSON to the web service
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceID,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);
        LibraryGraphMgt.PostToWebService(TargetURL, InvoiceLineJSON, ResponseText);

        // [THEN] the response text should contain the invoice ID and the change should exist in the database
        Assert.AreNotEqual('', ResponseText, 'response JSON should not be blank');
        Assert.IsTrue(
          LibraryGraphMgt.GetObjectIDFromJSON(ResponseText, 'sequence', LineNoFromJSON), 'Could not find sequence');

        EVALUATE(LineNo, LineNoFromJSON);
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange("Line No.", LineNo);
        Assert.IsFalse(PurchaseLine.IsEmpty(), 'The unposted invoice line should exist');
    end;

    [Test]
    procedure TestPostInvoiceLineWithSequence()
    var
        Item: Record "Item";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ResponseText: Text;
        TargetURL: Text;
        InvoiceLineJSON: Text;
        LineNoFromJSON: Text;
        InvoiceID: Text;
        LineNo: Integer;
    begin
        // [SCENARIO] POST a new line to an unposted Invoice with a sequence number
        // [GIVEN] An existing unposted invoice and a valid JSON describing the new invoice line
        Initialize();
        InvoiceID := CreatePurchaseInvoiceWithLines(PurchaseHeader);
        LibraryInventory.CreateItem(Item);

        InvoiceLineJSON := CreateInvoiceLineJSON(Item.SystemId, LibraryRandom.RandIntInRange(1, 100));
        LineNo := 500;
        InvoiceLineJSON := LibraryGraphMgt.AddPropertytoJSON(InvoiceLineJSON, 'sequence', LineNo);
        COMMIT();

        // [WHEN] we POST the JSON to the web service
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceID,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);
        LibraryGraphMgt.PostToWebService(TargetURL, InvoiceLineJSON, ResponseText);

        // [THEN] the response text should contain the correct sequence and exist in the database
        Assert.AreNotEqual('', ResponseText, 'response JSON should not be blank');
        Assert.IsTrue(
          LibraryGraphMgt.GetObjectIDFromJSON(ResponseText, 'sequence', LineNoFromJSON), 'Could not find sequence');
        Assert.AreEqual(FORMAT(LineNo), LineNoFromJSON, 'The sequence in the response does not exist of the one that was given.');

        PurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        PurchaseLine.SETRANGE("Line No.", LineNo);
        Assert.IsTrue(PurchaseLine.FINDFIRST(), 'The unposted invoice line should exist');
        Assert.AreEqual(PurchaseLine."Line No.", LineNo, 'The line should have the line no that was given.');
    end;

    [Test]
    procedure TestModifyInvoiceLines()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ResponseText: Text;
        TargetURL: Text;
        InvoiceLineJSON: Text;
        LineNo: Integer;
        InvoiceId: Text;
        PurchaseQuantity: Integer;
        PurchaseQuantityFromJSON: Text;
    begin
        // [SCENARIO] PATCH a line of an unposted Invoice
        // [GIVEN] An unposted invoice with lines and a valid JSON describing the fields that we want to change
        Initialize();
        InvoiceId := CreatePurchaseInvoiceWithLines(PurchaseHeader);
        Assert.AreNotEqual('', InvoiceId, 'ID should not be empty');
        PurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        PurchaseLine.FINDFIRST();
        LineNo := PurchaseLine."Line No.";

        PurchaseQuantity := 4;
        InvoiceLineJSON := LibraryGraphMgt.AddComplexTypetoJSON('{}', 'quantity', FORMAT(PurchaseQuantity));

        // [WHEN] we PATCH the line
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            APIV1SalesInvLinesE2E.GetLineSubURL(InvoiceId, LineNo, InvoiceServiceLinesNameTxt));
        LibraryGraphMgt.PatchToWebService(TargetURL, InvoiceLineJSON, ResponseText);

        // [THEN] the line should be changed in the table and the response JSON text should contain our changed field
        Assert.AreNotEqual('', ResponseText, 'Response JSON should not be blank');

        PurchaseLine.RESET();
        PurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        PurchaseLine.SETRANGE("Line No.", LineNo);
        Assert.IsTrue(PurchaseLine.FINDFIRST(), 'The unposted invoice line should exist after modification');
        Assert.AreEqual(PurchaseLine.Quantity, PurchaseQuantity, 'The patch of Purchase line quantity was unsuccessful');

        Assert.IsTrue(LibraryGraphMgt.GetPropertyValueFromJSON(ResponseText, 'quantity', PurchaseQuantityFromJSON),
          'Could not find the quantity property in' + ResponseText);
        Assert.AreNotEqual('', PurchaseQuantityFromJSON, 'Quantity should not be blank in ' + ResponseText);
    end;

    [Test]
    procedure TestModifyInvoiceLineFailsOnSequenceIdOrDocumentIdChange()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ResponseText: Text;
        TargetURL: Text;
        InvoiceLineJSON: Array[3] of Text;
        LineNo: Integer;
        InvoiceId: Text;
        NewSequence: Integer;
    begin
        // [SCENARIO] PATCH a line of an unposted Invoice will fail if sequence is modified
        // [GIVEN] An unposted invoice with lines and a valid JSON describing the fields that we want to change
        Initialize();
        InvoiceId := CreatePurchaseInvoiceWithLines(PurchaseHeader);
        Assert.AreNotEqual('', InvoiceId, 'ID should not be empty');
        PurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        PurchaseLine.FINDFIRST();
        LineNo := PurchaseLine."Line No.";

        NewSequence := PurchaseLine."Line No." + 1;
        InvoiceLineJSON[1] := LibraryGraphMgt.AddPropertytoJSON('', 'sequence', NewSequence);
        InvoiceLineJSON[2] := LibraryGraphMgt.AddPropertytoJSON('', 'documentId', LibraryGraphMgt.StripBrackets(CreateGuid()));
        InvoiceLineJSON[3] := LibraryGraphMgt.AddPropertytoJSON('', 'id', SalesInvoiceAggregator.GetIdFromDocumentIdAndSequence(CreateGuid(), NewSequence));

        // [WHEN] we PATCH the line
        // [THEN] the request will fail
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceId,
            PAGE::"APIV1 - Sales Invoices",
            InvoiceServiceNameTxt,
            APIV1SalesInvLinesE2E.GetLineSubURL(InvoiceId, LineNo, InvoiceServiceLinesNameTxt));
        ASSERTERROR LibraryGraphMgt.PatchToWebService(TargetURL, InvoiceLineJSON[1], ResponseText);

        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceId,
            PAGE::"APIV1 - Sales Invoices",
            InvoiceServiceNameTxt,
            APIV1SalesInvLinesE2E.GetLineSubURL(InvoiceId, LineNo, InvoiceServiceLinesNameTxt));
        ASSERTERROR LibraryGraphMgt.PatchToWebService(TargetURL, InvoiceLineJSON[2], ResponseText);

        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceId,
            PAGE::"APIV1 - Sales Invoices",
            InvoiceServiceNameTxt,
            APIV1SalesInvLinesE2E.GetLineSubURL(InvoiceId, LineNo, InvoiceServiceLinesNameTxt));
        ASSERTERROR LibraryGraphMgt.PatchToWebService(TargetURL, InvoiceLineJSON[3], ResponseText);
    end;

    [Test]
    procedure TestDeleteInvoiceLine()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ResponseText: Text;
        TargetURL: Text;
        InvoiceId: Text;
        LineNo: Integer;
    begin
        // [SCENARIO] DELETE a line from an unposted Invoice
        // [GIVEN] An unposted invoice with lines
        Initialize();
        InvoiceId := CreatePurchaseInvoiceWithLines(PurchaseHeader);

        PurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        PurchaseLine.FINDFIRST();
        LineNo := PurchaseLine."Line No.";

        COMMIT();

        // [WHEN] we DELETE the first line of that invoice
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            APIV1SalesInvLinesE2E.GetLineSubURL(InvoiceId, LineNo, InvoiceServiceLinesNameTxt));
        LibraryGraphMgt.DeleteFromWebService(TargetURL, '', ResponseText);

        // [THEN] the line should no longer exist in the database
        PurchaseLine.Reset();
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange("Line No.", LineNo);
        Assert.IsTrue(PurchaseLine.IsEmpty(), 'The invoice line should not exist');
    end;

    [Test]
    procedure TestDeletePostedInvoiceLine()
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchInvLine: Record "Purch. Inv. Line";
        ResponseText: Text;
        TargetURL: Text;
        PostedInvoiceId: Text;
        LineNo: Integer;
    begin
        // [SCENARIO] Call DELETE on a line of a posted Invoice
        // [GIVEN] A posted invoice with lines
        Initialize();
        PostedInvoiceId := CreatePostedPurchaseInvoiceWithLines(PurchInvHeader);

        PurchInvLine.SETRANGE("Document No.", PurchInvHeader."No.");
        PurchInvLine.FINDFIRST();
        LineNo := PurchInvLine."Line No.";

        // [WHEN] we DELETE the first line through the API
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            PostedInvoiceId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            APIV1SalesInvLinesE2E.GetLineSubURL(PostedInvoiceId, LineNo, InvoiceServiceLinesNameTxt));
        ASSERTERROR LibraryGraphMgt.DeleteFromWebService(TargetURL, '', ResponseText);

        // [THEN] the line should still exist, since it's not allowed to delete lines in posted invoices
        PurchInvLine.Reset();
        PurchInvLine.SetRange("Document No.", PurchInvHeader."No.");
        PurchInvLine.SetRange("Line No.", LineNo);
        Assert.IsFalse(PurchInvLine.IsEmpty(), 'The invoice line should still exist');
    end;

    [Test]
    procedure TestCreateLineThroughPageAndAPI()
    var
        PurchaseHeader: Record "Purchase Header";
        Item: Record "Item";
        PagePurchaseLine: Record "Purchase Line";
        ApiPurchaseLine: Record "Purchase Line";
        TempIgnoredFieldsForComparison: Record 2000000041 temporary;
        Vendor: Record "Vendor";
        PageRecordRef: RecordRef;
        ApiRecordRef: RecordRef;
        PurchaseInvoice: TestPage "Purchase Invoice";
        ResponseText: Text;
        TargetURL: Text;
        InvoiceLineJSON: Text;
        LineNoFromJSON: Text;
        InvoiceID: Text;
        LineNo: Integer;
        ItemQuantity: Integer;
        ItemNo: Code[20];
        VendorNo: Code[20];
    begin
        // [SCENARIO] Create an invoice both through the client UI and through the API and compare their final values.
        // [GIVEN] An unposted invoice and a JSON describing the line we want to create
        Initialize();
        LibraryPurchase.CreateVendor(Vendor);
        VendorNo := Vendor."No.";
        ItemNo := LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, VendorNo);
        InvoiceID := PurchaseHeader.SystemId;
        ItemQuantity := LibraryRandom.RandIntInRange(1, 100);
        InvoiceLineJSON := CreateInvoiceLineJSON(Item.SystemId, ItemQuantity);
        COMMIT();

        // [WHEN] we POST the JSON to the web service and when we create an invoice through the client UI
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceID,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);
        LibraryGraphMgt.PostToWebService(TargetURL, InvoiceLineJSON, ResponseText);

        // [THEN] the response text should be valid, the invoice line should exist in the tables and the two invoices have the same field values.
        Assert.AreNotEqual('', ResponseText, 'response JSON should not be blank');
        Assert.IsTrue(
          LibraryGraphMgt.GetObjectIDFromJSON(ResponseText, 'sequence', LineNoFromJSON), 'Could not find sequence');

        EVALUATE(LineNo, LineNoFromJSON);
        ApiPurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type"::Invoice);
        ApiPurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        ApiPurchaseLine.SETRANGE("Line No.", LineNo);
        Assert.IsTrue(ApiPurchaseLine.FINDFIRST(), 'The unposted invoice line should exist');

        CreateInvoiceAndLinesThroughPage(PurchaseInvoice, VendorNo, ItemNo, ItemQuantity);

        PagePurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type"::Invoice);
        PagePurchaseLine.SETRANGE("Document No.", PurchaseInvoice."No.".VALUE());
        Assert.IsTrue(PagePurchaseLine.FINDFIRST(), 'The unposted invoice line should exist');

        ApiRecordRef.GETTABLE(ApiPurchaseLine);
        PageRecordRef.GETTABLE(PagePurchaseLine);

        // Ignore these fields when comparing Page and API invoices
        LibraryUtility.AddTempField(TempIgnoredFieldsForComparison, ApiPurchaseLine.FIELDNO("Line No."), DATABASE::"Purchase Line");
        LibraryUtility.AddTempField(TempIgnoredFieldsForComparison, ApiPurchaseLine.FIELDNO("Document No."), DATABASE::"Purchase Line");
        LibraryUtility.AddTempField(TempIgnoredFieldsForComparison, ApiPurchaseLine.FIELDNO("No."), DATABASE::"Purchase Line");
        LibraryUtility.AddTempField(TempIgnoredFieldsForComparison, ApiPurchaseLine.FIELDNO(Subtype), DATABASE::"Purchase Line");
        LibraryUtility.AddTempField(
          TempIgnoredFieldsForComparison, ApiPurchaseLine.FIELDNO("Recalculate Invoice Disc."), DATABASE::"Purchase Line"); // TODO: remove once other changes are checked in

        Assert.RecordsAreEqualExceptCertainFields(ApiRecordRef, PageRecordRef, TempIgnoredFieldsForComparison,
          'Page and API Invoice lines do not match');
    end;

    [Test]
    procedure TestInsertingLineUpdatesInvoiceDiscountPct()
    var
        PurchaseHeader: Record "Purchase Header";
        Vendor: Record "Vendor";
        Item: Record "Item";
        TargetURL: Text;
        InvoiceLineJSON: Text;
        ResponseText: Text;
        MinAmount: Decimal;
        DiscountPct: Decimal;
    begin
        // [FEATURE] [Invoice Discount]
        // [SCENARIO] Creating a line through API should update Discount Pct
        // [GIVEN] An unposted invoice for vendor with invoice discount pct
        Initialize();
        CreateInvoiceWithTwoLines(PurchaseHeader, Vendor, Item);
        PurchaseHeader.CALCFIELDS(Amount);
        MinAmount := PurchaseHeader.Amount + Item."Unit Price" / 2;
        DiscountPct := LibraryRandom.RandDecInDecimalRange(1, 90, 2);
        LibrarySmallBusiness.SetInvoiceDiscountToVendor(Vendor, DiscountPct, MinAmount, PurchaseHeader."Currency Code");
        InvoiceLineJSON := CreateInvoiceLineJSON(Item.SystemId, LibraryRandom.RandIntInRange(1, 100));
        COMMIT();

        // [WHEN] We create a line through API
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            PurchaseHeader.SystemId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);
        LibraryGraphMgt.PostToWebService(TargetURL, InvoiceLineJSON, ResponseText);

        // [THEN] Invoice discount is applied
        Assert.AreNotEqual('', ResponseText, 'Response JSON should not be blank');
        LibraryGraphMgt.VerifyIDFieldInJson(ResponseText, 'itemId');
        VerifyTotals(PurchaseHeader, DiscountPct, PurchaseHeader."Invoice Discount Calculation"::"%");
    end;

    [Test]
    procedure TestModifyingLineUpdatesInvoiceDiscountPct()
    var
        PurchaseHeader: Record "Purchase Header";
        Vendor: Record "Vendor";
        Item: Record "Item";
        PurchaseLine: Record "Purchase Line";
        TargetURL: Text;
        InvoiceLineJSON: Text;
        ResponseText: Text;
        MinAmount: Decimal;
        DiscountPct: Decimal;
        PurchaseQuantity: Integer;
    begin
        // [FEATURE] [Invoice Discount]
        // [SCENARIO] Modifying a line through API should update Discount Pct
        // [GIVEN] An unposted invoice for vendor with invoice discount pct
        Initialize();
        CreateInvoiceWithTwoLines(PurchaseHeader, Vendor, Item);
        PurchaseHeader.CALCFIELDS(Amount);
        MinAmount := PurchaseHeader.Amount + Item."Unit Price" / 2;
        DiscountPct := LibraryRandom.RandDecInDecimalRange(1, 90, 2);
        LibrarySmallBusiness.SetInvoiceDiscountToVendor(Vendor, DiscountPct, MinAmount, PurchaseHeader."Currency Code");
        InvoiceLineJSON := CreateInvoiceLineJSON(Item.SystemId, LibraryRandom.RandIntInRange(1, 100));
        FindFirstPurchaseLine(PurchaseHeader, PurchaseLine);
        PurchaseQuantity := PurchaseLine.Quantity * 2;

        COMMIT();

        InvoiceLineJSON := LibraryGraphMgt.AddComplexTypetoJSON('{}', 'quantity', FORMAT(PurchaseQuantity));

        // [WHEN] we PATCH the line
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            PurchaseHeader.SystemId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            APIV1SalesInvLinesE2E.GetLineSubURL(PurchaseHeader.SystemId, PurchaseLine."Line No.", InvoiceServiceLinesNameTxt));
        LibraryGraphMgt.PatchToWebService(TargetURL, InvoiceLineJSON, ResponseText);

        // [THEN] Invoice discount is applied
        Assert.AreNotEqual('', ResponseText, 'Response JSON should not be blank');
        LibraryGraphMgt.VerifyIDFieldInJson(ResponseText, 'itemId');
        VerifyTotals(PurchaseHeader, DiscountPct, PurchaseHeader."Invoice Discount Calculation"::"%");
    end;

    [Test]
    procedure TestDeletingLineRemovesInvoiceDiscountPct()
    var
        PurchaseHeader: Record "Purchase Header";
        Vendor: Record "Vendor";
        Item: Record "Item";
        PurchaseLine: Record "Purchase Line";
        TargetURL: Text;
        ResponseText: Text;
        MinAmount: Decimal;
        DiscountPct: Decimal;
    begin
        // [FEATURE] [Invoice Discount]
        // [SCENARIO] Deleting a line through API should update Discount Pct
        // [GIVEN] An unposted invoice for vendor with invoice discount pct
        Initialize();
        CreateInvoiceWithTwoLines(PurchaseHeader, Vendor, Item);
        PurchaseHeader.CALCFIELDS(Amount);
        FindFirstPurchaseLine(PurchaseHeader, PurchaseLine);

        MinAmount := PurchaseHeader.Amount - PurchaseLine."Line Amount" / 2;
        DiscountPct := LibraryRandom.RandDecInDecimalRange(30, 50, 2);
        LibrarySmallBusiness.SetInvoiceDiscountToVendor(Vendor, DiscountPct, MinAmount, PurchaseHeader."Currency Code");

        CODEUNIT.RUN(CODEUNIT::"Purch - Calc Disc. By Type", PurchaseLine);
        PurchaseHeader.FIND();
        Assert.AreEqual(PurchaseHeader."Invoice Discount Value", DiscountPct, 'Discount Pct was not assigned');
        COMMIT();

        // [WHEN] we DELETE the line
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            PurchaseHeader.SystemId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            APIV1SalesInvLinesE2E.GetLineSubURL(PurchaseHeader.SystemId, PurchaseLine."Line No.", InvoiceServiceLinesNameTxt));
        LibraryGraphMgt.DeleteFromWebService(TargetURL, '', ResponseText);

        // [THEN] Lower Invoice discount is applied
        VerifyTotals(PurchaseHeader, 0, PurchaseHeader."Invoice Discount Calculation"::"%");
        RecallNotifications();
    end;

    [Test]
    procedure TestInsertingLineKeepsInvoiceDiscountAmt()
    var
        PurchaseHeader: Record "Purchase Header";
        Item: Record "Item";
        TargetURL: Text;
        ResponseText: Text;
        InvoiceLineJSON: Text;
        DiscountAmount: Decimal;
    begin
        // [FEATURE] [Invoice Discount]
        // [SCENARIO] Adding an invoice through API will keep Discount Amount
        // [GIVEN] An unposted invoice for vendor with invoice discount amount
        Initialize();
        SetupAmountDiscountTest(PurchaseHeader, DiscountAmount);
        InvoiceLineJSON := CreateInvoiceLineJSON(Item.SystemId, LibraryRandom.RandIntInRange(1, 100));

        COMMIT();

        // [WHEN] We create a line through API
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            PurchaseHeader.SystemId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);
        ASSERTERROR LibraryGraphMgt.PostToWebService(TargetURL, InvoiceLineJSON, ResponseText);

        // [THEN] Discount Amount is Kept
        VerifyTotals(PurchaseHeader, DiscountAmount, PurchaseHeader."Invoice Discount Calculation"::Amount);
        RecallNotifications();
    end;

    [Test]
    procedure TestPostingBlankLineDefaultsToItemType()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        TargetURL: Text;
        ResponseText: Text;
        InvoiceLineJSON: Text;
    begin
        // [SCENARIO] Posting a line with description only will get a type item
        // [GIVEN] A post request with description only
        Initialize();
        CreatePurchaseInvoiceWithLines(PurchaseHeader);

        COMMIT();

        InvoiceLineJSON := '{"description":"test"}';

        // [WHEN] we just POST a blank line
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            PurchaseHeader.SystemId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);
        LibraryGraphMgt.PostToWebService(TargetURL, InvoiceLineJSON, ResponseText);

        // [THEN] Line of type Item is created
        FindFirstPurchaseLine(PurchaseHeader, PurchaseLine);
        PurchaseLine.FINDLAST();
        Assert.AreEqual('', PurchaseLine."No.", 'No should be blank');
        Assert.AreEqual(PurchaseLine.Type, PurchaseLine.Type::Item, 'Wrong type is set');

        VerifyIdsAreBlank(ResponseText);
    end;

    [Test]
    procedure TestPostingCommentLine()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        TargetURL: Text;
        ResponseText: Text;
        InvoiceLineJSON: Text;
    begin
        // [FEATURE] [Comment Line]
        // [SCENARIO] Posting a line with Type Comment and description will make a comment line
        // [GIVEN] A post request with type and description
        Initialize();
        CreatePurchaseInvoiceWithLines(PurchaseHeader);

        InvoiceLineJSON := '{"' + LineTypeFieldNameTxt + '":"Comment","description":"test"}';

        COMMIT();

        // [WHEN] we just POST a blank line
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            PurchaseHeader.SystemId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);
        LibraryGraphMgt.PostToWebService(TargetURL, InvoiceLineJSON, ResponseText);

        // [THEN] Line of type Item is created
        FindFirstPurchaseLine(PurchaseHeader, PurchaseLine);
        PurchaseLine.FINDLAST();
        Assert.AreEqual(PurchaseLine.Type, PurchaseLine.Type::" ", 'Wrong type is set');
        Assert.AreEqual('test', PurchaseLine.Description, 'Wrong description is set');

        LibraryGraphDocumentTools.VerifyPurchaseObjectTxtDescription(PurchaseLine, ResponseText);
        VerifyIdsAreBlank(ResponseText);
    end;

    [Test]
    procedure TestPatchingTheTypeBlanksIds()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchInvLineAggregate: Record "Purch. Inv. Line Aggregate";
        PurchaseLine: Record "Purchase Line";
        TargetURL: Text;
        ResponseText: Text;
        InvoiceLineJSON: Text;
        InvoiceId: Text;
        LineNo: Integer;
    begin
        // [SCENARIO] PATCH a Type on a line of an unposted Invoice
        // [GIVEN] An unposted invoice with lines and a valid JSON describing the fields that we want to change
        Initialize();
        InvoiceId := CreatePurchaseInvoiceWithLines(PurchaseHeader);
        Assert.AreNotEqual('', InvoiceId, 'ID should not be empty');
        FindFirstPurchaseLine(PurchaseHeader, PurchaseLine);
        LineNo := PurchaseLine."Line No.";

        InvoiceLineJSON := STRSUBSTNO('{"%1":"%2"}', LineTypeFieldNameTxt, FORMAT(PurchInvLineAggregate."API Type"::Account));

        // [WHEN] we PATCH the line
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceId,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            APIV1SalesInvLinesE2E.GetLineSubURL(InvoiceId, LineNo, InvoiceServiceLinesNameTxt));
        LibraryGraphMgt.PatchToWebService(TargetURL, InvoiceLineJSON, ResponseText);

        // [THEN] Line type is changed to Account
        FindFirstPurchaseLine(PurchaseHeader, PurchaseLine);
        Assert.AreEqual(PurchaseLine.Type::"G/L Account", PurchaseLine.Type, 'Type was not changed');
        Assert.AreEqual('', PurchaseLine."No.", 'No should be blank');

        VerifyIdsAreBlank(ResponseText);
    end;

    [Test]
    procedure TestPostInvoiceLinesWithItemVariant()
    var
        Item: Record "Item";
        ItemVariant: Record "Item Variant";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ItemNo: Code[20];
        ItemVariantCode: Code[10];
        ResponseText: Text;
        TargetURL: Text;
        InvoiceLineJSON: Text;
        LineNoFromJSON: Text;
        InvoiceID: Text;
        LineNo: Integer;
    begin
        // [SCENARIO] POST a new line to an unposted Invoice with item variant
        // [GIVEN] An existing unposted invoice and a valid JSON describing the new invoice line with item variant
        Initialize();
        InvoiceID := CreatePurchaseInvoiceWithLines(PurchaseHeader);
        ItemNo := LibraryInventory.CreateItem(Item);
        ItemVariantCode := LibraryInventory.CreateItemVariant(ItemVariant, ItemNo);
        Commit();

        // [WHEN] we POST the JSON to the web service
        InvoiceLineJSON := CreateInvoiceLineJSONWithItemVariantId(Item.SystemId, LibraryRandom.RandIntInRange(1, 100), ItemVariant.SystemId);
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceID,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);
        LibraryGraphMgt.PostToWebService(TargetURL, InvoiceLineJSON, ResponseText);

        // [THEN] the response text should contain the invoice ID and the change should exist in the database
        Assert.AreNotEqual('', ResponseText, 'response JSON should not be blank');
        Assert.IsTrue(
          LibraryGraphMgt.GetObjectIDFromJSON(ResponseText, 'sequence', LineNoFromJSON), 'Could not find sequence');

        Evaluate(LineNo, LineNoFromJSON);
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type"::Invoice);
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange("Line No.", LineNo);
        PurchaseLine.SetRange("Variant Code", ItemVariantCode);
        Assert.IsFalse(PurchaseLine.IsEmpty(), 'The unposted invoice line should exist');
    end;

    [Test]
    procedure TestPostInvoiceLinesWithWrongItemVariant()
    var
        Item1: Record "Item";
        Item2: Record "Item";
        ItemVariant: Record "Item Variant";
        PurchaseHeader: Record "Purchase Header";
        ItemNo2: Code[20];
        ResponseText: Text;
        TargetURL: Text;
        InvoiceLineJSON: Text;
        InvoiceID: Text;
    begin
        // [SCENARIO] POST a new line to an unposted Invoice with wrong item variant
        // [GIVEN] An existing unposted invoice and a valid JSON describing the new invoice line with item variant
        Initialize();
        InvoiceID := CreatePurchaseInvoiceWithLines(PurchaseHeader);
        LibraryInventory.CreateItem(Item1);
        ItemNo2 := LibraryInventory.CreateItem(Item2);
        LibraryInventory.CreateItemVariant(ItemVariant, ItemNo2);
        Commit();

        // [WHEN] we POST the JSON to the web service
        InvoiceLineJSON := CreateInvoiceLineJSONWithItemVariantId(Item1.SystemId, LibraryRandom.RandIntInRange(1, 100), ItemVariant.SystemId);
        TargetURL := LibraryGraphMgt
          .CreateTargetURLWithSubpage(
            InvoiceID,
            PAGE::"APIV1 - Purchase Invoices",
            InvoiceServiceNameTxt,
            InvoiceServiceLinesNameTxt);

        // [THEN] the response text should contain the invoice ID and the change should exist in the database
        asserterror LibraryGraphMgt.PostToWebService(TargetURL, InvoiceLineJSON, ResponseText);
    end;

    local procedure CreatePurchaseInvoiceWithLines(var PurchaseHeader: Record "Purchase Header"): Text
    var
        PurchaseLine: Record "Purchase Line";
        Item: Record "Item";
    begin
        LibraryPurchase.CreatePurchaseInvoice(PurchaseHeader);
        LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 2);
        COMMIT();
        EXIT(PurchaseHeader.SystemId);
    end;

    local procedure CreatePostedPurchaseInvoiceWithLines(var PurchInvHeader: Record "Purch. Inv. Header"): Text
    var
        PurchaseLine: Record "Purchase Line";
        Item: Record "Item";
        PurchaseHeader: Record "Purchase Header";
        PostedPurchaseInvoiceID: Text;
        NewNo: Code[20];
    begin
        LibraryPurchase.CreatePurchaseInvoice(PurchaseHeader);
        LibraryInventory.CreateItem(Item);
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 2);
        PostedPurchaseInvoiceID := PurchaseHeader.SystemId;
        NewNo := LibraryPurchase.PostPurchaseDocument(PurchaseHeader, FALSE, TRUE);
        COMMIT();

        PurchInvHeader.RESET();
        PurchInvHeader.SETFILTER("No.", NewNo);
        PurchInvHeader.FINDFIRST();

        EXIT(PostedPurchaseInvoiceID);
    end;

    [Normal]
    local procedure CreateInvoiceLineJSON(ItemId: Guid; Quantity: Integer): Text
    var
        LineJSON: Text;
    begin
        LineJSON := LibraryGraphMgt.AddPropertytoJSON('', 'itemId', LibraryGraphMgt.StripBrackets(Format(ItemId)));
        LineJSON := LibraryGraphMgt.AddComplexTypetoJSON(LineJSON, 'quantity', FORMAT(Quantity));
        LineJSON := LibraryGraphMgt.AddComplexTypetoJSON(LineJSON, 'unitCost', FORMAT(1000));
        EXIT(LineJSON);
    end;

    local procedure CreateInvoiceLineJSONWithItemVariantId(ItemId: Guid; Quantity: Integer; ItemVariantId: Guid): Text
    var
        LineJSON: Text;
    begin
        LineJSON := CreateInvoiceLineJSON(ItemId, Quantity);
        LineJSON := LibraryGraphMgt.AddPropertytoJSON(LineJSON, 'itemVariantId', LibraryGraphMgt.StripBrackets(Format(ItemVariantId)));
        exit(LineJSON);
    end;

    local procedure CreateInvoiceAndLinesThroughPage(var PurchaseInvoice: TestPage "Purchase Invoice"; VendorNo: Text; ItemNo: Text; ItemQuantity: Integer)
    begin
        PurchaseInvoice.OPENNEW();
        PurchaseInvoice."Document Date".SETVALUE(WORKDATE());
        PurchaseInvoice."Buy-from Vendor No.".SETVALUE(VendorNo);

        PurchaseInvoice.PurchLines.LAST();
        PurchaseInvoice.PurchLines."No.".SETVALUE(ItemNo);
        PurchaseInvoice.PurchLines."Direct Unit Cost".SETVALUE(1000);

        PurchaseInvoice.PurchLines.Quantity.SETVALUE(ItemQuantity);

        // Trigger Save
        PurchaseInvoice.PurchLines.Next();
        PurchaseInvoice.PurchLines.Previous();
    end;

    local procedure VerifyInvoiceLines(ResponseText: Text; LineNo1: Text; LineNo2: Text)
    var
        LineJSON1: Text;
        LineJSON2: Text;
        ItemId1: Text;
        ItemId2: Text;
    begin
        Assert.AreNotEqual('', ResponseText, 'Response JSON should not be blank');
        Assert.IsTrue(
          LibraryGraphMgt.GetObjectsFromJSONResponse(
            ResponseText, 'sequence', LineNo1, LineNo2, LineJSON1, LineJSON2),
          'Could not find the invoice lines in JSON');
        LibraryGraphMgt.VerifyIDFieldInJson(LineJSON1, 'documentId');
        LibraryGraphMgt.VerifyIDFieldInJson(LineJSON2, 'documentId');
        LibraryGraphMgt.GetObjectIDFromJSON(LineJSON1, 'itemId', ItemId1);
        LibraryGraphMgt.GetObjectIDFromJSON(LineJSON2, 'itemId', ItemId2);
        Assert.AreNotEqual(ItemId1, ItemId2, 'Item Ids should be different for different items');
    end;

    local procedure VerifyIdsAreBlank(JsonObjectTxt: Text)
    var
        itemId: Text;
        accountId: Text;
        ExpectedId: Text;
        BlankGuid: Guid;
    begin
        ExpectedId := LibraryGraphMgt.StripBrackets(Format(BlankGuid));

        Assert.IsTrue(LibraryGraphMgt.GetPropertyValueFromJSON(JsonObjectTxt, 'itemId', itemId), 'Could not find itemId');
        Assert.IsTrue(LibraryGraphMgt.GetPropertyValueFromJSON(JsonObjectTxt, 'accountId', accountId), 'Could not find accountId');

        Assert.AreEqual(UPPERCASE(ExpectedId), UPPERCASE(accountId), 'Account id should be blank');
        Assert.AreEqual(UPPERCASE(ExpectedId), UPPERCASE(itemId), 'Item id should be blank');
    end;

    local procedure CreateInvoiceWithTwoLines(var PurchaseHeader: Record "Purchase Header"; var Vendor: Record "Vendor"; var Item: Record "Item")
    var
        PurchaseLine: Record "Purchase Line";
        Quantity: Integer;
    begin
        LibraryInventory.CreateItemWithUnitPriceUnitCostAndPostingGroup(
          Item, LibraryRandom.RandDecInDecimalRange(1000, 3000, 2), LibraryRandom.RandDecInDecimalRange(1000, 3000, 2));
        LibraryPurchase.CreateVendor(Vendor);
        Quantity := LibraryRandom.RandIntInRange(1, 10);

        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", Quantity);
        PurchaseLine.VALIDATE(Amount, LibraryRandom.RandIntInRange(1, 10));
        PurchaseLine.VALIDATE("Direct Unit Cost", LibraryRandom.RandDecInDecimalRange(1000, 3000, 2));
        PurchaseLine.MODIFY(TRUE);
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", Quantity);
        PurchaseLine.VALIDATE(Amount, LibraryRandom.RandIntInRange(1, 10));
        PurchaseLine.VALIDATE("Direct Unit Cost", LibraryRandom.RandDecInDecimalRange(1000, 3000, 2));
        PurchaseLine.MODIFY(TRUE);
    end;

    local procedure VerifyTotals(var PurchaseHeader: Record "Purchase Header"; ExpectedInvDiscValue: Decimal; ExpectedInvDiscType: Option)
    var
        PurchInvEntityAggregate: Record "Purch. Inv. Entity Aggregate";
    begin
        PurchaseHeader.FIND();
        PurchaseHeader.CALCFIELDS(Amount, "Amount Including VAT", "Invoice Discount Amount", "Recalculate Invoice Disc.");
        Assert.AreEqual(ExpectedInvDiscType, PurchaseHeader."Invoice Discount Calculation", 'Wrong invoice discount type');
        Assert.AreEqual(ExpectedInvDiscValue, PurchaseHeader."Invoice Discount Value", 'Wrong invoice discount value');
        Assert.IsFalse(PurchaseHeader."Recalculate Invoice Disc.", 'Recalculate inv. discount should be false');

        IF ExpectedInvDiscValue = 0 THEN
            Assert.AreEqual(0, PurchaseHeader."Invoice Discount Amount", 'Wrong purchase invoice discount amount')
        ELSE
            Assert.IsTrue(PurchaseHeader."Invoice Discount Amount" > 0, 'Invoice discount amount value is wrong');

        // Verify Aggregate table
        PurchInvEntityAggregate.GET(PurchaseHeader."No.", FALSE);
        Assert.AreEqual(PurchaseHeader.Amount, PurchInvEntityAggregate.Amount, 'Amount was not updated on Aggregate Table');
        Assert.AreEqual(
          PurchaseHeader."Amount Including VAT", PurchInvEntityAggregate."Amount Including VAT",
          'Amount Including VAT was not updated on Aggregate Table');
        Assert.AreEqual(
          PurchaseHeader."Amount Including VAT" - PurchaseHeader.Amount, PurchInvEntityAggregate."Total Tax Amount",
          'Total Tax Amount was not updated on Aggregate Table');
        Assert.AreEqual(
          PurchaseHeader."Invoice Discount Amount", PurchInvEntityAggregate."Invoice Discount Amount",
          'Amount was not updated on Aggregate Table');
    end;

    local procedure FindFirstPurchaseLine(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line")
    begin
        PurchaseLine.SETRANGE("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        PurchaseLine.FINDFIRST();
    end;

    local procedure SetupAmountDiscountTest(var PurchaseHeader: Record "Purchase Header"; var DiscountAmount: Decimal)
    var
        Vendor: Record "Vendor";
        Item: Record "Item";
        PurchCalcDiscByType: Codeunit "Purch - Calc Disc. By Type";
    begin
        CreateInvoiceWithTwoLines(PurchaseHeader, Vendor, Item);
        PurchaseHeader.CALCFIELDS(Amount);
        DiscountAmount := LibraryRandom.RandDecInDecimalRange(1, PurchaseHeader.Amount / 2, 2);
        PurchCalcDiscByType.ApplyInvDiscBasedOnAmt(DiscountAmount, PurchaseHeader);
    end;

    local procedure RecallNotifications()
    var
        NotificationLifecycleMgt: Codeunit "Notification Lifecycle Mgt.";
    begin
        NotificationLifecycleMgt.RecallAllNotifications();
    end;
}


















































































