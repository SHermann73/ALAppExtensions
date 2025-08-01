﻿#if not CLEAN27
// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

using Microsoft.eServices.EDocument.IO.Peppol;
using Microsoft.EServices.EDocument.OrderMatch;
using Microsoft.eServices.EDocument.Service.Participant;

permissionset 6103 "E-Doc. Core - Basic"
{
    Access = Public;
    Assignable = true;
    Caption = 'E-Document - Basic';
    ObsoleteReason = 'Replaced by "E-Doc. Core - User" and "E-Doc. Core - Admin"';
    ObsoleteState = Pending;
    ObsoleteTag = '27.0';

    IncludedPermissionSets = "E-Doc. Core - Read";

    Permissions =
        tabledata "E-Doc. Mapping" = im,
        tabledata "E-Doc. Mapping Log" = im,
        tabledata "E-Doc. Data Storage" = im,
        tabledata "E-Document" = im,
        tabledata "E-Document Log" = im,
        tabledata "E-Document Service" = im,
        tabledata "E-Document Service Status" = im,
        tabledata "E-Document Integration Log" = im,
        tabledata "E-Doc. Service Data Exch. Def." = im,
        tabledata "E-Doc. Service Supported Type" = im,
        tabledata "E-Doc. Imported Line" = imd,
        tabledata "E-Doc. Order Match" = imd,
        tabledata "Service Participant" = imd;
}
#endif