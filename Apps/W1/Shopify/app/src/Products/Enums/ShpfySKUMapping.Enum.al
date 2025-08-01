// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

/// <summary>
/// Enum Shpfy SKU Mapping (ID 30132).
/// </summary>
enum 30132 "Shpfy SKU Mapping"
{
    Caption = 'Shopify SKU Mapping';
    Extensible = false;

    value(0; " ")
    {
    }

    value(1; "Item No.")
    {
        Caption = 'Item No.';
    }

    value(2; "Variant Code")
    {
        Caption = 'Variant code';
    }

    value(3; "Item No. + Variant Code")
    {
        Caption = 'Item No. + Variant Code';
    }

    value(4; "Vendor Item No.")
    {
        Caption = 'Vendor Item No.';
    }

    value(5; "Bar Code")
    {
        Caption = 'Bar Code';
    }
}