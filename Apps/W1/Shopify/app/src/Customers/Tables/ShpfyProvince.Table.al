// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
#if not CLEANSCHEMA25
namespace Microsoft.Integration.Shopify;

/// <summary>
/// Table Shpfy Province (ID 30108).
/// </summary>
table 30108 "Shpfy Province"
{
    Access = Internal;
    Caption = 'Shopify Province';
    DataClassification = SystemMetadata;
    ObsoleteReason = 'Replaced by Shpfy Tax Area';
    ObsoleteState = Removed;
    ObsoleteTag = '25.0';

    fields
    {
        field(1; "Country/Region Id"; BigInteger)
        {
            Caption = 'Country/Region Id';
            DataClassification = SystemMetadata;
            Editable = false;
        }

        field(2; Id; BigInteger)
        {
            Caption = 'Id';
            DataClassification = SystemMetadata;
            Editable = false;
        }

        field(3; "Code"; Code[10])
        {
            Caption = 'Code';
            DataClassification = SystemMetadata;
            Editable = false;
        }

        field(4; Name; Text[50])
        {
            Caption = 'Name';
            DataClassification = SystemMetadata;
            Editable = false;
        }

        field(5; Tax; Decimal)
        {
            Caption = 'Tax';
            DataClassification = CustomerContent;
            AutoFormatType = 0;
        }

        field(6; "Tax Name"; Code[10])
        {
            Caption = 'Tax Name';
            DataClassification = SystemMetadata;
            Editable = false;
        }

        field(7; "Tax Type"; enum "Shpfy Tax Type")
        {
            Caption = 'TaxType';
            DataClassification = CustomerContent;
        }

        field(8; "Tax Percentage"; Decimal)
        {
            Caption = 'Tax Percentage';
            DataClassification = CustomerContent;
            AutoFormatType = 0;
        }
    }

    keys
    {
        key(PK; Id, "Country/Region Id")
        {
            Clustered = true;
        }
    }
}
#endif