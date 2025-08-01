namespace Microsoft.DataMigration;

using System.Migration;
using System.Reflection;
using Microsoft.Foundation.NoSeries;
using System.Environment;
using Microsoft.Foundation.AuditCodes;

codeunit 40030 "Table and Field Move Mappings"
{
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;

    var
        BaseAppAppIdLbl: Label '437dbf0e-84ff-417a-965d-ed2bb9650972', Locked = true;
        BaseApplicationTok: Label 'Base Application', Locked = true;
        BusinessFoundationAppIdLbl: Label 'f3552374-a1f2-4356-848e-196002525837', Locked = true;
        BusinessFoundationTok: Label 'Business Foundation', Locked = true;
        SubBillingAppIdLbl: Label '3099ffc7-4cf7-4df6-9b96-7e4bc2bb587c', Locked = true;
        SubBillingOldTok: Label 'Subscription & Recurring Billing', Locked = true;
        SubBillingNewTok: Label 'Subscription Billing', Locked = true;
        SQLInvalidCharsLbl: Label '.""\/''%][', Locked = true;

    local procedure AddMappings()
    begin
        AddNoSeriesMappings();
        AddAuditCodesMappings();
        AddSubBillingMappings();
    end;

    local procedure AddNoSeriesMappings()
    var
        TableNos: List of [Integer];
        AppliesFromVersion: Version;
    begin
        AppliesFromVersion := Version.Create(24, 0);
        TableNos.Add(Database::"No. Series");
        TableNos.Add(Database::"No. Series Line");
        TableNos.Add(Database::"No. Series Relationship");
        AddTableMappingListFromBaseappToBusinessFoundation(TableNos, AppliesFromVersion, true);
        AddTableMappingFromBaseappToBusinessFoundation(Database::"No. Series Tenant", AppliesFromVersion, false); // has replicate data = false?

        AddLocalizationNoSeriesMappings();
    end;

    local procedure AddLocalizationNoSeriesMappings()
    var
        EnvironmentInformation: Codeunit "Environment Information";
        FieldNos: List of [Integer];
        AppliesFromVersion: Version;
    begin
        if EnvironmentInformation.GetApplicationFamily() <> 'IT' then
            exit;
        AppliesFromVersion := Version.Create(24, 0);

        FieldNos.AddRange(12100, 12101, 12102, 12103);
        AddTableFieldMappingListFromBusinessFoundationToBaseApp(Database::"No. Series", FieldNos, AppliesFromVersion, true);
    end;

    local procedure AddAuditCodesMappings()
    var
        TableNos: List of [Integer];
        FieldNos: List of [Integer];
        AppliesFromVersion: Version;
    begin
        AppliesFromVersion := Version.Create(25, 0);
        TableNos.AddRange(Database::"Source Code", Database::"Source Code Setup", Database::"Reason Code", Database::"Return Reason");
        AddTableMappingListFromBaseappToBusinessFoundation(TableNos, AppliesFromVersion, true);

        FieldNos.AddRange(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 840, 900, 1000, 1001, 1100, 1102, 1104, 1105, 1700, 1701, 1702, 5400, 5402, 5403, 5404, 5500, 5502, 5600, 5601, 5602, 5603, 5604, 5605, 5700, 5800, 5801, 5850, 5851, 5875, 5900, 7139, 7300, 7302, 7303, 7304, 7305, 7306, 7307);
        AddTableFieldMappingListFromBusinessFoundationToBaseApp(Database::"Source Code Setup", FieldNos, AppliesFromVersion, true);

        AddTableFieldMappingFromBusinessFoundationToBaseApp(Database::"Return Reason", 3, AppliesFromVersion, true);
        AddTableFieldMappingFromBusinessFoundationToBaseApp(Database::"Return Reason", 4, AppliesFromVersion, true);

        AddLocalizationAuditCodesMappings();
    end;

    local procedure AddLocalizationAuditCodesMappings()
    var
        EnvironmentInformation: Codeunit "Environment Information";
        FieldNos: List of [Integer];
        AppliesFromVersion: Version;
    begin
        AppliesFromVersion := Version.Create(25, 0);
        case EnvironmentInformation.GetApplicationFamily() of
            'AU', 'NZ':
                FieldNos.Add(28040);
            'BE':
                FieldNos.AddRange(11307, 2000020);
            'CA', 'US':
                FieldNos.AddRange(10002, 10003);
            'DE', 'AT', 'CH':
                FieldNos.Add(5005270);
            'ES':
                FieldNos.Add(7000000);
            'FI':
                FieldNos.Add(13400);
            'NL':
                FieldNos.AddRange(11400, 11401);
            'RU':
                FieldNos.AddRange(12400, 12401, 12402, 12403, 12404, 12405, 12406, 12407, 12408, 12409, 12410, 12411, 12470, 12471, 12472, 17301);
        end;
        AddTableFieldMappingListFromBusinessFoundationToBaseApp(Database::"Source Code Setup", FieldNos, AppliesFromVersion, true);
    end;

    local procedure AddSubBillingMappings()
    var
        TableNos: List of [Integer];
        FieldNos: List of [Integer];
        AppliesFromVersion: Version;
    begin
        AppliesFromVersion := Version.Create(26, 0);

        TableNos.AddRange(8051, 8004, 8001, 8002, 8019, 8062, 8065, 8066, 8072, 8010, 8008, 8009, 8007, 8068, 8069, 8056, 8016, 8053, 8052, 8063, 8058, 8005, 8054, 8055, 8012);
        AddTableMappingListSubBilling(TableNos, AppliesFromVersion, true);

        FieldNos.AddRange(20, 21, 30, 31, 33, 34, 39, 52);
        AddTableFieldMappingListSubBilling(8061, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(20, 21, 30, 31, 33, 34, 39, 52);
        AddTableFieldMappingListSubBilling(8064, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(4, 5, 6);
        AddTableFieldMappingListSubBilling(8003, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.Add(4);
        AddTableFieldMappingListSubBilling(8017, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(5, 6, 7, 9, 10);
        AddTableFieldMappingListSubBilling(8006, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.Add(6);
        AddTableFieldMappingListSubBilling(8018, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(2, 3, 4, 6);
        AddTableFieldMappingListSubBilling(8051, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(2, 3, 7, 8, 9, 10, 13, 14, 15);
        AddTableFieldMappingListSubBilling(8004, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(1, 2, 10, 11, 12, 13, 14, 201);
        AddTableFieldMappingListSubBilling(8001, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(1, 3, 6, 7, 14, 19, 26, 27);
        AddTableFieldMappingListSubBilling(8002, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(2, 3, 6, 7, 14, 19, 27, 33, 39, 1005, 8007, 8008, 8010);
        AddTableFieldMappingListSubBilling(8019, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(1, 100, 101, 102, 106);
        AddTableFieldMappingListSubBilling(8062, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(1, 100, 101, 102, 106);
        AddTableFieldMappingListSubBilling(8065, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(2, 5, 22, 23, 24);
        AddTableFieldMappingListSubBilling(8066, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(2, 5, 22, 23, 24);
        AddTableFieldMappingListSubBilling(8072, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(2, 7);
        AddTableFieldMappingListSubBilling(8010, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(2, 100);
        AddTableFieldMappingListSubBilling(8008, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(2, 3, 5, 6, 7, 8, 11, 12, 19, 28, 100, 104);
        AddTableFieldMappingListSubBilling(8009, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(4, 5, 6, 10, 12, 14, 15, 16, 17, 19);
        AddTableFieldMappingListSubBilling(8007, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(20, 21, 22, 31, 50, 51);
        AddTableFieldMappingListSubBilling(8068, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(20, 21, 22);
        AddTableFieldMappingListSubBilling(8069, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.Add(28);
        AddTableFieldMappingListSubBilling(8057, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(1, 3, 6, 7, 14, 19, 27, 33);
        AddTableFieldMappingListSubBilling(8059, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(2, 5, 8, 9, 16, 21, 29, 35, 41, 42, 96);
        AddTableFieldMappingListSubBilling(8073, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(1, 12);
        AddTableFieldMappingListSubBilling(8056, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
        FieldNos.AddRange(6, 7, 21, 22, 23);
        AddTableFieldMappingListSubBilling(8016, FieldNos, AppliesFromVersion, true);
        Clear(FieldNos);
    end;

    local procedure AddTableMappingListFromBaseappToBusinessFoundation(TableNos: List of [Integer]; AppliesFromVersion: Version; PerCompany: Boolean)
    var
        TableNo: Integer;
    begin
        foreach TableNo in TableNos do
            AddTableMappingFromBaseappToBusinessFoundation(TableNo, AppliesFromVersion, PerCompany);
    end;

    local procedure AddTableMappingListSubBilling(TableNos: List of [Integer]; AppliesFromVersion: Version; PerCompany: Boolean)
    var
        TableNo: Integer;
    begin
        foreach TableNo in TableNos do
            AddTableMappingSubBilling(TableNo, AppliesFromVersion, PerCompany);
    end;

    local procedure AddTableMappingFromBaseappToBusinessFoundation(TableNo: Integer; AppliesFromVersion: Version; PerCompany: Boolean)
    var
        RecordRef: RecordRef;
        CurrModuleInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(CurrModuleInfo);
        RecordRef.Open(TableNo);
        AddTableMapping(BaseAppAppIdLbl, BaseApplicationTok, RecordRef.Number, CopyStr(RecordRef.Name, 1, 30), false, '', BusinessFoundationAppIdLbl, BusinessFoundationTok, RecordRef.Number, CopyStr(RecordRef.Name, 1, 30), false, '', AppliesFromVersion, CurrModuleInfo.Id, PerCompany);
    end;

    local procedure AddTableMappingSubBilling(TableNo: Integer; AppliesFromVersion: Version; PerCompany: Boolean)
    var
        RecordRef: RecordRef;
        CurrModuleInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(CurrModuleInfo);
        RecordRef.Open(TableNo);
        AddTableMapping(SubBillingAppIdLbl, SubBillingOldTok, RecordRef.Number, CopyStr(RecordRef.Name, 1, 30), false, '', SubBillingAppIdLbl, SubBillingNewTok, RecordRef.Number, CopyStr(RecordRef.Name, 1, 30), true, '', AppliesFromVersion, CurrModuleInfo.Id, PerCompany);
    end;

    local procedure AddTableFieldMappingListFromBusinessFoundationToBaseApp(TableNo: Integer; FieldNos: List of [Integer]; AppliesFromVersion: Version; PerCompany: Boolean)
    var
        FieldNo: Integer;
    begin
        foreach FieldNo in FieldNos do
            AddTableFieldMappingFromBusinessFoundationToBaseApp(TableNo, FieldNo, AppliesFromVersion, PerCompany);
    end;

    local procedure AddTableFieldMappingListSubBilling(TableNo: Integer; FieldNos: List of [Integer]; AppliesFromVersion: Version; PerCompany: Boolean)
    var
        FieldNo: Integer;
    begin
        foreach FieldNo in FieldNos do
            AddTableFieldMappingSubBilling(TableNo, FieldNo, AppliesFromVersion, PerCompany);
    end;

    local procedure AddTableFieldMappingFromBusinessFoundationToBaseApp(TableNo: Integer; FieldNo: Integer; AppliesFromVersion: Version; PerCompany: Boolean)
    var
        Field: Record Field;
        CurrModuleInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(CurrModuleInfo);
        Field.Get(TableNo, FieldNo);
        AddTableFieldMapping(BusinessFoundationAppIdLbl, BusinessFoundationTok, Field.TableName, Field.FieldName, false, '', BaseAppAppIdLbl, BaseApplicationTok, Field.TableName, true, Field.TableName, Field.FieldName, AppliesFromVersion, CurrModuleInfo.Id, PerCompany);
    end;

    local procedure AddTableFieldMappingSubBilling(TableNo: Integer; FieldNo: Integer; AppliesFromVersion: Version; PerCompany: Boolean)
    var
        Field: Record Field;
        CurrModuleInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(CurrModuleInfo);
        Field.Get(TableNo, FieldNo);
        AddTableFieldMapping(SubBillingAppIdLbl, SubBillingOldTok, Field.TableName, Field.FieldName, false, '', SubBillingAppIdLbl, SubBillingNewTok, Field.TableName, true, Field.TableName, Field.FieldName, AppliesFromVersion, CurrModuleInfo.Id, PerCompany);
    end;

    local procedure AddTableMapping(FromAppID: Guid; FromAppName: Text[150]; FromTableNo: Integer; FromTableName: Text[150]; FromIsExtensionTable: Boolean; FromBaseTableName: Text[150]; ToAppID: Guid; ToAppName: Text[150]; ToTableNo: Integer; ToTableName: Text[150]; ToIsExtensionTable: Boolean; ToBaseTableName: Text[150]; AppliesFromVersion: Version; InserterAppID: Guid; PerCompany: Boolean)
    var
        TableMappings: Record "Table Mappings";
    begin
        TableMappings.SetRange("To Table SQL Name", ConvertNameToSqlName(ToTableName));
        TableMappings.SetRange("To App Name", ToAppName);
        TableMappings.SetRange("To APP ID", ToAppID);
        TableMappings.SetRange("To Base Table SQL Name", ConvertNameToSqlName(ToBaseTableName));
        TableMappings.SetRange("Applies From BC Major Release", AppliesFromVersion.Major);
        TableMappings.SetRange("Applies From BC Minor Release", AppliesFromVersion.Minor);
        if TableMappings.FindFirst() then
            exit;

        // TableMappings."ID" // autoincrement
        TableMappings."From APP ID" := FromAppID;
        TableMappings."From App Name" := FromAppName;
        TableMappings."From Table ID" := FromTableNo;
        TableMappings."From Table Name" := FromTableName;
        TableMappings."From Table SQL Name" := CopyStr(ConvertNameToSqlName(FromTableName), 1, MaxStrLen(TableMappings."From Table SQL Name"));
        TableMappings."From Is Extension Table" := FromIsExtensionTable;
        TableMappings."From Base Table Name" := FromBaseTableName;
        TableMappings."From Base Table SQL Name" := CopyStr(ConvertNameToSqlName(FromBaseTableName), 1, MaxStrLen(TableMappings."From Base Table SQL Name"));
        TableMappings."To APP ID" := ToAppID;
        TableMappings."To App Name" := ToAppName;
        TableMappings."To Table ID" := ToTableNo;
        TableMappings."To Table Name" := ToTableName;
        TableMappings."To Table SQL Name" := CopyStr(ConvertNameToSqlName(ToTableName), 1, MaxStrLen(TableMappings."To Table SQL Name"));
        TableMappings."To Is Extension Table" := ToIsExtensionTable;
        TableMappings."To Base Table Name" := ToBaseTableName;
        TableMappings."To Base Table SQL Name" := CopyStr(ConvertNameToSqlName(ToBaseTableName), 1, MaxStrLen(TableMappings."To Base Table SQL Name"));
        TableMappings."Inserter App ID" := InserterAppID;
        TableMappings."Applies From BC Major Release" := AppliesFromVersion.Major;
        TableMappings."Applies From BC Minor Release" := AppliesFromVersion.Minor;
        TableMappings."Per Company" := PerCompany;
        TableMappings.Insert(true);
    end;

    local procedure AddTableFieldMapping(FromAppID: Guid; FromAppName: Text[150]; FromTableName: Text[150]; FromTableFieldName: Text[150]; FromIsExtensionTable: Boolean; FromBaseTableName: Text[150]; ToAppID: Guid; ToAppName: Text[150]; ToTableName: Text[150]; ToIsExtensionTable: Boolean; ToBaseTableName: Text[150]; ToTableFieldName: Text[150]; AppliesFromVersion: Version; InserterAppID: Guid; PerCompany: Boolean)
    var
        TableFieldMappings: Record "Table Field Mappings";
    begin
        TableFieldMappings.SetRange("To Table SQL Name", ConvertNameToSqlName(ToTableName));
        TableFieldMappings.SetRange("To App Name", ToAppName);
        TableFieldMappings.SetRange("To APP ID", ToAppID);
        TableFieldMappings.SetRange("To Field SQL Name", ConvertNameToSqlName(ToTableFieldName));
        TableFieldMappings.SetRange("To Base Table SQL Name", ConvertNameToSqlName(ToBaseTableName));
        TableFieldMappings.SetRange("Applies From BC Major Release", AppliesFromVersion.Major);
        TableFieldMappings.SetRange("Applies From BC Minor Release", AppliesFromVersion.Minor);
        if TableFieldMappings.FindFirst() then
            exit;

        // TableFieldMappings."ID" // autoincrement
        TableFieldMappings."From APP ID" := FromAppID;
        TableFieldMappings."From App Name" := FromAppName;
        TableFieldMappings."From Table Name" := FromTableName;
        TableFieldMappings."From Table SQL Name" := CopyStr(ConvertNameToSqlName(FromTableName), 1, MaxStrLen(TableFieldMappings."From Table SQL Name"));
        TableFieldMappings."From Table Field Name" := FromTableFieldName;
        TableFieldMappings."From Field SQL Name" := CopyStr(ConvertNameToSqlName(FromTableFieldName), 1, MaxStrLen(TableFieldMappings."From Field SQL Name"));
        TableFieldMappings."From Is Extension Table" := FromIsExtensionTable;
        TableFieldMappings."From Base Table Name" := FromBaseTableName;
        TableFieldMappings."From Base Table SQL Name" := CopyStr(ConvertNameToSqlName(FromBaseTableName), 1, MaxStrLen(TableFieldMappings."From Base Table SQL Name"));
        TableFieldMappings."To APP ID" := ToAppID;
        TableFieldMappings."To App Name" := ToAppName;
        TableFieldMappings."To Table Name" := ToTableName;
        TableFieldMappings."To Table SQL Name" := CopyStr(ConvertNameToSqlName(ToTableName), 1, MaxStrLen(TableFieldMappings."To Table SQL Name"));
        TableFieldMappings."To Table Field Name" := ToTableFieldName;
        TableFieldMappings."To Field SQL Name" := CopyStr(ConvertNameToSqlName(ToTableFieldName), 1, MaxStrLen(TableFieldMappings."To Field SQL Name"));
        TableFieldMappings."To Is Extension Table" := ToIsExtensionTable;
        TableFieldMappings."To Base Table Name" := ToBaseTableName;
        TableFieldMappings."To Base Table SQL Name" := CopyStr(ConvertNameToSqlName(ToBaseTableName), 1, MaxStrLen(TableFieldMappings."To Base Table SQL Name"));
        TableFieldMappings."Inserter App ID" := InserterAppID;
        TableFieldMappings."Applies From BC Major Release" := AppliesFromVersion.Major;
        TableFieldMappings."Applies From BC Minor Release" := AppliesFromVersion.Minor;
        TableFieldMappings."Per Company" := PerCompany;
        TableFieldMappings.Insert(true);
    end;

    local procedure DeleteTableMappings()
    var
        TableMappings: Record "Table Mappings";
        TableFieldMappings: Record "Table Field Mappings";
    begin
        if not TableMappings.IsEmpty() then
            TableMappings.DeleteAll();
        if not TableFieldMappings.IsEmpty() then
            TableFieldMappings.DeleteAll();
    end;

    local procedure ConvertNameToSqlName(Name: Text): Text
    var
        ValidChars: Text;
    begin
        ValidChars := PadStr('', StrLen(SQLInvalidCharsLbl), '_');
        exit(ConvertStr(Name, SQLInvalidCharsLbl, ValidChars));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Hybrid Cloud Management", OnInsertDefaultTableMappings, '', false, false)]
    local procedure OnInsertDefaultTableMappings(DeleteExisting: Boolean; ProductID: Text[250])
    var
        HybridBCLastManagement: Codeunit "Hybrid BC Last Management";
    begin
        if not HybridBCLastManagement.GetBCLastProductEnabled() then
            exit;

        if DeleteExisting then
            DeleteTableMappings();

        // Insert table mappings
        AddMappings();
    end;
}