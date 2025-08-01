// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
#pragma warning disable AA0247

tableextension 10539 "MTD Report Setup" extends "VAT Report Setup"
{
    fields
    {
        field(10530; "MTD OAuth Setup Option"; Option)
        {
            DataClassification = CustomerContent;
            OptionMembers = Production,Sandbox;
        }
        field(10531; "MTD Gov Test Scenario"; Text[250])
        {
            DataClassification = CustomerContent;
        }
        field(10539; "MTD Enabled"; Boolean)
        {
            Caption = 'Enabled';

            trigger OnValidate()
            var
                AuditLog: Codeunit "Audit Log";
                CustomerConsentMgt: Codeunit "Customer Consent Mgt.";
                FeatureTelemetry: Codeunit "Feature Telemetry";
                UKMakingTaxTok: Label 'UK Making Tax Digital', Locked = true;
                UKMakingTaxConsentProvidedLbl: Label 'The UK Making Tax Digital - consent has been provided by UserSecurityId %1.', Locked = true;
            begin
                FeatureTelemetry.LogUptake('0000HFV', UKMakingTaxTok, Enum::"Feature Uptake Status"::"Set up");
                if not xRec."MTD Enabled" and "MTD Enabled" then
                    "MTD Enabled" := CustomerConsentMgt.ConfirmUserConsent();

                if "MTD Enabled" then
                    AuditLog.LogAuditMessage(StrSubstNo(UKMakingTaxConsentProvidedLbl, UserSecurityId()), SecurityOperationResult::Success, AuditCategory::ApplicationManagement, 4, 0);
            end;
        }
        field(10540; "MTD FP Public IP Service URL"; Text[250])
        {
            Caption = 'User IP Address Service';
        }
    }

    internal procedure GetMTDOAuthSetupCode(): Code[20]
    var
        MTDOAuth20Mgt: Codeunit "MTD OAuth 2.0 Mgt";
    begin
        case "MTD OAuth Setup Option" of
            "MTD OAuth Setup Option"::Production:
                exit(MTDOAuth20Mgt.GetOAuthPRODSetupCode());
            "MTD OAuth Setup Option"::Sandbox:
                exit(MTDOAuth20Mgt.GetOAuthSandboxSetupCode());
            else
                exit('');
        end;
    end;
}
