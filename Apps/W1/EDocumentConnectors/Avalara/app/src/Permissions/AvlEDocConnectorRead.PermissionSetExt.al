// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.EServices.EDocumentConnector.Avalara;

using System.Security.AccessControl;

permissionsetextension 6372 "Avl. EDoc. Connector - Read" extends "D365 READ"
{
    IncludedPermissionSets = "Avalara Read";
}