// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

/// <summary>
/// Codeunit Shpfy GQL VariantById (ID 30150) implements Interface Shpfy IGraphQL.
/// </summary>
codeunit 30150 "Shpfy GQL VariantById" implements "Shpfy IGraphQL"
{
    Access = Internal;

    /// <summary>
    /// GetGraphQL.
    /// </summary>
    /// <returns>Return value of type Text.</returns>
    internal procedure GetGraphQL(): Text
    begin
        exit('{"query":"{productVariant(id: \"gid://shopify/ProductVariant/{{VariantId}}\") {createdAt updatedAt availableForSale barcode compareAtPrice displayName inventoryPolicy position price sku taxCode taxable title product{id}selectedOptions{name value} inventoryItem{countryCodeOfOrigin createdAt id inventoryHistoryUrl legacyResourceId measurement { weight { value }} provinceCodeOfOrigin requiresShipping sku tracked updatedAt unitCost { amount currencyCode }} metafields(first: 50) {edges {node {id namespace type legacyResourceId key value}}}}}"}');
    end;

    /// <summary>
    /// GetExpectedCost.
    /// </summary>
    /// <returns>Return value of type Integer.</returns>
    internal procedure GetExpectedCost(): Integer
    begin
        exit(25);
    end;

}
