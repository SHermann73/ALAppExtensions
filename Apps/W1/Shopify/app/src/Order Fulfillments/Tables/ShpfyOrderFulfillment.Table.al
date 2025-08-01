// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

/// <summary>
/// Table Shpfy Order Fulfillment (ID 30111).
/// </summary>
table 30111 "Shpfy Order Fulfillment"
{
    Access = Internal;
    Caption = 'Shopify Order Fulfillment';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Shopify Fulfillment Id"; BigInteger)
        {
            Caption = 'Shopify Fulfillment Id';
            DataClassification = SystemMetadata;
        }
        field(2; "Shopify Order Id"; BigInteger)
        {
            Caption = 'Shopify Order Id';
            DataClassification = SystemMetadata;
        }
        field(3; "Created At"; DateTime)
        {
            Caption = 'Created At';
            DataClassification = SystemMetadata;
        }
        field(4; "Updated At"; DateTime)
        {
            Caption = 'Updated At';
            DataClassification = SystemMetadata;
        }
        field(5; "Tracking Number"; Text[30])
        {
            Caption = 'Tracking Number';
            DataClassification = SystemMetadata;
        }
        field(6; "Tracking URL"; Text[250])
        {
            Caption = 'Tracking URL';
            DataClassification = SystemMetadata;
            ExtendedDatatype = URL;
        }
        field(7; Status; Enum "Shpfy Fulfillment Status")
        {
            Caption = 'Status';
            DataClassification = SystemMetadata;
        }
        field(8; "Tracking Company"; Text[50])
        {
            Caption = 'Tracking Company';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(9; Name; Code[20])
        {
            Caption = 'Name';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(10; "Notify Customer"; Boolean)
        {
            Caption = 'Notify Customer';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(11; "Test Case"; Boolean)
        {
            Caption = 'Test Case';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(12; Authorization; Code[20])
        {
            Caption = 'Authorization Code';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(13; Service; Text[30])
        {
            Caption = 'Service';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(14; "Shipment Status"; enum "Shpfy Shipment Status")
        {
            Caption = 'Shipment Status';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(15; "Tracking Numbers"; Text[250])
        {
            Caption = 'Tracking Numbers';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(16; "Tracking URLs"; Text[2048])
        {
            Caption = 'Tracking URLs';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(17; "Tracking Companies"; Text[2048])
        {
            Caption = 'Tracking Companies';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(18; "Contains Gift Cards"; Boolean)
        {
            Caption = 'Contains Gift Cards';
            FieldClass = FlowField;
            CalcFormula = exist("Shpfy Fulfillment Line" where("Order Id" = field("Shopify Order Id"), "Is Gift Card" = const(true)));
        }
    }

    keys
    {
        key(Key1; "Shopify Fulfillment Id")
        {
            Clustered = true;
        }
    }

    trigger OnDelete()
    var
        FulfillmentLine: Record "Shpfy FulFillment Line";
        DataCapture: Record "Shpfy Data Capture";
    begin
        FulfillmentLine.Reset();
        FulfillmentLine.SetRange("Fulfillment Id", Rec."Shopify Fulfillment Id");
        FulfillmentLine.DeleteAll(true);

        DataCapture.SetCurrentKey("Linked To Table", "Linked To Id");
        DataCapture.SetRange("Linked To Table", Database::"Shpfy Order Fulfillment");
        DataCapture.SetRange("Linked To Id", Rec.SystemId);
        if not DataCapture.IsEmpty then
            DataCapture.DeleteAll(false);
    end;
}

