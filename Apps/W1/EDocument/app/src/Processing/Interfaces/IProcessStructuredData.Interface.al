// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument.Processing.Interfaces;

using Microsoft.eServices.EDocument;
using Microsoft.Purchases.Vendor;
using Microsoft.eServices.EDocument.Processing.Import;

/// <summary>
/// Describe the data processing used to assign Business Central values to the E-Document data structures
/// </summary>
interface IProcessStructuredData
{

    /// <summary>
    /// From an E-Document that has had its data structures populated, process the data to assign Business Central values
    /// </summary>
    procedure PrepareDraft(EDocument: Record "E-Document"; EDocImportParameters: Record "E-Doc. Import Parameters"): Enum "E-Document Type";

    /// <summary>
    /// Get the vendor for the E-Document
    /// </summary>
    procedure GetVendor(EDocument: Record "E-Document"; Customizations: Enum "E-Doc. Proc. Customizations"): Record Vendor;

    /// <summary>
    /// Open the draft page for the E-Document
    /// </summary>
    procedure OpenDraftPage(var EDocument: Record "E-Document");

    /// <summary>
    /// Clean up any custom or scenario specific records using during processing 
    /// </summary>
    /// <param name="EDocument"></param>
    procedure CleanUpDraft(EDocument: Record "E-Document");

}
